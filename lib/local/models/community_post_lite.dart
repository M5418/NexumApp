import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'community_post_lite.g.dart';

/// Lightweight community post model for local Isar storage.
/// Same as PostLite but with communityId index for filtering.
@collection
class CommunityPostLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  late String authorId;
  String? authorName;
  String? authorPhotoUrl;

  String? caption;

  List<String> mediaThumbUrls = [];
  List<String> mediaUrls = [];
  List<String> mediaTypes = [];

  int likeCount = 0;
  int commentCount = 0;
  int shareCount = 0;
  int repostCount = 0;
  int bookmarkCount = 0;

  String? repostOf;

  @Index()
  late String communityId;

  @Index()
  late DateTime createdAt;

  @Index()
  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';

  CommunityPostLite();

  factory CommunityPostLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final post = CommunityPostLite()
      ..id = docId
      ..authorId = data['authorId'] as String? ?? ''
      ..authorName = data['authorName'] as String?
      ..authorPhotoUrl = data['authorAvatarUrl'] as String?
      ..caption = data['text'] as String?
      ..communityId = data['communityId'] as String? ?? ''
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

    // Parse counts
    final summary = data['summary'];
    if (summary is Map) {
      post.likeCount = _safeInt(summary['likes']);
      post.commentCount = _safeInt(summary['comments']);
      post.shareCount = _safeInt(summary['shares']);
      post.repostCount = _safeInt(summary['reposts']);
      post.bookmarkCount = _safeInt(summary['bookmarks']);
    }

    post.createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now();
    post.updatedAt = _parseTimestamp(data['updatedAt']);

    return post;
  }

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
      'communityId': communityId,
      'createdAt': createdAt,
      'syncStatus': syncStatus,
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

