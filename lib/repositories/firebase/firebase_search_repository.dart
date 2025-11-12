import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/search_repository.dart';
import '../../models/post.dart';
import '../models/post_model.dart';
import 'firebase_post_repository.dart';
import 'firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirebaseSearchRepository implements SearchRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebasePostRepository _postRepo = FirebasePostRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  @override
  Future<SearchResult> search({
    required String query,
    int limit = 10,
    SearchType? type,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResult(users: [], posts: [], communities: []);
    }

    // Search all types or specific type
    final searchUsers = type == null || type == SearchType.users || type == SearchType.all;
    final searchCommunities = type == null || type == SearchType.communities || type == SearchType.all;
    final searchPosts = type == null || type == SearchType.posts || type == SearchType.all;

    final results = await Future.wait([
      if (searchUsers) this.searchUsers(query, limit: limit),
      if (searchCommunities) this.searchCommunities(query, limit: limit),
      if (searchPosts) this.searchPosts(query, limit: limit),
    ]);

    int idx = 0;
    final users = searchUsers ? results[idx++] as List<SearchUser> : <SearchUser>[];
    final communities = searchCommunities ? results[idx++] as List<SearchCommunity> : <SearchCommunity>[];
    final posts = searchPosts ? results[idx++] as List<Post> : <Post>[];

    return SearchResult(
      users: users,
      posts: posts,
      communities: communities,
    );
  }

  @override
  Future<List<SearchUser>> searchUsers(String query, {int limit = 10}) async {
    final queryLower = query.toLowerCase();
    
    // Search by username prefix
    final usernameQuery = await _db
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: queryLower)
        .where('usernameLower', isLessThan: '$queryLower\uf8ff')
        .limit(limit)
        .get();

    // Search by display name prefix (if different from username search)
    final displayNameQuery = await _db
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: queryLower)
        .where('displayNameLower', isLessThan: '$queryLower\uf8ff')
        .limit(limit)
        .get();

    // Merge results and deduplicate
    final userMap = <String, SearchUser>{};
    
    for (final doc in [...usernameQuery.docs, ...displayNameQuery.docs]) {
      final data = doc.data();
      final id = doc.id;
      if (!userMap.containsKey(id)) {
        userMap[id] = SearchUser(
          id: id,
          name: data['displayName'] ?? data['firstName'] ?? 'User',
          username: '@${data['username'] ?? 'user'}',
          avatarUrl: data['avatarUrl'],
        );
      }
    }

    return userMap.values.take(limit).toList();
  }

  @override
  Future<List<SearchCommunity>> searchCommunities(String query, {int limit = 10}) async {
    final queryLower = query.toLowerCase();
    
    final snapshot = await _db
        .collection('communities')
        .where('nameLower', isGreaterThanOrEqualTo: queryLower)
        .where('nameLower', isLessThan: '$queryLower\uf8ff')
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return SearchCommunity(
        id: doc.id,
        name: data['name'] ?? '',
        bio: data['bio'] ?? '',
        avatarUrl: data['avatarUrl'] ?? '',
        coverUrl: data['coverUrl'],
      );
    }).toList();
  }

  @override
  Future<List<Post>> searchPosts(String query, {int limit = 10}) async {
    // For posts, we'll search by hashtags initially
    // Full-text search would require Algolia or similar
    final queryLower = query.toLowerCase();
    final isHashtagSearch = query.startsWith('#');
    
    if (isHashtagSearch) {
      // Search posts by hashtag
      final tag = queryLower.substring(1); // Remove #
      final snapshot = await _db
          .collection('posts')
          .where('hashtags', arrayContains: tag)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      // Convert to Post models
      final posts = <Post>[];
      for (final doc in snapshot.docs) {
        final postModel = await _postRepo.getPost(doc.id);
        if (postModel != null) {
          final post = await _toPost(postModel);
          posts.add(post);
        }
      }
      return posts;
    }

    // For non-hashtag searches, search in content (limited)
    // This is a basic implementation - for production, use Algolia
    final snapshot = await _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit * 3) // Get more to filter locally
        .get();
    
    final posts = <Post>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final content = (data['text'] ?? '').toString().toLowerCase();
      if (content.contains(queryLower)) {
        final postModel = await _postRepo.getPost(doc.id);
        if (postModel != null) {
          final post = await _toPost(postModel);
          posts.add(post);
          if (posts.length >= limit) break;
        }
      }
    }
    
    return posts;
  }

  Future<Post> _toPost(PostModel model) async {
    final author = await _userRepo.getUserProfile(model.authorId);
    final uid = _auth.currentUser?.uid;
    bool isBookmarked = false;
    bool isLiked = false;
    
    if (uid != null) {
      isBookmarked = await _postRepo.hasUserBookmarkedPost(postId: model.id, uid: uid);
      isLiked = await _postRepo.hasUserLikedPost(postId: model.id, uid: uid);
    }
    
    return Post(
      id: model.id,
      authorId: model.authorId,
      userName: author?.displayName ?? author?.username ?? 'User',
      userAvatarUrl: author?.avatarUrl ?? '',
      createdAt: model.createdAt,
      text: model.text,
      mediaType: _getMediaType(model.mediaUrls),
      imageUrls: model.mediaUrls,
      videoUrl: null, // Handle video URLs if needed
      counts: PostCounts(
        likes: model.summary.likes,
        comments: model.summary.comments,
        shares: model.summary.shares,
        reposts: model.summary.reposts,
        bookmarks: model.summary.bookmarks,
      ),
      userReaction: isLiked ? ReactionType.like : null,
      isBookmarked: isBookmarked,
      isRepost: model.repostOf != null && model.repostOf!.isNotEmpty,
      repostedBy: null,
      originalPostId: model.repostOf,
    );
  }

  MediaType _getMediaType(List<String> urls) {
    if (urls.isEmpty) return MediaType.none;
    if (urls.length == 1) return MediaType.image;
    return MediaType.images;
  }
}
