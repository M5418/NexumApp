import '../../core/cache_manager.dart';
import '../interfaces/post_repository.dart';
import '../models/post_model.dart';

/// Cached wrapper for PostRepository
class CachedPostRepository implements PostRepository {
  final PostRepository _source;
  final CacheManager _cache = CacheManager();

  CachedPostRepository(this._source);

  @override
  Future<String> createPost({
    required String text,
    List<String>? mediaUrls,
    List<String>? thumbUrls,
    String? repostOf,
    String? communityId,
    List<Map<String, String>>? taggedUsers,
  }) async {
    final postId = await _source.createPost(
      text: text,
      mediaUrls: mediaUrls,
      thumbUrls: thumbUrls,
      repostOf: repostOf,
      communityId: communityId,
      taggedUsers: taggedUsers,
    );
    
    // Invalidate feed caches
    await _cache.removePattern('feed_*');
    await _cache.removePattern('user_posts_*');
    if (communityId != null) {
      await _cache.removePattern('community_posts_$communityId*');
    }
    
    return postId;
  }

  @override
  Future<PostModel?> getPost(String postId) async {
    // Check memory cache
    final cached = _cache.getMemoryOnly<PostModel>('post_$postId');
    if (cached != null) return cached;

    // Fetch from source
    final post = await _source.getPost(postId);
    if (post != null) {
      _cache.setMemoryOnly('post_$postId', post, ttl: Duration(minutes: 10));
    }
    
    return post;
  }

  @override
  Future<void> updatePost({
    required String postId,
    required String text,
    List<String>? mediaUrls,
    List<String>? thumbUrls,
  }) async {
    await _source.updatePost(postId: postId, text: text, mediaUrls: mediaUrls, thumbUrls: thumbUrls);
    await _cache.remove('post_$postId');
    await _cache.removePattern('feed_*');
  }

  @override
  Future<void> deletePost(String postId) async {
    await _source.deletePost(postId);
    await _cache.remove('post_$postId');
    await _cache.removePattern('feed_*');
  }

  @override
  Future<List<PostModel>> getFeed({int limit = 20, PostModel? lastPost}) async {
    final cacheKey = 'feed_${limit}_${lastPost?.id ?? 'start'}';
    
    // Check cache (2 minute TTL for feed)
    final cached = _cache.getMemoryOnly<List<PostModel>>(cacheKey);
    if (cached != null && cached.isNotEmpty) return cached;

    // Fetch from source
    final posts = await _source.getFeed(limit: limit, lastPost: lastPost);
    
    if (posts.isNotEmpty) {
      _cache.setMemoryOnly(cacheKey, posts, ttl: Duration(minutes: 2));
      
      // Cache individual posts
      for (final post in posts) {
        _cache.setMemoryOnly('post_${post.id}', post, ttl: Duration(minutes: 10));
      }
    }
    
    return posts;
  }

  @override
  Future<List<PostModel>> getUserPosts({
    required String uid,
    int limit = 20,
    PostModel? lastPost,
  }) async {
    final cacheKey = 'user_posts_${uid}_${limit}_${lastPost?.id ?? 'start'}';
    
    final cached = _cache.getMemoryOnly<List<PostModel>>(cacheKey);
    if (cached != null) return cached;

    final posts = await _source.getUserPosts(uid: uid, limit: limit, lastPost: lastPost);
    
    if (posts.isNotEmpty) {
      _cache.setMemoryOnly(cacheKey, posts, ttl: Duration(minutes: 5));
    }
    
    return posts;
  }

  @override
  Future<List<PostModel>> getCommunityPosts({
    required String communityId,
    int limit = 20,
    PostModel? lastPost,
  }) async {
    final cacheKey = 'community_posts_${communityId}_${limit}_${lastPost?.id ?? 'start'}';
    
    final cached = _cache.getMemoryOnly<List<PostModel>>(cacheKey);
    if (cached != null) return cached;

    final posts = await _source.getCommunityPosts(
      communityId: communityId,
      limit: limit,
      lastPost: lastPost,
    );
    
    if (posts.isNotEmpty) {
      _cache.setMemoryOnly(cacheKey, posts, ttl: Duration(minutes: 3));
    }
    
    return posts;
  }

  @override
  Future<void> likePost(String postId) async {
    await _source.likePost(postId);
    await _cache.remove('post_$postId');
  }

  @override
  Future<void> unlikePost(String postId) async {
    await _source.unlikePost(postId);
    await _cache.remove('post_$postId');
  }

  @override
  Future<void> bookmarkPost(String postId) async {
    await _source.bookmarkPost(postId);
    await _cache.remove('post_$postId');
  }

  @override
  Future<void> unbookmarkPost(String postId) async {
    await _source.unbookmarkPost(postId);
    await _cache.remove('post_$postId');
  }

  @override
  Future<void> repostPost(String postId) async {
    await _source.repostPost(postId);
    await _cache.removePattern('feed_*');
  }

  @override
  Future<void> unrepostPost(String postId) async {
    await _source.unrepostPost(postId);
    await _cache.removePattern('feed_*');
  }

  @override
  Future<List<String>> getPostLikes({
    required String postId,
    int limit = 20,
    String? lastUserId,
  }) async {
    return await _source.getPostLikes(
      postId: postId,
      limit: limit,
      lastUserId: lastUserId,
    );
  }

  @override
  Future<bool> hasUserLikedPost({
    required String postId,
    required String uid,
  }) async {
    return await _source.hasUserLikedPost(postId: postId, uid: uid);
  }

  @override
  Future<bool> hasUserBookmarkedPost({
    required String postId,
    required String uid,
  }) async {
    return await _source.hasUserBookmarkedPost(postId: postId, uid: uid);
  }

  @override
  Stream<PostModel?> postStream(String postId) {
    return _source.postStream(postId);
  }

  @override
  Stream<List<PostModel>> feedStream({int limit = 20}) {
    return _source.feedStream(limit: limit);
  }

  @override
  Stream<List<PostModel>> userPostsStream({
    required String uid,
    int limit = 20,
  }) {
    return _source.userPostsStream(uid: uid, limit: limit);
  }

  @override
  Future<List<PostModel>> getPostsLikedByUser({
    required String uid,
    int limit = 50,
  }) async {
    return await _source.getPostsLikedByUser(uid: uid, limit: limit);
  }

  @override
  Future<List<PostModel>> getPostsBookmarkedByUser({
    required String uid,
    int limit = 50,
  }) async {
    return await _source.getPostsBookmarkedByUser(uid: uid, limit: limit);
  }

  @override
  Future<List<PostModel>> getUserReposts({
    required String uid,
    int limit = 50,
  }) async {
    return await _source.getUserReposts(uid: uid, limit: limit);
  }
}
