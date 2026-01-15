// Web-compatible StoryLite model (no Isar annotations)

class StoryLite {
  String id = '';
  String authorId = '';
  String? authorName;
  String? authorPhotoUrl;
  String type = 'image';
  String? mediaUrl;
  String? mediaThumbUrl;
  String? text;
  String? backgroundColor;
  int? durationSeconds;
  DateTime createdAt = DateTime.now();
  DateTime expiresAt = DateTime.now().add(const Duration(hours: 24));
  DateTime localUpdatedAt = DateTime.now();
  String syncStatus = 'synced';
  int viewCount = 0;
  bool viewed = false;

  StoryLite();

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

    story.createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now();
    story.expiresAt = _parseTimestamp(data['expiresAt']) ?? 
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
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
