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
      final parentId = parentIdRaw == null ? null : parentIdRaw.toString();
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
    final author = Map<String, dynamic>.from(p['author'] ?? {});
    final counts = Map<String, dynamic>.from(p['counts'] ?? {});
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

    if (p['video_url'] != null && p['video_url'].toString().isNotEmpty) {
      mediaType = MediaType.video;
      videoUrl = p['video_url'].toString();
    } else if (p['image_urls'] != null) {
      final urls = (p['image_urls'] as List<dynamic>? ?? [])
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
    } else if (p['image_url'] != null && p['image_url'].toString().isNotEmpty) {
      mediaType = MediaType.image;
      imageUrls = [p['image_url'].toString()];
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return Post(
      id: (p['id'] ?? '').toString(),
      userName: (author['name'] ?? 'User').toString(),
      userAvatarUrl: (author['avatarUrl'] ?? '').toString(),
      createdAt: parseCreatedAt(p['created_at']),
      text: (p['content'] ?? '').toString(),
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: toInt(counts['likes']),
        comments: toInt(counts['comments']),
        shares: toInt(counts['shares']),
        reposts: toInt(counts['reposts']),
        bookmarks: toInt(counts['bookmarks']),
      ),
      userReaction: (me['liked'] == true) ? ReactionType.like : null,
      isBookmarked: (me['bookmarked'] ?? false) as bool,
      isRepost: p['repost_of'] != null,
      repostedBy: null,
    );
  }
}