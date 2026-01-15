import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'mentorship_message_lite.g.dart';

/// Lightweight mentorship message model for local Isar storage.
@collection
class MentorshipMessageLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  @Index()
  late String conversationId;

  late String senderId;
  String? senderName;
  String? senderPhotoUrl;

  /// Message type: 'text', 'image', 'video', 'voice', 'file'
  String type = 'text';

  String? text;
  String? mediaUrl;
  String? mediaThumbUrl;

  String? fileName;
  int? fileSize;
  String? fileMimeType;
  int? voiceDurationSeconds;

  @Index()
  late DateTime createdAt;

  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';
  String? localMediaPath;

  MentorshipMessageLite();

  factory MentorshipMessageLite.fromFirestore(
    String docId,
    Map<String, dynamic> data,
    String convId,
  ) {
    final msg = MentorshipMessageLite()
      ..id = docId
      ..conversationId = convId
      ..senderId = data['senderId'] as String? ?? ''
      ..senderName = data['senderName'] as String?
      ..type = data['type'] as String? ?? 'text'
      ..text = data['text'] as String?
      ..mediaUrl = data['mediaUrl'] as String?
      ..mediaThumbUrl = data['thumbUrl'] as String?
      ..fileName = data['fileName'] as String?
      ..fileSize = _safeIntOrNull(data['fileSize'])
      ..fileMimeType = data['mimeType'] as String?
      ..voiceDurationSeconds = _safeIntOrNull(data['duration'])
      ..createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now()
      ..updatedAt = _parseTimestamp(data['updatedAt'])
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    return msg;
  }

  factory MentorshipMessageLite.fromMap(Map<String, dynamic> data) {
    final msg = MentorshipMessageLite()
      ..id = data['id'] as String? ?? ''
      ..conversationId = data['conversationId'] as String? ?? ''
      ..senderId = data['senderId'] as String? ?? ''
      ..senderName = data['senderName'] as String?
      ..type = data['type'] as String? ?? 'text'
      ..text = data['text'] as String?
      ..mediaUrl = data['mediaUrl'] as String?
      ..mediaThumbUrl = data['mediaThumbUrl'] as String?
      ..fileName = data['fileName'] as String?
      ..fileSize = _safeIntOrNull(data['fileSize'])
      ..voiceDurationSeconds = _safeIntOrNull(data['voiceDurationSeconds'])
      ..syncStatus = data['syncStatus'] as String? ?? 'synced';

    msg.createdAt = _parseMapTimestamp(data['createdAt']) ?? DateTime.now();
    msg.updatedAt = _parseMapTimestamp(data['updatedAt']);

    return msg;
  }

  factory MentorshipMessageLite.pending({
    required String id,
    required String conversationId,
    required String senderId,
    required String type,
    String? text,
    String? localMediaPath,
    String? fileName,
    int? fileSize,
    int? voiceDurationSeconds,
  }) {
    return MentorshipMessageLite()
      ..id = id
      ..conversationId = conversationId
      ..senderId = senderId
      ..type = type
      ..text = text
      ..localMediaPath = localMediaPath
      ..fileName = fileName
      ..fileSize = fileSize
      ..voiceDurationSeconds = voiceDurationSeconds
      ..createdAt = DateTime.now()
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'pending';
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaThumbUrl': mediaThumbUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'voiceDurationSeconds': voiceDurationSeconds,
      'createdAt': createdAt,
      'syncStatus': syncStatus,
      'localMediaPath': localMediaPath,
    };
  }

  static int? _safeIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final seconds = (value as dynamic).seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }

  static DateTime? _parseMapTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
