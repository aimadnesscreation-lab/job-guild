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

  /// Subscribe to a live stream of messages for the given job/conversation
  void _subscribeToMessages(String conversationId) {
    // Unsubscribe from previous channel
    _messagesChannel?.unsubscribe();

    final client = Supabase.instance.client;

    // Subscribe to realtime changes on the messages table for this job
    _messagesChannel = client.channel('messages:$conversationId');
    _messagesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        // On any change, re-fetch the full message list
        await _fetchMessages(conversationId);
      },
    );
    _messagesChannel!.subscribe();

    // Also set up the initial stream
    _fetchMessages(conversationId);
  }

  /// Fetch the full message list for a conversation via the Supabase stream API
  Future<void> _fetchMessages(String conversationId) async {
    try {
      final client = Supabase.instance.client;
      final messages = await client
          .from('messages')
          .select('*, sender:sender_id(full_name)')
          .eq('job_id', conversationId)
          .order('sent_at');

      final parsed = (messages as List).map((json) {
        final sender = json['sender'] as Map<String, dynamic>?;
        return Message(
          id: json['id'] as String? ?? '',
          conversationId: conversationId,
          senderId: json['sender_id'] as String? ?? '',
          senderName: sender?['full_name'] as String? ?? 'User',
          content: json['content'] as String? ?? '',
          contentType: _parseContentType(json['content_type'] as String?),
          sentAt: json['sent_at'] != null
              ? DateTime.parse(json['sent_at'] as String)
              : DateTime.now(),
          readAt: json['read_at'] != null
              ? DateTime.parse(json['read_at'] as String)
              : null,
        );
      }).toList();

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

  /// Send a message via Supabase
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

      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send message',
      );
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
