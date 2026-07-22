import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/chat/models/message_model.dart';

/// State for the chat feature
class ChatState {
  final List<Conversation> conversations;
  final List<Message> currentMessages;
  final String? activeConversationId;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final bool isTyping;

  const ChatState({
    this.conversations = const [],
    this.currentMessages = const [],
    this.activeConversationId,
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.isTyping = false,
  });

  ChatState copyWith({
    List<Conversation>? conversations,
    List<Message>? currentMessages,
    String? activeConversationId,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    bool? isTyping,
    bool clearError = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      currentMessages: currentMessages ?? this.currentMessages,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  /// Active Realtime subscription channel for the current conversation's
  /// message thread (per-conversation, created when entering a detail view).
  RealtimeChannel? _messagesChannel;

  /// Global Realtime subscription channel for the conversation list.
  /// Listens for new messages on ANY of the user's jobs (employer + worker)
  /// and updates the conversation previews in realtime.
  RealtimeChannel? _conversationsChannel;

  /// Cache of sender profiles keyed by user id, so realtime inserts can be
  /// enriched without refetching the whole thread (realtime payloads don't
  /// include joined relation data).
  final Map<String, Map<String, dynamic>> _senderCache = {};

  /// Job IDs relevant to the current user (posted as employer + applied as
  /// worker). Cached so the global Realtime subscription can filter incoming
  /// messages without re-querying.
  final Set<String> _userJobIds = {};

  @override
  ChatState build() {
    // Start loading conversations on init
    _loadConversations();

    // Auto-retry queued offline messages on startup (deferred to avoid
    // coupling the provider to Flutter's widget layer)
    Future.microtask(() => retryOfflineQueue());

    // Clean up the global conversation channel when this provider is
    // disposed by Riverpod (e.g. user leaves the chat tab entirely).
    ref.onDispose(() {
      _conversationsChannel?.unsubscribe();
      if (_conversationsChannel != null) {
        Supabase.instance.client.removeChannel(_conversationsChannel!);
      }
    });

    return const ChatState(isLoading: true);
  }

  /// Call this when leaving the chat detail view to clean up the
  /// per-conversation message subscription. The global conversation list
  /// subscription is NOT torn down here — it lives for the provider's
  /// lifetime and is cleaned up in [build]'s `ref.onDispose`.
  void disposeChannel() {
    if (_messagesChannel != null) {
      _messagesChannel!.unsubscribe();
      Supabase.instance.client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  /// Fetch the current user's conversations from Supabase
  Future<void> _loadConversations() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        state = const ChatState(isLoading: false);
        return;
      }

      // Fetch messages involving the user, grouped by job_id.
      //
      // PostgREST rejects an `.or()` that references an embedded resource
      // (jobs.employer_id), so we resolve relevant job IDs first and filter
      // on the top-level `job_id` column.
      //
      // 1. Jobs the user posted as employer
      final employerJobIds =
          (await client.from('jobs').select('id').eq('employer_id', userId))
              as List;
      final jobIds = employerJobIds
          .map((j) => (j as Map<String, dynamic>)['id'] as String)
          .toList();

      // 2. Jobs the user applied to as a worker (best-effort — the user may
      //    not have a worker_profile yet, or RLS may deny the query).
      //    This ensures workers see conversations where the employer sent
      //    the first message (inbound messages they didn't initiate).
      try {
        final appliedJobs = await client
            .from('applications')
            .select('job_id')
            .eq('worker_id', userId);
        for (final row in (appliedJobs as List)) {
          final jid = (row as Map<String, dynamic>)['job_id'] as String?;
          if (jid != null && !jobIds.contains(jid)) {
            jobIds.add(jid);
          }
        }
      } catch (_) {
        // applications table not available or user has no worker profile —
        // fall through with just the employer job IDs.
      }

      // Cache the job IDs for the global Realtime subscription filter.
      _userJobIds
        ..clear()
        ..addAll(jobIds);

      final query = client
          .from('messages')
          .select('*, jobs!inner(title, employer_id)');
      if (jobIds.isEmpty) {
        query.eq('sender_id', userId);
      } else {
        // Build proper PostgREST in.() syntax: job_id.in.(id1,id2,id3)
        final jobIdsStr = jobIds.join(',');
        query.or('sender_id.eq.$userId,job_id.in.($jobIdsStr)');
      }
      final response = await query.order('sent_at', ascending: false);

      final data = response as List;

      // First pass: collect unique other-user IDs for a single batched lookup.
      final uniqueOtherIds = <String>{};
      final jobIdToOtherId = <String, String>{};
      final jobIdToIsEmployer = <String, bool>{};

      for (final msg in data) {
        final jobId = msg['job_id'] as String? ?? '';
        if (jobId.isEmpty || jobIdToOtherId.containsKey(jobId)) continue;

        final job = msg['jobs'] as Map<String, dynamic>? ?? {};
        final employerId = job['employer_id'] as String? ?? '';
        final isEmployer = employerId == userId;
        final otherId = isEmployer
            ? (msg['sender_id'] as String?) ?? ''
            : employerId;

        jobIdToOtherId[jobId] = otherId;
        jobIdToIsEmployer[jobId] = isEmployer;
        if (otherId.isNotEmpty) {
          uniqueOtherIds.add(otherId);
        }
      }

      // Batch-lookup all unique user names in a single query.
      final nameCache = <String, String>{};
      if (uniqueOtherIds.isNotEmpty) {
        try {              final userIdsList = uniqueOtherIds.toList();
              // PostgREST `in` filter requires a comma-separated string
              // wrapped in parentheses, e.g. "(id1,id2,id3)". Passing a
              // Dart List would toString as "[id1, id2]" which is invalid.
              final idFilter = '(${userIdsList.join(',')})';
              final userDataList = await client
                  .from('users')
                  .select('id, full_name')
                  .filter('id', 'in', idFilter);
          for (final userData in (userDataList as List)) {
            final uid = userData['id'] as String?;
            final name = userData['full_name'] as String?;
            if (uid != null && name != null && name.isNotEmpty) {
              nameCache[uid] = name;
            }
          }
        } catch (_) {
          // Fallback to generic labels below
        }
      }

      // Second pass: build conversation objects using the cached names.
      final grouped = <String, Map<String, dynamic>>{};

      for (final msg in data) {
        final jobId = msg['job_id'] as String? ?? '';
        if (jobId.isEmpty || grouped.containsKey(jobId)) continue;

        final job = msg['jobs'] as Map<String, dynamic>? ?? {};
        final otherId = jobIdToOtherId[jobId] ?? '';
        final isEmployer = jobIdToIsEmployer[jobId] ?? false;

        String otherName = nameCache[otherId] ??
            (isEmployer ? 'Worker' : 'Employer');

        grouped[jobId] = {
          'id': jobId,
          'jobId': jobId,
          'jobTitle': job['title'] as String? ?? 'Job',
          'otherUserId': otherId,
          'otherUserName': otherName,
          'lastContent': msg['content'] as String? ?? '',
          'lastSentAt': msg['sent_at'] != null
              ? DateTime.parse(msg['sent_at'] as String)
              : DateTime.now(),
        };
      }

      final conversations = grouped.entries.map((entry) {
        final v = entry.value;
        return Conversation(
          id: v['id'] as String,
          jobId: v['jobId'] as String,
          jobTitle: v['jobTitle'] as String,
          otherUserId: v['otherUserId'] as String,
          otherUserName: v['otherUserName'] as String,
          lastMessage: Message(
            content: v['lastContent'] as String,
            sentAt: v['lastSentAt'] as DateTime,
          ),
          updatedAt: v['lastSentAt'] as DateTime,
        );
      }).toList();

      state = ChatState(conversations: conversations, isLoading: false);

      // Subscribe to realtime updates for the conversation list now that
      // we have the job IDs cached.
      _subscribeToConversations();
    } catch (e) {
      state = ChatState(
        isLoading: false,
        errorMessage: 'Failed to load conversations: $e',
      );
    }
  }

  // ─── Global Realtime (conversation list) ─────────────────────────

  /// Subscribe to INSERT events on the `messages` table so the conversation
  /// list updates live when a new message arrives — even if the user is not
  /// currently viewing that conversation.  The callback checks the cached
  /// [_userJobIds] set to filter only relevant messages (ignoring messages
  /// for other users' conversations entirely).
  void _subscribeToConversations() {
    // Unsubscribe previous channel before creating a new one
    _conversationsChannel?.unsubscribe();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    _conversationsChannel = client.channel('conversations:$userId');
    _conversationsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) => _onConversationMessageInsert(payload, userId),
    );
    _conversationsChannel!.subscribe();
  }

  /// Handle a new message INSERT that is relevant to the current user
  /// (its `job_id` is in [_userJobIds]).  Updates the conversation preview
  /// live.  If the conversation is not yet in the list (new conversation),
  /// fetches job title + other user info and creates a fresh entry.
  Future<void> _onConversationMessageInsert(
    PostgresChangePayload payload,
    String userId,
  ) async {
    final record = payload.newRecord;
    final jobId = record['job_id'] as String? ?? '';
    if (jobId.isEmpty || !_userJobIds.contains(jobId)) return;

    final senderId = record['sender_id'] as String? ?? '';
    final content = record['content'] as String? ?? '';
    final contentType = record['content_type'] as String? ?? 'text';
    final sentAtStr = record['sent_at'] as String?;
    final sentAt = sentAtStr != null ? DateTime.parse(sentAtStr) : DateTime.now();
    final isOwn = senderId == userId;

    final existingIdx = state.conversations.indexWhere((c) => c.id == jobId);

    if (existingIdx >= 0) {
      // Update existing conversation — replace preview and bump to top.
      final conv = state.conversations[existingIdx];
      final updated = Conversation(
        id: conv.id,
        jobId: conv.jobId,
        jobTitle: conv.jobTitle,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserPhotoUrl: conv.otherUserPhotoUrl,
        lastMessage: Message(
          content: content,
          sentAt: sentAt,
          contentType: _parseContentType(contentType),
        ),
        unreadCount: isOwn ? 0 : conv.unreadCount + 1,
        updatedAt: sentAt,
      );
      final list = List<Conversation>.from(state.conversations)
        ..[existingIdx] = updated
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(conversations: list);
    } else {
      // New conversation — fetch job + user info, then add to list.
      try {
        final client = Supabase.instance.client;
        final job = await client
            .from('jobs')
            .select('title, employer_id')
            .eq('id', jobId)
            .single();
        // Determine the other participant — mirrors the logic in
        // _loadConversations() first pass.
        final employerId = job['employer_id'] as String? ?? '';
        final otherId = userId == employerId ? senderId : employerId;
        String otherName = 'User';
        try {
          final user = await client
              .from('users')
              .select('full_name')
              .eq('id', otherId)
              .single();
          otherName = user['full_name'] as String? ?? 'User';
        } catch (_) {}

        final newConv = Conversation(
          id: jobId,
          jobId: jobId,
          jobTitle: job['title'] as String? ?? 'Job',
          otherUserId: otherId,
          otherUserName: otherName,
          lastMessage: Message(content: content, sentAt: sentAt),
          unreadCount: isOwn ? 0 : 1,
          updatedAt: sentAt,
        );
        final list = List<Conversation>.from(state.conversations)
          ..add(newConv)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        state = state.copyWith(conversations: list);
      } catch (_) {
        // Fetch failed — full reload as fallback.
        _loadConversations();
      }
    }
  }

  /// Update the conversation preview for a recently-sent message (used by
  /// [sendMessage] and [sendVoice] so the chat list shows the latest text).
  void _updateConversationPreview(
    String conversationId,
    String content,
    MessageContentType contentType,
  ) {
    final now = DateTime.now();
    final idx = state.conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) return;

    final conv = state.conversations[idx];
    final updated = Conversation(
      id: conv.id,
      jobId: conv.jobId,
      jobTitle: conv.jobTitle,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserPhotoUrl: conv.otherUserPhotoUrl,
      lastMessage: Message(content: content, sentAt: now, contentType: contentType),
      unreadCount: conv.unreadCount,
      updatedAt: now,
    );
    final list = List<Conversation>.from(state.conversations)
      ..[idx] = updated
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(conversations: list);
  }

  /// Parse a content_type string into [MessageContentType] (mirrors the
  /// private static [Message._parseContentType] which we cannot access).
  static MessageContentType _parseContentType(String? type) {
    switch (type) {
      case 'image':
        return MessageContentType.image;
      case 'voice':
        return MessageContentType.voice;
      case 'location':
        return MessageContentType.location;
      case 'file':
        return MessageContentType.file;
      default:
        return MessageContentType.text;
    }
  }

  /// Subscribe to live changes for the given job/conversation and apply them
  /// as deltas (insert/update/delete) instead of refetching the whole thread.
  void _subscribeToMessages(String conversationId) {
    // Unsubscribe from previous channel
    _messagesChannel?.unsubscribe();

    final client = Supabase.instance.client;

    _messagesChannel = client.channel('messages:$conversationId');
    _messagesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'job_id',
        value: conversationId,
      ),
      callback: (payload) async {
        await _applyRealtimeChange(payload, conversationId);
      },
    );
    _messagesChannel!.subscribe();

    // Initial load of the full thread
    _fetchMessages(conversationId);
  }

  /// Apply a single realtime change to the in-memory message list.
  Future<void> _applyRealtimeChange(
    PostgresChangePayload payload,
    String conversationId,
  ) async {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final msg = await _messageFromRecord(payload.newRecord, conversationId);
        _upsertMessage(msg);
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id'] as String?;
        if (id != null) _removeMessage(id);
      case PostgresChangeEvent.all:
        // Fallback: rebuild from the database
        await _fetchMessages(conversationId);
    }
  }

  /// Build a [Message] from a raw realtime row, enriching sender info with a
  /// cached lookup (or a single targeted fetch) since realtime payloads don't
  /// include joined relation data.
  Future<Message> _messageFromRecord(
    Map<String, dynamic> record,
    String conversationId,
  ) async {
    final senderId = record['sender_id'] as String? ?? '';
    Map<String, dynamic>? sender = _senderCache[senderId];
    if (senderId.isNotEmpty && sender == null) {
      try {
        sender = await Supabase.instance.client
            .from('users')
            .select('full_name, profile_photo_url')
            .eq('id', senderId)
            .single();
        _senderCache[senderId] = sender;
      } catch (_) {
        sender = null;
      }
    }

    final enriched = <String, dynamic>{...record};
    if (sender != null) enriched['sender'] = sender;
    return Message.fromJson(enriched);
  }

  void _upsertMessage(Message msg) {
    if (msg.id.isEmpty) return;
    final list = List<Message>.from(state.currentMessages);
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      list[idx] = msg;
    } else {
      list.add(msg);
    }
    list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    state = state.copyWith(currentMessages: list, isLoading: false);
  }

  void _removeMessage(String id) {
    final list = state.currentMessages.where((m) => m.id != id).toList();
    state = state.copyWith(currentMessages: list);
  }

  /// Fetch the full message list for a conversation via the Supabase stream API
  Future<void> _fetchMessages(String conversationId) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      Message.currentUserId = userId ?? '';

      final messages = await client
          .from('messages')
          .select('*, sender:sender_id(full_name, profile_photo_url)')
          .eq('job_id', conversationId)
          .order('sent_at');

      final parsed = (messages as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();

      // Warm the sender cache so realtime inserts can be enriched cheaply.
      for (final m in parsed) {
        if (m.senderId.isNotEmpty && !_senderCache.containsKey(m.senderId)) {
          _senderCache[m.senderId] = {
            'full_name': m.senderName,
            'profile_photo_url': m.senderPhotoUrl,
          };
        }
      }

      state = state.copyWith(currentMessages: parsed, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load messages: $e',
      );
    }
  }

  // ─── Public API ──────────────────────────────────────────────

  /// Load conversation messages and subscribe to live updates
  Future<void> loadConversation(String conversationId) async {
    state = state.copyWith(
      activeConversationId: conversationId,
      isLoading: true,
    );
    _subscribeToMessages(conversationId);
  }

  /// Send a message via Supabase with optimistic UI update and offline queue.
  ///
  /// 1. Optimistically adds the message to the UI immediately.
  /// 2. Tries to send to Supabase.
  /// 3. On failure, saves to local queue and marks as unsent.
  Future<void> sendMessage(String text, {String? imageUrl}) async {
    if (text.trim().isEmpty && imageUrl == null) return;

    final conversationId = state.activeConversationId;
    if (conversationId == null) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id ?? 'anonymous';

    // Create an optimistic message with a temporary ID
    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = Message(
      id: optimisticId,
      jobId: conversationId,
      senderId: userId,
      senderName: 'You',
      contentType: imageUrl != null
          ? MessageContentType.image
          : MessageContentType.text,
      content: imageUrl ?? text.trim(),
      sentAt: DateTime.now(),
    );

    // Optimistic UI update
    _upsertMessage(optimisticMsg);
    state = state.copyWith(isSending: true);
    // Immediately update the conversation preview so the chat list shows
    // the new message without waiting for the server round-trip.
    _updateConversationPreview(
      conversationId,
      imageUrl ?? text.trim(),
      imageUrl != null ? MessageContentType.image : MessageContentType.text,
    );

    try {
      await client.from('messages').insert({
        'job_id': conversationId,
        'sender_id': userId,
        'content': imageUrl ?? text.trim(),
        'content_type': imageUrl != null ? 'image' : 'text',
        if (imageUrl != null)
          'metadata': jsonEncode({'type': 'image', 'url': imageUrl}),
      });

      state = state.copyWith(isSending: false, clearError: true);
    } catch (e) {
      // Save to offline queue
      await _addToOfflineQueue({
        'job_id': conversationId,
        'sender_id': userId,
        'content': imageUrl ?? text.trim(),
        'content_type': imageUrl != null ? 'image' : 'text',
        'failed_at': DateTime.now().toIso8601String(),
      });
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Message queued — will send when online',
      );
    }
  }

  /// Save a failed message to the local queue for retry
  Future<void> _addToOfflineQueue(Map<String, dynamic> msg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('message_queue');
      final queue = existing != null
          ? (jsonDecode(existing) as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      queue.add(msg);
      await prefs.setString('message_queue', jsonEncode(queue));
      debugPrint('[OfflineQueue] Message queued. Queue size: ${queue.length}');
    } catch (e) {
      debugPrint('[OfflineQueue] Failed to queue message: $e');
    }
  }

  /// Retry sending all queued offline messages
  Future<void> retryOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('message_queue');
      if (existing == null) return;

      final queue = (jsonDecode(existing) as List).cast<Map<String, dynamic>>();
      if (queue.isEmpty) return;

      final client = Supabase.instance.client;
      final remaining = <Map<String, dynamic>>[];

      for (final msg in queue) {
        try {
          await client.from('messages').insert({
            'job_id': msg['job_id'],
            'sender_id': msg['sender_id'],
            'content': msg['content'],
            'content_type': msg['content_type'],
          });
          debugPrint('[OfflineQueue] Delivered queued message');
        } catch (e) {
          remaining.add(msg);
        }
      }

      await prefs.setString('message_queue', jsonEncode(remaining));
      debugPrint('[OfflineQueue] Sync complete. ${remaining.length} remaining');
    } catch (e) {
      debugPrint('[OfflineQueue] Sync failed: $e');
    }
  }

  /// Set typing indicator
  void setTyping(bool typing) {
    state = state.copyWith(isTyping: typing);
  }

  /// Send an image message
  Future<void> sendImage(String imageUrl) async {
    await sendMessage('🖼️ Image', imageUrl: imageUrl);
  }

  /// Send a voice message — stores the audio URL with content_type: 'voice'
  /// so the UI can render [_VoiceMessageWidget] with playback controls.
  Future<void> sendVoice(String audioUrl) async {
    if (audioUrl.trim().isEmpty) return;

    final conversationId = state.activeConversationId;
    if (conversationId == null) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id ?? 'anonymous';

    // Optimistic message
    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = Message(
      id: optimisticId,
      jobId: conversationId,
      senderId: userId,
      senderName: 'You',
      contentType: MessageContentType.voice,
      content: audioUrl,
      sentAt: DateTime.now(),
    );
    _upsertMessage(optimisticMsg);
    state = state.copyWith(isSending: true);
    // Update conversation preview so the chat list shows the voice message.
    _updateConversationPreview(
      conversationId,
      '🎤 Voice message',
      MessageContentType.voice,
    );

    try {
      await client.from('messages').insert({
        'job_id': conversationId,
        'sender_id': userId,
        'content': audioUrl,
        'content_type': 'voice',
        'metadata': jsonEncode({'type': 'voice', 'url': audioUrl}),
      });
      state = state.copyWith(isSending: false, clearError: true);
    } catch (e) {
      await _addToOfflineQueue({
        'job_id': conversationId,
        'sender_id': userId,
        'content': audioUrl,
        'content_type': 'voice',
        'failed_at': DateTime.now().toIso8601String(),
      });
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Voice message queued — will send when online',
      );
    }
  }

  /// Mark all messages in a conversation as read, both locally and on the
  /// server.  Updates `read_at` in Supabase for any message with a null
  /// `read_at` so read receipts (`done_all` icon) persist across sessions.
  Future<void> markAsRead(String conversationId) async {
    // 1. Optimistic local update — clear the unread badge immediately.
    final localList = state.conversations.map((c) {
      if (c.id == conversationId) {
        return Conversation(
          id: c.id,
          jobId: c.jobId,
          jobTitle: c.jobTitle,
          otherUserId: c.otherUserId,
          otherUserName: c.otherUserName,
          otherUserPhotoUrl: c.otherUserPhotoUrl,
          lastMessage: c.lastMessage,
          unreadCount: 0,
          updatedAt: c.updatedAt,
        );
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: localList);

    // 2. Persist to Supabase — mark all currently-unread messages as read.
    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return;
      final now = DateTime.now().toIso8601String();
      await client
          .from('messages')
          .update({'read_at': now})
          .eq('job_id', conversationId)
          .filter('read_at', 'is', 'null')
          // Don't mark the user's own messages as read — the done_all
          // icon should only show when the OTHER user has read them.
          .filter('sender_id', 'neq', currentUserId);
      debugPrint('[Chat] Marked messages as read for conversation $conversationId');
    } catch (e) {
      debugPrint('[Chat] Failed to persist read receipts: $e');
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);
