import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'api_client.dart';

class ConversationUser {
  final String name;
  final String username;
  final String? avatarUrl;

  ConversationUser({
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      name: (json['name'] ?? 'User').toString(),
      username: (json['username'] ?? '@user').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

class ConversationSummary {
  final String id;
  final String otherUserId;
  final ConversationUser otherUser;
  final String? lastMessageType; // text, image, video, voice, file
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool lastFromCurrentUser;
  final bool? lastRead;

  ConversationSummary({
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

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: (json['id'] ?? '').toString(),
      otherUserId: (json['other_user_id'] ?? '').toString(),
      otherUser: ConversationUser.fromJson(
        Map<String, dynamic>.from(json['other_user'] ?? {}),
      ),
      lastMessageType: json['last_message_type']?.toString(),
      lastMessageText: json['last_message_text']?.toString(),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      unreadCount: int.tryParse((json['unread_count'] ?? 0).toString()) ?? 0,
      muted: (json['muted'] == true) || (json['muted'] == 1),
      lastFromCurrentUser:
          json['last_from_current_user'] == true ||
          json['last_from_current_user'] == 1,
      lastRead: json['last_read'] == null
          ? null
          : (json['last_read'] == true || json['last_read'] == 1),
    );
  }
}

class ConversationsApi {
  final Dio _dio = ApiClient().dio;

  Future<List<ConversationSummary>> list() async {
    final res = await _dio.get('/api/conversations');
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final items = (data['conversations'] as List<dynamic>? ?? [])
        .map(
          (e) =>
              ConversationSummary.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return items;
  }

  Future<String> createOrGet(String otherUserId) async {
    final res = await _dio.post(
      '/api/conversations',
      data: {'other_user_id': otherUserId},
    );
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final conv = Map<String, dynamic>.from(data['conversation'] ?? {});
    return (conv['id'] ?? '').toString();
  }

  Future<void> markRead(String conversationId) async {
    await _dio.post('/api/conversations/$conversationId/mark-read');
  }

  Future<void> mute(String conversationId) async {
    await _dio.post('/api/conversations/$conversationId/mute');
  }

  Future<void> unmute(String conversationId) async {
    await _dio.post('/api/conversations/$conversationId/unmute');
  }

  Future<void> delete(String conversationId) async {
    await _dio.delete('/api/conversations/$conversationId');
  }

  /// Check if conversation exists with another user
  /// Returns conversation ID if exists, null if not
  Future<String?> checkConversationExists(String otherUserId) async {
    try {
      final conversations = await list();
      for (final conv in conversations) {
        if (conv.otherUserId == otherUserId) {
          return conv.id;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ ConversationsApi: Error checking conversation: $e');
      return null;
    }
  }
}