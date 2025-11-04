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
        userName: (u?.displayName ?? u?.username ?? u?.email ?? 'User') ?? 'User',
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
      userName: (author?.displayName ?? author?.username ?? author?.email ?? 'User') ?? 'User',
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
