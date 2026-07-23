/// A single message in a conversation
class Message {
  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final MessageContentType contentType;
  final String content;
  final Map<String, dynamic>? metadata;
  final DateTime sentAt;
  final DateTime? readAt;

  Message({
    this.id = '',
    this.jobId = '',
    this.senderId = '',
    this.senderName = '',
    this.senderPhotoUrl,
    this.contentType = MessageContentType.text,
    this.content = '',
    this.metadata,
    DateTime? sentAt,
    this.readAt,
  }) : sentAt = sentAt ?? DateTime.now();

  bool get isRead => readAt != null;

  /// Whether this message was sent by the currently authenticated user.
  /// Pass the current user's ID from the provider/session that owns the view.
  bool isMe(String currentUserId) => senderId == currentUserId;

  factory Message.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return Message(
      id: json['id'] as String? ?? '',
      jobId: json['job_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName:
          sender?['full_name'] as String? ??
          json['sender_name'] as String? ??
          '',
      senderPhotoUrl:
          sender?['profile_photo_url'] as String? ??
          json['sender_photo_url'] as String?,
      contentType: parseContentType(json['content_type'] as String?),
      content: json['content'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'job_id': jobId,
    'sender_id': senderId,
    'content_type': contentType.name,
    'content': content,
    if (metadata != null) 'metadata': metadata,
    'sent_at': sentAt.toIso8601String(),
    if (readAt != null) 'read_at': readAt!.toIso8601String(),
  };

  /// Parse a content_type string into [MessageContentType].
  /// This is the canonical parser — used by both [Message] and [ChatNotifier].
  static MessageContentType parseContentType(String? type) {
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
}

enum MessageContentType { text, image, voice, location, file }

/// A conversation between employer and worker for a specific job
class Conversation {
  final String id;
  final String jobId;
  final String jobTitle;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  Conversation({
    this.id = '',
    this.jobId = '',
    this.jobTitle = '',
    this.otherUserId = '',
    this.otherUserName = '',
    this.otherUserPhotoUrl,
    this.lastMessage,
    this.unreadCount = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Conversation copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? otherUserId,
    String? otherUserName,
    String? otherUserPhotoUrl,
    Message? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    bool clearOtherUserPhotoUrl = false,
    bool clearLastMessage = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserPhotoUrl: clearOtherUserPhotoUrl
          ? null
          : (otherUserPhotoUrl ?? this.otherUserPhotoUrl),
      lastMessage:
          clearLastMessage ? null : (lastMessage ?? this.lastMessage),
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
