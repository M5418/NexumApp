import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/post.dart';
import '../models/comment.dart';

class PostsApi {
  final Dio _dio = ApiClient().dio;

  Future<List<Post>> listFeed({int limit = 20, int offset = 0}) async {
    debugPrint('📝 PostsApi.listFeed: Starting to fetch feed...');
    debugPrint('📝 PostsApi.listFeed called with limit: $limit, offset: $offset');

    final res = await _dio.get(
      '/api/posts',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    debugPrint('📝 PostsApi.listFeed: Response status: ${res.statusCode}');
    debugPrint('📝 PostsApi.listFeed: Response data type: ${res.data.runtimeType}');
    debugPrint('📝 PostsApi.listFeed: Response data: ${res.data}');

    final body = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});

    final posts = (data['posts'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_toPost)
        .toList();

    debugPrint('📝 PostsApi.listFeed: Successfully parsed ${posts.length} posts');
    for (int i = 0; i < posts.length && i < 3; i++) {
      final p = posts[i];
      final preview = p.text.length > 50 ? p.text.substring(0, 50) : p.text;
      debugPrint('📝 Post $i: id=${p.id}, user=${p.userName}, content=$preview');
    }

    return posts;
  }

  Future<Map<String, dynamic>> create({
    required String content,
    List<Map<String, dynamic>>? media,
    String? repostOf,
  }) async {
    debugPrint('📝 PostsApi.create: Starting to create post...');
    final payload = <String, dynamic>{'content': content};

    if (media != null && media.isNotEmpty) {
      final images = media.where((m) => m['type'] == 'image').toList();
      final videos = media.where((m) => m['type'] == 'video').toList();

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

    final res = await _dio.post('/api/posts', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> like(String postId) async {
    await _dio.post('/api/posts/$postId/like');
  }

  Future<void> unlike(String postId) async {
    await _dio.delete('/api/posts/$postId/like');
  }

  Future<void> bookmark(String postId) async {
    await _dio.post('/api/posts/$postId/bookmark');
  }

  Future<void> unbookmark(String postId) async {
    await _dio.delete('/api/posts/$postId/bookmark');
  }

  // Repost: create (fallback to create(repost_of) if /repost route is missing)
  Future<void> repost(String postId) async {
    try {
      await _dio.post('/api/posts/$postId/repost');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback for servers that don't expose /:postId/repost
        await create(content: '', repostOf: postId);
        return;
      }
      rethrow;
    }
  }

  // Repost: remove (no safe fallback without a specific API)
  Future<void> unrepost(String postId) async {
    await _dio.delete('/api/posts/$postId/repost');
  }

  // Single post fetch (used for client-side hydration of reposts)
  Future<Post?> getPost(String id) async {
    try {
      final res = await _dio.get('/api/posts/$id');
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

  // Comments: list
  Future<List<Comment>> listComments(String postId) async {
    final res = await _dio.get('/api/posts/$postId/comments');
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

  // Comments: create
  Future<void> addComment(
    String postId, {
    required String content,
    String? parentCommentId,
  }) async {
    final payload = <String, dynamic>{'content': content};
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      payload['parent_comment_id'] = parentCommentId;
    }
    await _dio.post('/api/posts/$postId/comments', data: payload);
  }

  // Comments: like
  Future<void> likeComment(String postId, String commentId) async {
    await _dio.post('/api/posts/$postId/comments/$commentId/like');
  }

  // Comments: unlike
  Future<void> unlikeComment(String postId, String commentId) async {
    await _dio.delete('/api/posts/$postId/comments/$commentId/like');
  }

  // Comments: delete
  Future<void> deleteComment(String postId, String commentId) async {
    await _dio.delete('/api/posts/$postId/comments/$commentId');
  }

  Post _toPost(Map<String, dynamic> p) {
    // Prefer a nested original post for content/media/author when present
    final original = Map<String, dynamic>.from(
      p['original_post'] ??
          p['originalPost'] ??
          p['original'] ??
          p['repost_of_post'] ??
          {},
    );

    // Build synthetic original from top-level original_* fields if needed
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

    // Use original as the content source if present; otherwise synthetic; otherwise top-level
    final contentSource =
        original.isNotEmpty ? original : (syntheticOriginal.isNotEmpty ? syntheticOriginal : p);

    // Author resolution for original content
    Map<String, dynamic> authorFrom(Map<String, dynamic> src) {
      final a = Map<String, dynamic>.from(src['author'] ?? {});
      if (a.isNotEmpty) return a;
      // Fallbacks some APIs might use
      final oa = Map<String, dynamic>.from(src['original_author'] ?? {});
      if (oa.isNotEmpty) return oa;
      return {};
    }

    final author = authorFrom(contentSource);

    // Counts: from content source counts, otherwise aggregate count fields or fallback to top-level counts
    Map<String, dynamic> countsMap = {};
    if (contentSource['counts'] is Map) {
      countsMap = Map<String, dynamic>.from(contentSource['counts']);
    } else if (p['counts'] is Map) {
      countsMap = Map<String, dynamic>.from(p['counts']);
    } else {
      // per-column counts fallback
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

    // Media parsing from chosen content source, supporting media[] or direct fields
    MediaType mediaType = MediaType.none;
    String? videoUrl;
    List<String> imageUrls = [];

    List<dynamic> mediaList = [];
    if (contentSource['media'] is List) {
      mediaList = List<dynamic>.from(contentSource['media']);
    } else if (p['media'] is List) {
      // some backends place media on the top-level even for reposts
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

    // Repost attribution (who reposted)
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

    // Best-effort original post id for client hydration
    final originalPostId = (p['repost_of'] ??
            p['repostOf'] ??
            original['id'] ??
            original['post_id'] ??
            original['postId'])
        ?.toString();

    // Decide header text trigger: ONLY when this row's reposter is the current user
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

    // Author fields with snake_case fallback
    final authorName =
        (author['name'] ?? author['username'] ?? 'User').toString();
    final authorAvatar =
        (author['avatarUrl'] ?? author['avatar_url'] ?? '').toString();

    // Text with multiple fallbacks (contentSource first)
    final text = (contentSource['content'] ??
            contentSource['text'] ??
            p['original_content'] ??
            p['text'] ??
            p['content'] ??
            '')
        .toString();

    return Post(
      id: (p['id'] ?? '').toString(),
      // Original author on the main card when reposting
      userName: authorName,
      userAvatarUrl: authorAvatar,
      // Prefer top-level created_at (repost time), fallback to content source
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