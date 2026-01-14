// Stub file for PodcastLite on web platform

class PodcastLite {
  String id = '';
  String title = '';
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
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime localUpdatedAt = DateTime.now();
  String syncStatus = 'synced';

  PodcastLite();

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

    podcast.createdAt = _parseTimestamp(data['createdAt']);
    podcast.updatedAt = _parseTimestamp(data['updatedAt']);

    return podcast;
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
