import 'package:dio/dio.dart';
import 'api_client.dart';
import 'messages_api.dart' show MessageRecord; // reuse DTO

class MentorshipMessagesApi {
  final Dio _dio = ApiClient().dio;

  Future<List<MessageRecord>> list(
    String conversationId, {
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/api/mentorship/messages/$conversationId',
      queryParameters: {'limit': limit},
    );
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final items = (data['messages'] as List<dynamic>? ?? [])
        .map((e) => MessageRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return items;
  }

  Future<MessageRecord> sendText({
    String? conversationId,
    String? mentorUserId,
    String? otherUserId,
    required String text,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{'type': 'text', 'text': text};
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (mentorUserId != null) body['mentor_user_id'] = mentorUserId;
    if (otherUserId != null) body['other_user_id'] = otherUserId;
    if (replyToMessageId != null) body['reply_to_message_id'] = replyToMessageId;

    final res = await _dio.post('/api/mentorship/messages', data: body);
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final msg = Map<String, dynamic>.from(data['message'] ?? {});
    return MessageRecord.fromJson(msg);
  }

  String _inferTypeFromAttachments(List<Map<String, dynamic>> atts, {String fallback = 'text'}) {
    final types = atts.map((a) => (a['type'] ?? '').toString()).toList();
    if (types.contains('video')) return 'video';
    if (types.contains('image')) return 'image';
    if (types.contains('voice')) return 'voice';
    if (types.contains('document')) return 'file';
    return fallback;
  }

  Future<MessageRecord> sendTextWithMedia({
    String? conversationId,
    String? mentorUserId,
    String? otherUserId,
    required String text,
    required List<Map<String, dynamic>> attachments,
    String? replyToMessageId,
  }) async {
    final atts = attachments.where((a) => a.isNotEmpty).toList();
    final msgType = atts.isEmpty
        ? 'text'
        : _inferTypeFromAttachments(atts, fallback: text.isNotEmpty ? 'text' : 'file');

    final normalized = atts.map((a) {
      return {
        'type': a['type'],
        'url': a['url'],
        if (a['thumbnail'] != null) 'thumbnail': a['thumbnail'],
        if (a['thumbnailUrl'] != null) 'thumbnail': a['thumbnailUrl'],
        if (a['durationSec'] != null) 'durationSec': a['durationSec'],
        if (a['fileSize'] != null) 'fileSize': a['fileSize'],
        if (a['fileName'] != null) 'fileName': a['fileName'],
      };
    }).toList();

    final body = <String, dynamic>{
      'type': msgType,
      'text': text,
      if (normalized.isNotEmpty) 'attachments': normalized,
    };
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (mentorUserId != null) body['mentor_user_id'] = mentorUserId;
    if (otherUserId != null) body['other_user_id'] = otherUserId;
    if (replyToMessageId != null) body['reply_to_message_id'] = replyToMessageId;

    final res = await _dio.post('/api/mentorship/messages', data: body);
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final msg = Map<String, dynamic>.from(data['message'] ?? {});
    return MessageRecord.fromJson(msg);
  }

  Future<MessageRecord> sendVoice({
    String? conversationId,
    String? mentorUserId,
    String? otherUserId,
    required String audioUrl,
    required int durationSec,
    required int fileSize,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{
      'type': 'voice',
      'text': '',
      'attachments': [
        {
          'type': 'voice',
          'url': audioUrl,
          'durationSec': durationSec,
          'fileSize': fileSize,
          'fileName': 'voice_message.m4a',
        },
      ],
    };
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (mentorUserId != null) body['mentor_user_id'] = mentorUserId;
    if (otherUserId != null) body['other_user_id'] = otherUserId;
    if (replyToMessageId != null) body['reply_to_message_id'] = replyToMessageId;

    final res = await _dio.post('/api/mentorship/messages', data: body);
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final msg = Map<String, dynamic>.from(data['message'] ?? {});
    return MessageRecord.fromJson(msg);
  }

  Future<void> react(String messageId, String? emoji) async {
    await _dio.post('/api/mentorship/messages/$messageId/react', data: emoji == null ? {} : {'emoji': emoji});
  }

  Future<void> markRead(String messageId) async {
    await _dio.post('/api/mentorship/messages/$messageId/read');
  }

  Future<void> deleteForMe(String messageId) async {
    await _dio.post('/api/mentorship/messages/$messageId/delete-for-me');
  }

  Future<void> deleteForEveryone(String messageId) async {
    await _dio.post('/api/mentorship/messages/$messageId/delete-for-everyone');
  }
}