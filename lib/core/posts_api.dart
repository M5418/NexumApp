import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/post.dart';

class PostsApi {
  final Dio _dio = ApiClient().dio;

  Future<List<Post>> listFeed({int limit = 20, int offset = 0}) async {
    final res = await _dio.get(
      '/api/posts',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final body = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final posts = (data['posts'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_toPost)
        .toList();
    return posts;
  }

  Future<Map<String, dynamic>> create({
    required String content,
    List<Map<String, dynamic>>? media,
    String? repostOf,
  }) async {
    final payload = <String, dynamic>{'content': content};
    if (media != null && media.isNotEmpty) payload['media'] = media;
    if (repostOf != null) payload['repost_of'] = repostOf;

    final res = await _dio.post('/api/posts', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Post _toPost(Map<String, dynamic> p) {
    final author = Map<String, dynamic>.from(p['author'] ?? {});
    final media = (p['media'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final counts = Map<String, dynamic>.from(p['counts'] ?? {});
    final me = Map<String, dynamic>.from(p['me'] ?? {});

    // Determine media type
    final images = media.where((m) => m['type'] == 'image').toList();
    final videos = media.where((m) => m['type'] == 'video').toList();

    MediaType mediaType = MediaType.none;
    String? videoUrl;
    List<String> imageUrls = [];
    if (videos.isNotEmpty) {
      mediaType = MediaType.video;
      videoUrl = (videos.first['url'] ?? '') as String?;
    } else if (images.length > 1) {
      mediaType = MediaType.images;
      imageUrls = images
          .map((m) => (m['url'] ?? '') as String)
          .where((u) => u.isNotEmpty)
          .toList();
    } else if (images.length == 1) {
      mediaType = MediaType.image;
      imageUrls = [
        (images.first['url'] ?? '') as String,
      ].where((u) => u.isNotEmpty).toList();
    }

    return Post(
      id: (p['id'] ?? '').toString(),
      userName: (author['name'] ?? 'User').toString(),
      userAvatarUrl:
          (author['avatarUrl'] ??
                  'https://ui-avatars.com/api/?background=BFAE01&color=000&name=' +
                      Uri.encodeComponent((author['name'] ?? 'U').toString()))
              .toString(),
      createdAt:
          DateTime.tryParse(p['created_at']?.toString() ?? '') ??
          DateTime.now(),
      text: (p['content'] ?? '').toString(),
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: (counts['likes'] ?? 0) as int,
        comments: (counts['comments'] ?? 0) as int,
        shares: (counts['shares'] ?? 0) as int,
        reposts: (counts['reposts'] ?? 0) as int,
        bookmarks: (counts['bookmarks'] ?? 0) as int,
      ),
      userReaction: null,
      isBookmarked: (me['bookmarked'] ?? false) as bool,
      isRepost: p['repost_of'] != null,
      repostedBy: null,
    );
  }
}
