import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'api_client.dart';
import '../models/post.dart';

class SearchAccount {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  SearchAccount({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory SearchAccount.fromJson(Map<String, dynamic> j) {
    return SearchAccount(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? 'User').toString(),
      username: (j['username'] ?? '@user').toString(),
      avatarUrl: j['avatarUrl']?.toString(),
    );
  }
}

class SearchCommunity {
  final String id;
  final String name;
  final String bio;
  final String avatarUrl;
  final String? coverUrl;

  SearchCommunity({
    required this.id,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    this.coverUrl,
  });

  factory SearchCommunity.fromJson(Map<String, dynamic> j) {
    return SearchCommunity(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      bio: (j['bio'] ?? '').toString(),
      avatarUrl: (j['avatarUrl'] ?? '').toString(),
      coverUrl: j['coverUrl']?.toString(),
    );
  }
}

class SearchResult {
  final List<SearchAccount> accounts;
  final List<Post> posts;
  final List<SearchCommunity> communities;

  SearchResult({
    required this.accounts,
    required this.posts,
    required this.communities,
  });
}

class SearchApi {
  final Dio _dio = ApiClient().dio;

  Future<SearchResult> search({
    required String query,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResult(accounts: const [], posts: const [], communities: const []);
    }
    debugPrint('🔎 SearchApi.search: q="$query" limit=$limit');
    final res = await _dio.get(
      '/api/search',
      queryParameters: {
        'q': query,
        'limit': limit,
        'types': 'accounts,posts,communities',
      },
    );
    final body = Map<String, dynamic>.from(res.data ?? {});
    final data = Map<String, dynamic>.from(body['data'] ?? {});

    final accounts = (data['users'] as List<dynamic>? ?? [])
        .map((e) => SearchAccount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final posts = (data['posts'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_toPostFromSearch)
        .toList();

    final communities = (data['communities'] as List<dynamic>? ?? [])
        .map((e) => SearchCommunity.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SearchResult(accounts: accounts, posts: posts, communities: communities);
  }

  // Minimal conversion to our Post model for Search results
  Post _toPostFromSearch(Map<String, dynamic> p) {
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

    // Author block
    final author = Map<String, dynamic>.from(p['author'] ?? {});
    final authorName = (author['name'] ?? author['username'] ?? 'User').toString();
    final authorAvatar = (author['avatarUrl'] ?? author['avatar_url'] ?? '').toString();

    // Media fields
    String? videoUrl;
    List<String> imageUrls = [];
    if (p['video_url'] != null && p['video_url'].toString().isNotEmpty) {
      videoUrl = p['video_url'].toString();
    } else if (p['image_urls'] is List) {
      imageUrls =
          (p['image_urls'] as List).map((u) => u.toString()).where((u) => u.isNotEmpty).toList();
    } else if (p['image_url'] != null && p['image_url'].toString().isNotEmpty) {
      imageUrls = [p['image_url'].toString()];
    }

    // Decide media type
    MediaType mt = MediaType.none;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      mt = MediaType.video;
    } else if (imageUrls.length > 1) {
      mt = MediaType.images;
    } else if (imageUrls.length == 1) {
      mt = MediaType.image;
    }

    // Counts
    final countsMap = Map<String, dynamic>.from(p['counts'] ?? {});
    final counts = PostCounts(
      likes: toInt(countsMap['likes']),
      comments: toInt(countsMap['comments']),
      shares: toInt(countsMap['shares']),
      reposts: toInt(countsMap['reposts']),
      bookmarks: toInt(countsMap['bookmarks']),
    );

    return Post(
      id: (p['id'] ?? '').toString(),
      userName: authorName,
      userAvatarUrl: authorAvatar,
      createdAt: parseCreatedAt(p['created_at'] ?? p['updated_at']),
      text: (p['content'] ?? '').toString(),
      mediaType: mt,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: counts,
      userReaction: null,
      isBookmarked: false,
      isRepost: (p['repost_of'] != null),
      repostedBy: null,
      originalPostId: p['repost_of']?.toString(),
    );
  }
}