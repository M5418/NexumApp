import 'dart:async';

class ConversationUserSummary {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  ConversationUserSummary({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });
}

class ConversationSummaryModel {
  final String id;
  final String otherUserId;
  final ConversationUserSummary otherUser;
  final String? lastMessageType; // text, image, video, voice, file
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool lastFromCurrentUser;
  final bool? lastRead;

  ConversationSummaryModel({
    required this.id,
    required this.otherUserId,
    required this.otherUser,
    this.lastMessageType,
    this.lastMessageText,
    this.lastMessageAt,
    required this.unreadCount,
    required this.muted,
    required this.lastFromCurrentUser,
    this.lastRead,
  });
}

abstract class ConversationRepository {
  Future<List<ConversationSummaryModel>> list({int limit = 50});
  Stream<List<ConversationSummaryModel>> listStream({int limit = 50});
  Future<String> createOrGet(String otherUserId);
  Future<void> markRead(String conversationId);
  Future<void> mute(String conversationId);
  Future<void> unmute(String conversationId);
  Future<void> delete(String conversationId);
  Future<String?> checkConversationExists(String otherUserId);
}
