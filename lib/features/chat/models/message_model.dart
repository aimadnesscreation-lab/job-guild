/// A single message in a conversation
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final MessageContentType contentType;
  final String content;
  final DateTime sentAt;
  final DateTime? readAt;

  Message({
    this.id = '',
    this.conversationId = '',
    this.senderId = '',
    this.senderName = '',
    this.senderPhotoUrl,
    this.contentType = MessageContentType.text,
    this.content = '',
    DateTime? sentAt,
    this.readAt,
  }) : sentAt = sentAt ?? DateTime.now();

  bool get isRead => readAt != null;
  bool get isMine => senderId == currentUserId; // set dynamically

  static String currentUserId = '';
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
}
