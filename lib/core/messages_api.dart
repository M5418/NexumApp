import 'package:dio/dio.dart';
import 'api_client.dart';

class AttachmentDto {
  final String id;
  final String type; // image, video, voice, document
  final String url;
  final String? thumbnail;
  final int? durationSec;
  final int? fileSize;
  final String? fileName;

  AttachmentDto({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnail,
    this.durationSec,
    this.fileSize,
    this.fileName,
  });

  factory AttachmentDto.fromJson(Map<String, dynamic> json) => AttachmentDto(
    id: (json['id'] ?? '').toString(),
    type: (json['type'] ?? 'image').toString(),
    url: (json['url'] ?? '').toString(),
    thumbnail: json['thumbnail']?.toString(),
    durationSec: json['durationSec'] is int
        ? json['durationSec'] as int
        : int.tryParse(json['durationSec']?.toString() ?? ''),
    fileSize: json['fileSize'] is int
        ? json['fileSize'] as int
        : int.tryParse(json['fileSize']?.toString() ?? ''),
    fileName: json['fileName']?.toString(),
  );
}

class MessageRecord {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String type; // text, image, video, voice, file
  final String? text;
  final DateTime createdAt;
  final DateTime? readAt;
  final List<AttachmentDto> attachments;
  final String? myReaction;
  final Map<String, dynamic>? replyTo;

  MessageRecord({
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
    this.replyTo,
  });

  factory MessageRecord.fromJson(Map<String, dynamic> json) => MessageRecord(
    id: (json['id'] ?? '').toString(),
    conversationId: (json['conversation_id'] ?? '').toString(),
    senderId: (json['sender_id'] ?? '').toString(),
    receiverId: (json['receiver_id'] ?? '').toString(),
    type: (json['type'] ?? 'text').toString(),
    text: json['text']?.toString(),
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    readAt: json['read_at'] != null
        ? DateTime.tryParse(json['read_at'].toString())
        : null,
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => AttachmentDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    myReaction: json['my_reaction']?.toString(),
    replyTo: json['reply_to'] != null
        ? Map<String, dynamic>.from(json['reply_to'] as Map)
        : null,
  );
}

class MessagesApi {
  final Dio _dio = ApiClient().dio;

  Future<List<MessageRecord>> list(
    String conversationId, {
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/api/messages/$conversationId',
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
    String? otherUserId,
    required String text,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{'type': 'text', 'text': text};
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (otherUserId != null) body['other_user_id'] = otherUserId;
    if (replyToMessageId != null) {
      body['reply_to_message_id'] = replyToMessageId;
    }

    final res = await _dio.post('/api/messages', data: body);
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final msg = Map<String, dynamic>.from(data['message'] ?? {});
    return MessageRecord.fromJson(msg);
  }

  Future<MessageRecord> sendTextWithMedia({
    String? conversationId,
    String? otherUserId,
    required String text,
    required List<Map<String, dynamic>> attachments,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{
      'type': 'text', // Keep as text type but with attachments
      'text': text,
      'attachments': attachments,
    };
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (otherUserId != null) body['other_user_id'] = otherUserId;
    if (replyToMessageId != null) {
      body['reply_to_message_id'] = replyToMessageId;
    }

    final res = await _dio.post('/api/messages', data: body);
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final msg = Map<String, dynamic>.from(data['message'] ?? {});
    return MessageRecord.fromJson(msg);
  }

  Future<MessageRecord> sendVoice({
    String? conversationId,
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
    if (otherUserId != null) body['other_user_id'] = otherUserId;
    if (replyToMessageId != null) {
      body['reply_to_message_id'] = replyToMessageId;
    }

    final res = await _dio.post('/api/messages', data: body);
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final msg = Map<String, dynamic>.from(data['message'] ?? {});
    return MessageRecord.fromJson(msg);
  }

  Future<void> react(String messageId, String? emoji) async {
    await _dio.post(
      '/api/messages/$messageId/react',
      data: emoji == null ? {} : {'emoji': emoji},
    );
  }

  Future<void> markRead(String messageId) async {
    await _dio.post('/api/messages/$messageId/read');
  }

  Future<void> delete(String messageId) async {
    await _dio.delete('/api/messages/$messageId');
  }
}
