import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'story_lite.g.dart';

/// Lightweight story model for local Isar storage.
@collection
class StoryLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  late String authorId;
  String? authorName;
  String? authorPhotoUrl;

  /// Story type: 'image', 'video', 'text'
  String type = 'image';

  String? mediaUrl;
  String? mediaThumbUrl;
  String? text;
  String? backgroundColor;

  /// Duration in seconds (for video)
  int? durationSeconds;

  @Index()
  late DateTime createdAt;

  /// Story expires after 24 hours
  late DateTime expiresAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';

  /// View count
  int viewCount = 0;

  /// Has current user viewed this story
  bool viewed = false;

  StoryLite();

  factory StoryLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final story = StoryLite()
      ..id = docId
      ..authorId = data['authorId'] as String? ?? ''
      ..authorName = data['authorName'] as String?
      ..authorPhotoUrl = data['authorPhotoUrl'] as String?
      ..type = data['type'] as String? ?? 'image'
      ..mediaUrl = data['mediaUrl'] as String?
      ..mediaThumbUrl = data['thumbUrl'] as String?
      ..text = data['text'] as String?
      ..backgroundColor = data['backgroundColor'] as String?
      ..durationSeconds = _safeIntOrNull(data['duration'])
      ..viewCount = _safeInt(data['viewCount'])
      ..createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now()
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    // Calculate expiry (24 hours from creation)
    story.expiresAt = story.createdAt.add(const Duration(hours: 24));

    return story;
  }

  factory StoryLite.fromMap(Map<String, dynamic> data) {
    final story = StoryLite()
      ..id = data['id'] as String? ?? ''
      ..authorId = data['authorId'] as String? ?? ''
      ..authorName = data['authorName'] as String?
      ..authorPhotoUrl = data['authorPhotoUrl'] as String?
      ..type = data['type'] as String? ?? 'image'
      ..mediaUrl = data['mediaUrl'] as String?
      ..mediaThumbUrl = data['mediaThumbUrl'] as String?
      ..text = data['text'] as String?
      ..backgroundColor = data['backgroundColor'] as String?
      ..durationSeconds = _safeIntOrNull(data['durationSeconds'])
      ..viewCount = _safeInt(data['viewCount'])
      ..viewed = data['viewed'] as bool? ?? false
      ..syncStatus = data['syncStatus'] as String? ?? 'synced';

    story.createdAt = _parseMapTimestamp(data['createdAt']) ?? DateTime.now();
    story.expiresAt = _parseMapTimestamp(data['expiresAt']) ?? 
        story.createdAt.add(const Duration(hours: 24));

    return story;
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'type': type,
      'mediaUrl': mediaUrl,
      'mediaThumbUrl': mediaThumbUrl,
      'text': text,
      'backgroundColor': backgroundColor,
      'durationSeconds': durationSeconds,
      'viewCount': viewCount,
      'viewed': viewed,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
