import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'post_lite.g.dart';

/// Lightweight post model for local Isar storage.
/// Contains only what UI needs for instant rendering.
@collection
class PostLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  late String authorId;
  String? authorName;
  String? authorPhotoUrl;

  String? caption;

  /// Thumbnail URLs for fast feed rendering
  List<String> mediaThumbUrls = [];

  /// Full media URLs (loaded on demand)
  List<String> mediaUrls = [];

  /// Media types: 'image', 'video'
  List<String> mediaTypes = [];

  /// Engagement counts
  int likeCount = 0;
  int commentCount = 0;
  int shareCount = 0;
  int repostCount = 0;
  int bookmarkCount = 0;

  /// Repost info
  String? repostOf;
  String? repostAuthorId;
  String? repostAuthorName;

  /// Community association (null for regular posts)
  String? communityId;

  @Index()
  late DateTime createdAt;

  @Index()
  DateTime? updatedAt;

  /// Local sync status
  @Index()
  late DateTime localUpdatedAt;

  /// Write status: 'synced', 'pending', 'failed'
  @Index()
  String syncStatus = 'synced';

  PostLite();

  /// Create from Firestore document data
  factory PostLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final post = PostLite()
      ..id = docId
      ..authorId = data['authorId'] as String? ?? ''
      ..authorName = data['authorName'] as String?
      ..authorPhotoUrl = data['authorAvatarUrl'] as String?
      ..caption = data['text'] as String?
      ..communityId = data['communityId'] as String?
      ..repostOf = data['repostOf'] as String?
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    // Parse media
    final mediaUrlsRaw = data['mediaUrls'];
    if (mediaUrlsRaw is List) {
      post.mediaUrls = mediaUrlsRaw.map((e) => e.toString()).toList();
    }

    // Parse media thumbs
    final thumbsRaw = data['mediaThumbs'];
    if (thumbsRaw is List) {
      for (final thumb in thumbsRaw) {
        if (thumb is Map) {
          final thumbUrl = thumb['thumbUrl'] as String?;
          final type = thumb['type'] as String? ?? 'image';
          if (thumbUrl != null) {
            post.mediaThumbUrls.add(thumbUrl);
            post.mediaTypes.add(type);
          }
        }
      }
    } else if (post.mediaUrls.isNotEmpty) {
      // Fallback: use mediaUrls as thumbs
      post.mediaThumbUrls = List.from(post.mediaUrls);
      post.mediaTypes = post.mediaUrls.map((url) {
        final l = url.toLowerCase();
        if (l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') ||
            l.contains('/videos/') || l.contains('video_')) {
          return 'video';
        }
        return 'image';
      }).toList();
    }

    // Parse counts from summary
    final summary = data['summary'];
    if (summary is Map) {
      post.likeCount = _safeInt(summary['likes']);
      post.commentCount = _safeInt(summary['comments']);
      post.shareCount = _safeInt(summary['shares']);
      post.repostCount = _safeInt(summary['reposts']);
      post.bookmarkCount = _safeInt(summary['bookmarks']);
    }

    // Parse timestamps
    post.createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now();
    post.updatedAt = _parseTimestamp(data['updatedAt']);

    return post;
  }

  /// Create from a simple Map (for Hive/web storage)
  factory PostLite.fromMap(Map<String, dynamic> data) {
    final post = PostLite()
      ..id = data['id'] as String? ?? ''
      ..authorId = data['authorId'] as String? ?? ''
      ..authorName = data['authorName'] as String?
      ..authorPhotoUrl = data['authorPhotoUrl'] as String?
      ..caption = data['caption'] as String?
      ..repostOf = data['repostOf'] as String?
      ..communityId = data['communityId'] as String?
      ..likeCount = _safeInt(data['likeCount'])
      ..commentCount = _safeInt(data['commentCount'])
      ..shareCount = _safeInt(data['shareCount'])
      ..repostCount = _safeInt(data['repostCount'])
      ..bookmarkCount = _safeInt(data['bookmarkCount'])
      ..syncStatus = data['syncStatus'] as String? ?? 'synced';

    // Parse lists
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

    // Parse timestamps
    post.createdAt = _parseMapTimestamp(data['createdAt']) ?? DateTime.now();
    post.updatedAt = _parseMapTimestamp(data['updatedAt']);
    final localUpdated = _parseMapTimestamp(data['localUpdatedAt']);
    if (localUpdated != null) {
      post.localUpdatedAt = localUpdated;
    }

    return post;
  }

  static DateTime? _parseMapTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Convert to map for display (matches existing Post model structure)
  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'caption': caption,
      'mediaThumbUrls': mediaThumbUrls,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'repostCount': repostCount,
      'bookmarkCount': bookmarkCount,
      'repostOf': repostOf,
      'communityId': communityId,
      'createdAt': createdAt,
      'syncStatus': syncStatus,
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // Firestore Timestamp
    if (value is Map && value['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value['_seconds'] as int) * 1000,
      );
    }
    // Handle Firestore Timestamp object
    try {
      final seconds = (value as dynamic).seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}

