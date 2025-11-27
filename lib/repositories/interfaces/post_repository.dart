import 'dart:async';
import '../models/post_model.dart';

abstract class PostRepository {
  // Create post
  Future<String> createPost({
    required String text,
    List<String>? mediaUrls,
    String? repostOf,
    String? communityId,
  });
  
  // Get single post
  Future<PostModel?> getPost(String postId);
  
  // Update post
  Future<void> updatePost({
    required String postId,
    required String text,
    List<String>? mediaUrls,
  });
  
  // Delete post
  Future<void> deletePost(String postId);
  
  // Get feed (paginated)
  Future<List<PostModel>> getFeed({
    int limit = 20,
    PostModel? lastPost,
  });
  
  // Get user posts (paginated)
  Future<List<PostModel>> getUserPosts({
    required String uid,
    int limit = 20,
    PostModel? lastPost,
  });
  
  // Get community posts (paginated)
  Future<List<PostModel>> getCommunityPosts({
    required String communityId,
    int limit = 20,
    PostModel? lastPost,
  });
  
  // Like/unlike post
  Future<void> likePost(String postId);
  Future<void> unlikePost(String postId);
  
  // Bookmark/unbookmark post
  Future<void> bookmarkPost(String postId);
  Future<void> unbookmarkPost(String postId);
  
  // Repost/unrepost
  Future<void> repostPost(String postId);
  Future<void> unrepostPost(String postId);
  
  // Get likes (paginated)
  Future<List<String>> getPostLikes({
    required String postId,
    int limit = 20,
    String? lastUserId,
  });
  
  // Check if user liked post
  Future<bool> hasUserLikedPost({
    required String postId,
    required String uid,
  });
  
  // Check if user bookmarked post
  Future<bool> hasUserBookmarkedPost({
    required String postId,
    required String uid,
  });
  
  // Real-time post stream
  Stream<PostModel?> postStream(String postId);
  
  // Real-time feed stream
  Stream<List<PostModel>> feedStream({int limit = 20});
  
  // Real-time user posts stream
  Stream<List<PostModel>> userPostsStream({
    required String uid,
    int limit = 20,
  });

  // Activity helpers
  Future<List<PostModel>> getPostsLikedByUser({
    required String uid,
    int limit = 50,
  });

  Future<List<PostModel>> getPostsBookmarkedByUser({
    required String uid,
    int limit = 50,
  });

  Future<List<PostModel>> getUserReposts({
    required String uid,
    int limit = 50,
  });
}
