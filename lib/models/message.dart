enum MessageType { text, image, video, voice, file }

enum MessageStatus { sending, sent, delivered, read, failed }

class MediaAttachment {
  final String id;
  final String url;
  final String? localPath;
  final MediaType type;
  final String? thumbnailUrl;
  final Duration? duration; // For videos and voice messages
  final int? fileSize;
  final String? fileName;

  MediaAttachment({
    required this.id,
    required this.url,
    this.localPath,
    required this.type,
    this.thumbnailUrl,
    this.duration,
    this.fileSize,
    this.fileName,
  });
}

enum MediaType { image, video, voice, document }

class ReplyTo {
  final String messageId;
  final String senderName;
  final String content;
  final MessageType type;
  final String? mediaUrl;

  ReplyTo({
    required this.messageId,
    required this.senderName,
    required this.content,
    required this.type,
    this.mediaUrl,
  });
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final List<MediaAttachment> attachments;
  final DateTime timestamp;
  final MessageStatus status;
  final ReplyTo? replyTo;
  final bool isFromCurrentUser;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    this.attachments = const [],
    required this.timestamp,
    required this.status,
    this.replyTo,
    required this.isFromCurrentUser,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    List<MediaAttachment>? attachments,
    DateTime? timestamp,
    MessageStatus? status,
    ReplyTo? replyTo,
    bool? isFromCurrentUser,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      replyTo: replyTo ?? this.replyTo,
      isFromCurrentUser: isFromCurrentUser ?? this.isFromCurrentUser,
    );
  }
}

class ChatUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });
}
