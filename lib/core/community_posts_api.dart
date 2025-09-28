import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/post.dart';
import '../models/comment.dart';

class CommunityPostsApi {
  final Dio _dio = ApiClient().dio;

  // List posts for a community
  Future<List<Post>> list(String communityId, {int limit = 20, int offset = 0}) async {
    debugPrint('🧩 CommunityPostsApi.list: communityId=$communityId, limit=$limit, offset=$offset');

    final res = await _dio.get(
      '/api/communities/$communityId/posts',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    final body = Map<String, dynamic>.from(res.data ?? {});
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final posts = (data['posts'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_toPost)
        .toList();

    debugPrint('🧩 CommunityPostsApi.list: parsed ${posts.length} posts');
    return posts;
    }

  // Create a post in a community
  Future<Map<String, dynamic>> create({
    required String communityId,
    required String content,
    List<Map<String, dynamic>>? media,
    String? repostOf,
  }) async {
    debugPrint('🧩 CommunityPostsApi.create: communityId=$communityId');

    final payload = <String, dynamic>{'content': content};

    if (media != null && media.isNotEmpty) {
      final images = media.where((m) => (m['type'] ?? '').toString() == 'image').toList();
      final videos = media.where((m) => (m['type'] ?? '').toString() == 'video').toList();

      if (videos.isNotEmpty) {
        payload['post_type'] = 'text_video';
        payload['video_url'] = videos.first['url'];
      } else if (images.length > 1) {
        payload['post_type'] = 'text_photo';
        payload['image_urls'] = images.map((m) => m['url']).toList();
      } else if (images.length == 1) {
        payload['post_type'] = 'text_photo';
        payload['image_url'] = images.first['url'];
      } else {
        payload['post_type'] = 'text';
      }
    } else {
      payload['post_type'] = 'text';
    }

    if (repostOf != null) payload['repost_of'] = repostOf;

    final res = await _dio.post('/api/communities/$communityId/posts', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Post?> getPost(String communityId, String postId) async {
    try {
      final res = await _dio.get('/api/communities/$communityId/posts/$postId');
      final raw = res.data;

      Map<String, dynamic>? p;
      if (raw is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(raw['data'] ?? raw);
        if (data['post'] is Map) {
          p = Map<String, dynamic>.from(data['post']);
        } else if (data['data'] is Map) {
          p = Map<String, dynamic>.from(data['data']);
        } else if (raw['post'] is Map) {
          p = Map<String, dynamic>.from(raw['post']);
        }
      }
      return p != null ? _toPost(p) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> like(String communityId, String postId) async {
    await _dio.post('/api/communities/$communityId/posts/$postId/like');
  }

  Future<void> unlike(String communityId, String postId) async {
    await _dio.delete('/api/communities/$communityId/posts/$postId/like');
  }

  Future<void> bookmark(String communityId, String postId) async {
    await _dio.post('/api/communities/$communityId/posts/$postId/bookmark');
  }

  Future<void> unbookmark(String communityId, String postId) async {
    await _dio.delete('/api/communities/$communityId/posts/$postId/bookmark');
  }

  Future<void> repost(String communityId, String postId) async {
    try {
      await _dio.post('/api/communities/$communityId/posts/$postId/repost');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback to create with repost_of when specific endpoint missing
        await create(communityId: communityId, content: '', repostOf: postId);
        return;
      }
      rethrow;
    }
  }

  Future<void> unrepost(String communityId, String postId) async {
    await _dio.delete('/api/communities/$communityId/posts/$postId/repost');
  }

  // Comments
  Future<List<Comment>> listComments(String communityId, String postId) async {
    final res = await _dio.get('/api/communities/$communityId/posts/$postId/comments');
    final body = Map<String, dynamic>.from(res.data ?? {});
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final list = (data['comments'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    DateTime parseCreatedAt(dynamic v) {
      if (v == null) return DateTime.now();
      final s = v.toString();
      final iso = DateTime.tryParse(s);
      if (iso != null) return iso;
      final m = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$',
      ).firstMatch(s);
      if (m != null) {
        final year = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final day = int.parse(m.group(3)!);
        final hour = int.parse(m.group(4)!);
        final minute = int.parse(m.group(5)!);
        final second = int.parse(m.group(6)!);
        final ms = int.tryParse(m.group(7) ?? '0') ?? 0;
        return DateTime.utc(year, month, day, hour, minute, second, ms);
      }
      return DateTime.now();
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final flat = <String, Comment>{};
    final parentOf = <String, String?>{};

    for (final c in list) {
      final author = Map<String, dynamic>.from(c['author'] ?? {});
      final me = Map<String, dynamic>.from(c['me'] ?? {});
      final id = (c['id'] ?? '').toString();
      final parentIdRaw = c['parent_comment_id'];
      final parentId = parentIdRaw?.toString();
      parentOf[id] = parentId;

      flat[id] = Comment(
        id: id,
        userId: (c['user_id'] ?? '').toString(),
        userName: (author['name'] ?? 'User').toString(),
        userAvatarUrl: (author['avatarUrl'] ?? '').toString(),
        text: (c['content'] ?? '').toString(),
        createdAt: parseCreatedAt(c['created_at']),
        likesCount: toInt(c['likes_count']),
        isLikedByUser: (me['liked'] ?? false) as bool,
        replies: const [],
        parentCommentId: parentId,
        isPinned: false,
        isCreator: false,
      );
    }

    final children = <String, List<Comment>>{};
    for (final entry in flat.entries) {
      final id = entry.key;
      final parentId = parentOf[id];
      if (parentId != null && flat.containsKey(parentId)) {
        children.putIfAbsent(parentId, () => <Comment>[]).add(entry.value);
      }
    }

    List<Comment> buildTree(Comment parent) {
      final kids = children[parent.id] ?? const <Comment>[];
      return kids.map((c) => c.copyWith(replies: buildTree(c))).toList();
    }

    final topLevel = flat.values
        .where((c) => c.parentCommentId == null)
        .map((c) => c.copyWith(replies: buildTree(c)))
        .toList();

    return topLevel;
  }

  Future<void> addComment(
    String communityId,
    String postId, {
    required String content,
    String? parentCommentId,
  }) async {
    final payload = <String, dynamic>{'content': content};
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      payload['parent_comment_id'] = parentCommentId;
    }
    await _dio.post('/api/communities/$communityId/posts/$postId/comments', data: payload);
  }

  Future<void> likeComment(String communityId, String postId, String commentId) async {
    await _dio.post('/api/communities/$communityId/posts/$postId/comments/$commentId/like');
  }

  Future<void> unlikeComment(String communityId, String postId, String commentId) async {
    await _dio.delete('/api/communities/$communityId/posts/$postId/comments/$commentId/like');
  }

  Future<void> deleteComment(String communityId, String postId, String commentId) async {
    await _dio.delete('/api/communities/$communityId/posts/$postId/comments/$commentId');
  }

  // Copy of PostsApi._toPost to keep structure identical
  Post _toPost(Map<String, dynamic> p) {
    final original = Map<String, dynamic>.from(
      p['original_post'] ??
      p['originalPost'] ??
      p['original'] ??
      p['repost_of_post'] ??
      {},
    );

    Map<String, dynamic> syntheticOriginal = {};
    if (original.isEmpty) {
      final origAuthor = (p['original_author'] is Map)
          ? Map<String, dynamic>.from(p['original_author'])
          : {};
      final origImageUrls = p['original_image_urls'];
      final origImageUrl = p['original_image_url'];
      final origVideoUrl = p['original_video_url'];
      final origContent =
          p['original_content'] ?? p['orig_content'] ?? p['source_content'];
      if (origAuthor.isNotEmpty ||
          origContent != null ||
          origImageUrl != null ||
          origImageUrls != null ||
          origVideoUrl != null) {
        syntheticOriginal = {
          if (origContent != null) 'content': origContent,
          if (origAuthor.isNotEmpty) 'author': origAuthor,
          if (origImageUrl != null) 'image_url': origImageUrl,
          if (origImageUrls != null) 'image_urls': origImageUrls,
          if (origVideoUrl != null) 'video_url': origVideoUrl,
        };
      }
    }

    final contentSource =
        original.isNotEmpty ? original : (syntheticOriginal.isNotEmpty ? syntheticOriginal : p);

    Map<String, dynamic> authorFrom(Map<String, dynamic> src) {
      final a = Map<String, dynamic>.from(src['author'] ?? {});
      if (a.isNotEmpty) return a;
      final oa = Map<String, dynamic>.from(src['original_author'] ?? {});
      if (oa.isNotEmpty) return oa;
      return {};
    }

    final author = authorFrom(contentSource);

    Map<String, dynamic> countsMap = {};
    if (contentSource['counts'] is Map) {
      countsMap = Map<String, dynamic>.from(contentSource['counts']);
    } else if (p['counts'] is Map) {
      countsMap = Map<String, dynamic>.from(p['counts']);
    } else {
      countsMap = {
        'likes': p['likes_count'] ?? 0,
        'comments': p['comments_count'] ?? 0,
        'shares': p['shares_count'] ?? 0,
        'reposts': p['reposts_count'] ?? 0,
        'bookmarks': p['bookmarks_count'] ?? 0,
      };
    }

    final me = Map<String, dynamic>.from(p['me'] ?? {});

    DateTime parseCreatedAt(dynamic v) {
      if (v == null) return DateTime.now();
      final s = v.toString();
      final iso = DateTime.tryParse(s);
      if (iso != null) return iso;
      final m = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$',
      ).firstMatch(s);
      if (m != null) {
        final year = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final day = int.parse(m.group(3)!);
        final hour = int.parse(m.group(4)!);
        final minute = int.parse(m.group(5)!);
        final second = int.parse(m.group(6)!);
        final ms = int.tryParse(m.group(7) ?? '0') ?? 0;
        return DateTime.utc(year, month, day, hour, minute, second, ms);
      }
      return DateTime.now();
    }

    MediaType mediaType = MediaType.none;
    String? videoUrl;
    List<String> imageUrls = [];

    List<dynamic> mediaList = [];
    if (contentSource['media'] is List) {
      mediaList = List<dynamic>.from(contentSource['media']);
    } else if (p['media'] is List) {
      mediaList = List<dynamic>.from(p['media']);
    }

    if (mediaList.isNotEmpty) {
      final asMaps = mediaList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final videos = asMaps.where((m) {
        final t = (m['type'] ?? m['kind'] ?? '').toString().toLowerCase();
        return t.contains('video');
      }).toList();

      final images = asMaps.where((m) {
        final t = (m['type'] ?? m['kind'] ?? '').toString().toLowerCase();
        return t.contains('image') || t.contains('photo') || t.isEmpty;
      }).toList();

      String? urlOf(Map<String, dynamic> m) =>
          (m['url'] ?? m['src'] ?? m['link'] ?? '').toString();

      if (videos.isNotEmpty) {
        mediaType = MediaType.video;
        videoUrl = urlOf(videos.first);
      } else if (images.length > 1) {
        mediaType = MediaType.images;
        imageUrls = images
            .map(urlOf)
            .whereType<String>()
            .where((u) => u.isNotEmpty)
            .toList();
      } else if (images.length == 1) {
        mediaType = MediaType.image;
        final u = urlOf(images.first);
        if (u != null && u.isNotEmpty) imageUrls = [u];
      }
    } else if (contentSource['video_url'] != null &&
        contentSource['video_url'].toString().isNotEmpty) {
      mediaType = MediaType.video;
      videoUrl = contentSource['video_url'].toString();
    } else if (contentSource['image_urls'] != null) {
      final urls = (contentSource['image_urls'] as List<dynamic>? ?? [])
          .map((url) => url.toString())
          .where((url) => url.isNotEmpty)
          .toList();
      if (urls.length > 1) {
        mediaType = MediaType.images;
        imageUrls = urls;
      } else if (urls.length == 1) {
        mediaType = MediaType.image;
        imageUrls = urls;
      }
    } else if (contentSource['image_url'] != null &&
        contentSource['image_url'].toString().isNotEmpty) {
      mediaType = MediaType.image;
      imageUrls = [contentSource['image_url'].toString()];
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final repostAuthorRaw = Map<String, dynamic>.from(
      p['repost_author'] ??
      p['reposter'] ??
      p['reposted_by_user'] ??
      p['repostAuthor'] ??
      p['repost_user'] ??
      {},
    );

    final isRepost =
        p['repost_of'] != null || (p['is_repost'] == true || p['isRepost'] == true);

    final originalPostId = (p['repost_of'] ??
        p['repostOf'] ??
        original['id'] ??
        original['post_id'] ??
        original['postId'])
        ?.toString();

    final isSelfRepostRow = (me['is_repost_author'] == true);

    final repostedBy = repostAuthorRaw.isNotEmpty
        ? RepostedBy(
            userName:
                (repostAuthorRaw['name'] ?? repostAuthorRaw['username'] ?? 'User')
                    .toString(),
            userAvatarUrl:
                (repostAuthorRaw['avatarUrl'] ?? repostAuthorRaw['avatar_url'] ?? '')
                    .toString(),
            actionType: isSelfRepostRow ? 'reposted this' : null,
          )
        : null;

    final authorName =
        (author['name'] ?? author['username'] ?? 'User').toString();
    final authorAvatar =
        (author['avatarUrl'] ?? author['avatar_url'] ?? '').toString();

    final text = (contentSource['content'] ??
        contentSource['text'] ??
        p['original_content'] ??
        p['text'] ??
        p['content'] ??
        '')
        .toString();

    return Post(
      id: (p['id'] ?? '').toString(),
      userName: authorName,
      userAvatarUrl: authorAvatar,
      createdAt: parseCreatedAt(
        p['created_at'] ??
            p['createdAt'] ??
            contentSource['created_at'] ??
            contentSource['createdAt'],
      ),
      text: text,
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: toInt(countsMap['likes']),
        comments: toInt(countsMap['comments']),
        shares: toInt(countsMap['shares']),
        reposts: toInt(countsMap['reposts']),
        bookmarks: toInt(countsMap['bookmarks']),
      ),
      userReaction: (me['liked'] == true) ? ReactionType.like : null,
      isBookmarked: (me['bookmarked'] ?? false) as bool,
      isRepost: isRepost,
      repostedBy: repostedBy,
      originalPostId: originalPostId,
    );
  }
}