import '../models/post.dart';
import '../models/comment.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../repositories/firebase/firebase_post_repository.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/firebase/firebase_comment_repository.dart';
import '../repositories/models/post_model.dart';

class PostsApi {
  final FirebasePostRepository _posts = FirebasePostRepository();
  final FirebaseUserRepository _users = FirebaseUserRepository();
  final FirebaseCommentRepository _comments = FirebaseCommentRepository();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  Future<List<Post>> listFeed({int limit = 20, int offset = 0}) async {
    final models = await _posts.getFeed(limit: limit);
    return _mapModelsToPosts(models);
  }

  // User posts
  Future<List<Post>> listUserPosts({required String uid, int limit = 20, int offset = 0}) async {
    final models = await _posts.getUserPosts(uid: uid, limit: limit);
    return _mapModelsToPosts(models);
  }

  // Community posts
  Future<List<Post>> listCommunityPosts({required String communityId, int limit = 50, int offset = 0}) async {
    final models = await _posts.getCommunityPosts(communityId: communityId, limit: limit);
    return _mapModelsToPosts(models);
  }

  // Activity: posts liked by user, bookmarked by user, or reposts authored by user
  Future<List<Post>> listActivityForUser({required String uid, int limit = 100}) async {
    final liked = await _posts.getPostsLikedByUser(uid: uid, limit: limit);
    final bookmarked = await _posts.getPostsBookmarkedByUser(uid: uid, limit: limit);
    final reposts = await _posts.getUserReposts(uid: uid, limit: limit);

    // Merge unique by post id
    final byId = <String, PostModel>{};
    for (final m in [...liked, ...bookmarked, ...reposts]) {
      // Exclude my own original posts (allow repost rows)
      final isMyOriginal = m.authorId == uid && (m.repostOf == null || m.repostOf!.isEmpty);
      if (isMyOriginal) continue;
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _mapModelsToPosts(merged);
  }

  Future<Map<String, dynamic>> create({
    required String content,
    List<Map<String, dynamic>>? media,
    String? repostOf,
  }) async {
    final urls = <String>[];
    if (media != null) {
      for (final m in media) {
        final u = (m['url'] ?? '').toString();
        if (u.isNotEmpty) urls.add(u);
      }
    }
    await _posts.createPost(text: content, mediaUrls: urls, repostOf: repostOf);
    return {'ok': true};
  }

  Future<void> like(String postId) async => _posts.likePost(postId);

  Future<void> unlike(String postId) async => _posts.unlikePost(postId);

  Future<void> bookmark(String postId) async => _posts.bookmarkPost(postId);

  Future<void> unbookmark(String postId) async => _posts.unbookmarkPost(postId);

  // Repost: create (fallback to create(repost_of) if /repost route is missing)
  Future<void> repost(String postId) async => _posts.repostPost(postId);

  // Repost: remove (no safe fallback without a specific API)
  Future<void> unrepost(String postId) async => _posts.unrepostPost(postId);

  // Single post fetch (used for client-side hydration of reposts)
  Future<Post?> getPost(String id) async {
    final m = await _posts.getPost(id);
    if (m == null) return null;
    final list = await _mapModelsToPosts([m]);
    return list.isNotEmpty ? list.first : null;
  }

  // Comments: list
  Future<List<Comment>> listComments(String postId) async {
    final models = await _comments.getComments(postId: postId, limit: 200);
    final results = <Comment>[];
    for (final m in models) {
      final u = await _users.getUserProfile(m.authorId);
      results.add(Comment(
        id: m.id,
        userId: m.authorId,
        userName: u?.displayName ?? u?.username ?? u?.email ?? 'User',
        userAvatarUrl: u?.avatarUrl ?? '',
        text: m.text,
        createdAt: m.createdAt,
        likesCount: m.likesCount,
        isLikedByUser: false,
        replies: const [],
        parentCommentId: m.parentCommentId,
        isPinned: false,
        isCreator: false,
      ));
    }
    return results;
  }

  // Comments: create
  Future<void> addComment(
    String postId, {
    required String content,
    String? parentCommentId,
  }) async {
    await _comments.createComment(postId: postId, text: content, parentCommentId: parentCommentId);
  }

  // Comments: like
  Future<void> likeComment(String postId, String commentId) async {
    await _comments.likeComment(commentId);
  }

  // Comments: unlike
  Future<void> unlikeComment(String postId, String commentId) async {
    await _comments.unlikeComment(commentId);
  }

  // Comments: delete
  Future<void> deleteComment(String postId, String commentId) async {
    await _comments.deleteComment(commentId);
  }

  Future<Post> _toPostFromModel(PostModel m) async {
    final author = await _users.getUserProfile(m.authorId);
    final uid = _auth.currentUser?.uid;
    bool isBookmarked = false;
    bool isLiked = false;
    if (uid != null) {
      isBookmarked = await _posts.hasUserBookmarkedPost(postId: m.id, uid: uid);
      isLiked = await _posts.hasUserLikedPost(postId: m.id, uid: uid);
    }
    return Post(
      id: m.id,
      userName: author?.displayName ?? author?.username ?? author?.email ?? 'User',
      userAvatarUrl: author?.avatarUrl ?? '',
      createdAt: m.createdAt,
      text: m.text,
      mediaType: (m.mediaUrls.isEmpty)
          ? MediaType.none
          : (m.mediaUrls.length == 1 ? MediaType.image : MediaType.images),
      imageUrls: m.mediaUrls,
      videoUrl: null,
      counts: PostCounts(
        likes: m.summary.likes,
        comments: m.summary.comments,
        shares: m.summary.shares,
        reposts: m.summary.reposts,
        bookmarks: m.summary.bookmarks,
      ),
      userReaction: isLiked ? ReactionType.like : null,
      isBookmarked: isBookmarked,
      isRepost: (m.repostOf != null && m.repostOf!.isNotEmpty),
      repostedBy: null,
      originalPostId: m.repostOf,
    );
  }

  Future<List<Post>> _mapModelsToPosts(List<PostModel> models) async {
    final out = <Post>[];
    for (final m in models) {
      out.add(await _toPostFromModel(m));
    }
    return out;
  }
}
