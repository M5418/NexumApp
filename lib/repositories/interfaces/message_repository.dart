import 'dart:async';

class AttachmentModel {
  final String id;
  final String type; // image, video, voice, file
  final String url;
  final String? thumbnail;
  final int? durationSec;
  final int? fileSize;
  final String? fileName;

  AttachmentModel({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnail,
    this.durationSec,
    this.fileSize,
    this.fileName,
  });
}

class MessageRecordModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String type; // text, image, video, voice, file
  final String? text;
  final DateTime createdAt;
  final DateTime? readAt; // optional convenience for "my read time"
  final List<AttachmentModel> attachments;
  final String? myReaction;
  final String? reaction; // latest reaction by anyone
  final Map<String, dynamic>? replyTo;

  MessageRecordModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    this.text,
    required this.createdAt,
    this.readAt,
    required this.attachments,
    this.myReaction,
    this.reaction,
    this.replyTo,
  });
}

abstract class MessageRepository {
  // List recent messages ordered by createdAt asc
  Future<List<MessageRecordModel>> list(String conversationId, {int limit = 50});

  // Real-time stream for messages (optional for future improvement)
  Stream<List<MessageRecordModel>> messagesStream(String conversationId, {int limit = 50});

  // Send messages
  Future<MessageRecordModel> sendText({String? conversationId, String? otherUserId, required String text, String? replyToMessageId});
  Future<MessageRecordModel> sendTextWithAttachments({String? conversationId, String? otherUserId, required String text, required List<Map<String, dynamic>> attachments, String? replyToMessageId});
  Future<MessageRecordModel> sendVoice({String? conversationId, String? otherUserId, required String audioUrl, required int durationSec, required int fileSize, String? replyToMessageId});

  // Reactions
  Future<void> react(String messageId, String? emoji);

  // Deletes
  Future<void> deleteForMe(String messageId);
  Future<void> deleteForEveryone(String messageId);
}
