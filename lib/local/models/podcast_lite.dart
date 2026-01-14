import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'podcast_lite.g.dart';

/// Lightweight podcast model for local Isar storage.
@collection
class PodcastLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  late String title;
  String? author;
  String? authorId;
  String? description;
  String? coverUrl;
  String? coverThumbUrl;
  String? audioUrl;

  int durationSeconds = 0;
  String? category;
  String? language;

  bool isPublished = true;

  @Index()
  DateTime? createdAt;

  @Index()
  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';

  PodcastLite();

  factory PodcastLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final podcast = PodcastLite()
      ..id = docId
      ..title = data['title'] as String? ?? ''
      ..author = data['author'] as String?
      ..authorId = data['authorId'] as String?
      ..description = data['description'] as String?
      ..coverUrl = data['coverUrl'] as String?
      ..coverThumbUrl = data['coverThumbUrl'] as String?
      ..audioUrl = data['audioUrl'] as String?
      ..durationSeconds = _safeInt(data['duration'])
      ..category = data['category'] as String?
      ..language = data['language'] as String?
      ..isPublished = data['isPublished'] != false
      ..createdAt = _parseTimestamp(data['createdAt'])
      ..updatedAt = _parseTimestamp(data['updatedAt'])
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    return podcast;
  }

  /// Create from a simple Map (for Hive/web storage)
  factory PodcastLite.fromMap(Map<String, dynamic> data) {
    final podcast = PodcastLite()
      ..id = data['id'] as String? ?? ''
      ..title = data['title'] as String? ?? ''
      ..author = data['author'] as String?
      ..authorId = data['authorId'] as String?
      ..description = data['description'] as String?
      ..coverUrl = data['coverUrl'] as String?
      ..coverThumbUrl = data['coverThumbUrl'] as String?
      ..audioUrl = data['audioUrl'] as String?
      ..durationSeconds = _safeInt(data['durationSeconds'])
      ..category = data['category'] as String?
      ..language = data['language'] as String?
      ..isPublished = data['isPublished'] as bool? ?? true;

    podcast.createdAt = _parseMapTimestamp(data['createdAt']);
    podcast.updatedAt = _parseMapTimestamp(data['updatedAt']);

    return podcast;
  }

  static DateTime? _parseMapTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'coverUrl': coverUrl,
      'coverThumbUrl': coverThumbUrl,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'category': category,
      'language': language,
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    return 0;
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

