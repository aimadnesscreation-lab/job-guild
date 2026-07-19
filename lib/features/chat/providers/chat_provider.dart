import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      activeConversationId:
          activeConversationId ?? this.activeConversationId,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  /// Active Realtime subscription channel for the current conversation
  RealtimeChannel? _messagesChannel;

  /// Cache of sender profiles keyed by user id, so realtime inserts can be
  /// enriched without refetching the whole thread (realtime payloads don't
  /// include joined relation data).
  final Map<String, Map<String, dynamic>> _senderCache = {};

  @override
  ChatState build() {
    // Start loading conversations on init
    _loadConversations();
    return const ChatState(isLoading: true);
  }

  /// Call this when leaving the chat to clean up subscriptions
  void disposeChannel() {
    _messagesChannel?.unsubscribe();
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

      // Fetch messages involving the user, grouped by job_id
      final response = await client
          .from('messages')
          .select('*, jobs!inner(title, employer_id)')
          .or('sender_id.eq.$userId,jobs.employer_id.eq.$userId')
          .order('sent_at', ascending: false);

      final data = response as List;

      // Group messages by job_id into conversations
      final grouped = <String, Map<String, dynamic>>{};
      for (final msg in data) {
        final jobId = msg['job_id'] as String? ?? '';
        if (jobId.isEmpty) continue;

        if (!grouped.containsKey(jobId)) {
          final job = msg['jobs'] as Map<String, dynamic>? ?? {};
          final employerId = job['employer_id'] as String? ?? '';
          final isEmployer = employerId == userId;

          grouped[jobId] = {
            'id': jobId,
            'jobId': jobId,
            'jobTitle': job['title'] as String? ?? 'Job',
            'otherUserId':
                isEmployer ? (msg['sender_id'] as String?) ?? '' : employerId,
            'otherUserName':
                isEmployer ? 'Worker' : 'Employer',
            'lastContent': msg['content'] as String? ?? '',
            'lastSentAt': msg['sent_at'] != null
                ? DateTime.parse(msg['sent_at'] as String)
                : DateTime.now(),
          };
        }
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

      state = ChatState(
        conversations: conversations,
        isLoading: false,
      );
    } catch (e) {
      state = ChatState(
        isLoading: false,
        errorMessage: 'Failed to load conversations: $e',
      );
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

      state = state.copyWith(
        currentMessages: parsed,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load messages: $e',
      );
    }
  }

  MessageContentType _parseContentType(String? type) {
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

  // ─── Public API ──────────────────────────────────────────────

  /// Load conversation messages and subscribe to live updates
  Future<void> loadConversation(String conversationId) async {
    state = state.copyWith(
      activeConversationId: conversationId,
      isLoading: true,
    );
    _subscribeToMessages(conversationId);
  }

  /// Send a message via Supabase. Re-throws on failure so the UI can surface
  /// the error (e.g. show a SnackBar when the send fails / user is offline).
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final conversationId = state.activeConversationId;
    if (conversationId == null) return;

    state = state.copyWith(isSending: true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      await client.from('messages').insert({
        'job_id': conversationId,
        'sender_id': userId ?? 'anonymous',
        'content': text.trim(),
        'content_type': 'text',
      });

      state = state.copyWith(isSending: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isSending: false);
      throw Exception('Failed to send message: $e');
    }
  }

  void setTyping(bool typing) {
    state = state.copyWith(isTyping: typing);
  }

  Future<void> markAsRead(String conversationId) async {
    final conversations = state.conversations.map((c) {
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
    state = state.copyWith(conversations: conversations);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
    () => ChatNotifier());
