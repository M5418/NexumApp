// Web-compatible CommunityPostLite model (no Isar annotations)

class CommunityPostLite {
  String id = '';
  String authorId = '';
  String? authorName;
  String? authorPhotoUrl;
  String? caption;
  List<String> mediaUrls = [];
  List<String> mediaThumbUrls = [];
  List<String> mediaTypes = [];
  String? repostOf;
  String communityId = '';
  int likeCount = 0;
  int commentCount = 0;
  int shareCount = 0;
  int repostCount = 0;
  int bookmarkCount = 0;
  DateTime createdAt = DateTime.now();
  DateTime? updatedAt;
  DateTime localUpdatedAt = DateTime.now();
  String syncStatus = 'synced';

  CommunityPostLite();

  factory CommunityPostLite.fromMap(Map<String, dynamic> data) {
    final post = CommunityPostLite()
      ..id = data['id'] as String? ?? ''
      ..authorId = data['authorId'] as String? ?? ''
      ..authorName = data['authorName'] as String?
      ..authorPhotoUrl = data['authorPhotoUrl'] as String?
      ..caption = data['caption'] as String?
      ..repostOf = data['repostOf'] as String?
      ..communityId = data['communityId'] as String? ?? ''
      ..likeCount = _safeInt(data['likeCount'])
      ..commentCount = _safeInt(data['commentCount'])
      ..shareCount = _safeInt(data['shareCount'])
      ..repostCount = _safeInt(data['repostCount'])
      ..bookmarkCount = _safeInt(data['bookmarkCount'])
      ..syncStatus = data['syncStatus'] as String? ?? 'synced';

    final mediaUrls = data['mediaUrls'];
    if (mediaUrls is List) {
      post.mediaUrls = mediaUrls.map((e) => e.toString()).toList();
    }

    final mediaThumbUrls = data['mediaThumbUrls'];
    if (mediaThumbUrls is List) {
      post.mediaThumbUrls = mediaThumbUrls.map((e) => e.toString()).toList();
    }

    final mediaTypes = data['mediaTypes'];
    if (mediaTypes is List) {
      post.mediaTypes = mediaTypes.map((e) => e.toString()).toList();
    }

    post.createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now();
    post.updatedAt = _parseTimestamp(data['updatedAt']);

    return post;
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
