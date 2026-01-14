import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'message_lite.g.dart';

/// Lightweight message model for local Isar storage.
@collection
class MessageLite {
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

  /// File metadata (for file messages)
  String? fileName;
  int? fileSize;
  String? fileMimeType;

  /// Voice message duration in seconds
  int? voiceDurationSeconds;

  @Index()
  late DateTime createdAt;

  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  /// Write status: 'synced', 'pending', 'failed'
  @Index()
  String syncStatus = 'synced';

  /// For optimistic writes - local path before upload
  String? localMediaPath;

  MessageLite();

  factory MessageLite.fromFirestore(
    String docId,
    Map<String, dynamic> data,
    String convId,
  ) {
    final msg = MessageLite()
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

  /// Create a pending message for optimistic write
  factory MessageLite.pending({
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
    return MessageLite()
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

  /// Convert to Firestore payload for upload
  Map<String, dynamic> toFirestorePayload() {
    return {
      'senderId': senderId,
      'type': type,
      if (text != null) 'text': text,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaThumbUrl != null) 'thumbUrl': mediaThumbUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (fileMimeType != null) 'mimeType': fileMimeType,
      if (voiceDurationSeconds != null) 'duration': voiceDurationSeconds,
      'createdAt': createdAt,
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
}

