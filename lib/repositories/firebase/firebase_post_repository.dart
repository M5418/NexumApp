import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/post_repository.dart';
import '../models/post_model.dart';
import 'firebase_user_repository.dart';

class FirebasePostRepository implements PostRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _communityPosts => _db.collection('community_posts');

  PostModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PostModel.fromFirestore(doc);
  }

  /// Send notifications to tagged users (non-blocking, fire-and-forget)
  void _sendTagNotifications({
    required String postId,
    required List<Map<String, String>> taggedUsers,
    required String authorId,
    required String authorName,
  }) async {
    try {
      final notifications = _db.collection('notifications');
      final batch = _db.batch();
      
      for (final user in taggedUsers) {
        final userId = user['id'];
        if (userId == null || userId.isEmpty || userId == authorId) continue;
        
        final notifRef = notifications.doc();
        batch.set(notifRef, {
          'userId': userId,
          'type': 'tag',
          'title': 'You were tagged',
          'body': '$authorName tagged you in a post',
          'data': {
            'postId': postId,
            'authorId': authorId,
            'authorName': authorName,
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      debugPrint('✅ Tag notifications sent to ${taggedUsers.length} users');
    } catch (e) {
      debugPrint('⚠️ Failed to send tag notifications: $e');
    }
  }

  @override
  Future<String> createPost({required String text, List<String>? mediaUrls, List<String>? thumbUrls, String? repostOf, String? communityId, List<Map<String, String>>? taggedUsers}) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        debugPrint('❌ User not authenticated');
        throw Exception('not_authenticated');
      }
      
      debugPrint('📝 Creating post - User: ${u.uid}, CommunityId: $communityId');
      
      // Fetch author profile for denormalization (fast feed rendering)
      String? authorName;
      String? authorAvatarUrl;
      try {
        final userRepo = FirebaseUserRepository();
        final profile = await userRepo.getUserProfile(u.uid);
        if (profile != null) {
          final fn = profile.firstName?.trim() ?? '';
          final ln = profile.lastName?.trim() ?? '';
          authorName = (fn.isNotEmpty || ln.isNotEmpty)
              ? '$fn $ln'.trim()
              : (profile.displayName ?? profile.username ?? 'User');
          authorAvatarUrl = profile.avatarUrl;
        }
      } catch (_) {
        // Continue without denormalized data - feed will fallback
      }
      
      // Build media thumbs - use provided thumbUrls if available, otherwise fallback to full URLs
      final urls = mediaUrls ?? [];
      final thumbs = <MediaThumb>[];
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final thumbUrl = (thumbUrls != null && i < thumbUrls.length) ? thumbUrls[i] : url;
        // Improved video detection for Firebase Storage URLs with query params
        final l = url.toLowerCase();
        final isVideo = l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') ||
            l.contains('.avi') || l.contains('.mkv') || l.contains('.m4v') ||
            l.contains('.wmv') || l.contains('.flv') || l.contains('.3gp') ||
            l.contains('.3g2') || l.contains('.ogv') || l.contains('.ts') ||
            l.contains('/videos/') || l.contains('video_') || l.contains('video%2f');
        thumbs.add(MediaThumb(
          type: isVideo ? 'video' : 'image',
          thumbUrl: thumbUrl,
        ));
      }
      
      // Convert tagged users to TaggedUserData
      final taggedUsersList = (taggedUsers ?? []).map((t) => TaggedUserData(
        id: t['id'] ?? '',
        name: t['name'] ?? '',
        avatarUrl: t['avatarUrl'],
      )).toList();
      
      final data = PostModel(
        id: '',
        authorId: u.uid,
        text: text,
        mediaUrls: mediaUrls ?? const [],
        summary: PostSummary(),
        repostOf: repostOf,
        communityId: communityId,
        createdAt: DateTime.now(),
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        mediaThumbs: thumbs,
        taggedUsers: taggedUsersList,
      ).toMap();
      
      debugPrint('📝 Post data prepared: ${data.keys.toList()}');
      
      // Route to correct collection: community posts go to community_posts, regular posts go to posts
      final collection = (communityId != null && communityId.isNotEmpty) ? _communityPosts : _posts;
      final collectionName = communityId != null && communityId.isNotEmpty ? 'community_posts' : 'posts';
      debugPrint('📝 Writing to Firebase collection: $collectionName');
      
      final ref = await collection.add(data);
      debugPrint('✅ Post created successfully with ID: ${ref.id} in $collectionName');
      
      // Send notifications to tagged users (non-blocking)
      if (taggedUsers != null && taggedUsers.isNotEmpty) {
        _sendTagNotifications(
          postId: ref.id,
          taggedUsers: taggedUsers,
          authorId: u.uid,
          authorName: authorName ?? 'Someone',
        );
      }
      
      return ref.id;
    } catch (e, stackTrace) {
      debugPrint('❌ FIREBASE ERROR creating post: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<PostModel?> getPost(String postId) async {
    // Check regular posts first
    var doc = await _posts.doc(postId).get();
    if (doc.exists) return _fromDoc(doc);
    
    // Check community posts
    doc = await _communityPosts.doc(postId).get();
    if (doc.exists) return _fromDoc(doc);
    
    return null;
  }

  @override
  Future<void> updatePost({required String postId, required String text, List<String>? mediaUrls, List<String>? thumbUrls}) async {
    // Build mediaThumbs if thumbUrls provided
    List<Map<String, dynamic>>? mediaThumbsData;
    if (mediaUrls != null && thumbUrls != null) {
      mediaThumbsData = [];
      for (var i = 0; i < mediaUrls.length; i++) {
        final url = mediaUrls[i];
        final thumbUrl = i < thumbUrls.length ? thumbUrls[i] : url;
        // Improved video detection for Firebase Storage URLs with query params
        final l = url.toLowerCase();
        final isVideo = l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') ||
            l.contains('.avi') || l.contains('.mkv') || l.contains('.m4v') ||
            l.contains('.wmv') || l.contains('.flv') || l.contains('.3gp') ||
            l.contains('.3g2') || l.contains('.ogv') || l.contains('.ts') ||
            l.contains('/videos/') || l.contains('video_') || l.contains('video%2f');
        mediaThumbsData.add({
          'type': isVideo ? 'video' : 'image',
          'thumbUrl': thumbUrl,
        });
      }
    }
    
    // Try to update in regular posts
    final regularDoc = await _posts.doc(postId).get();
    if (regularDoc.exists) {
      await _posts.doc(postId).update({
        'text': text,
        if (mediaUrls != null) 'mediaUrls': mediaUrls,
        if (mediaThumbsData != null) 'mediaThumbs': mediaThumbsData,
        'updatedAt': Timestamp.now(),
      });
      return;
    }
    
    // Try to update in community posts
    final communityDoc = await _communityPosts.doc(postId).get();
    if (communityDoc.exists) {
      await _communityPosts.doc(postId).update({
        'text': text,
        if (mediaUrls != null) 'mediaUrls': mediaUrls,
        if (mediaThumbsData != null) 'mediaThumbs': mediaThumbsData,
        'updatedAt': Timestamp.now(),
      });
      return;
    }
    
    throw Exception('Post not found: $postId');
  }

  @override
  Future<void> deletePost(String postId) async {
    // Try to delete from regular posts
    final regularDoc = await _posts.doc(postId).get();
    if (regularDoc.exists) {
      await _posts.doc(postId).delete();
      return;
    }
    
    // Try to delete from community posts
    final communityDoc = await _communityPosts.doc(postId).get();
    if (communityDoc.exists) {
      await _communityPosts.doc(postId).delete();
      return;
    }
  }

  @override
  Future<List<PostModel>> getFeed({int limit = 20, PostModel? lastPost}) async {
    Query<Map<String, dynamic>> q = _posts.orderBy('createdAt', descending: true).limit(limit);
    if (lastPost?.snapshot != null) {
      q = q.startAfterDocument(lastPost!.snapshot!);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// FAST: Get feed from cache first (instant), returns cached data
  /// Call getFeed() after to refresh from server
  Future<List<PostModel>> getFeedFromCache({int limit = 20}) async {
    try {
      Query<Map<String, dynamic>> q = _posts.orderBy('createdAt', descending: true).limit(limit);
      final snap = await q.get(const GetOptions(source: Source.cache));
      return snap.docs.map(_fromDoc).toList();
    } catch (_) {
      return []; // Cache miss - return empty, caller will load from server
    }
  }

  @override
  Future<List<PostModel>> getUserPosts({required String uid, int limit = 20, PostModel? lastPost}) async {
    try {
      Query<Map<String, dynamic>> q = _posts.where('authorId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(limit);
      if (lastPost?.snapshot != null) {
        q = q.startAfterDocument(lastPost!.snapshot!);
      }
      final snap = await q.get();
      return snap.docs.map(_fromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// FAST: Get user posts from cache first (instant)
  Future<List<PostModel>> getUserPostsFromCache({required String uid, int limit = 20}) async {
    try {
      Query<Map<String, dynamic>> q = _posts
          .where('authorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      final snap = await q.get(const GetOptions(source: Source.cache));
      return snap.docs.map(_fromDoc).toList();
    } catch (_) {
      return []; // Cache miss
    }
  }

  @override
  Future<List<PostModel>> getCommunityPosts({required String communityId, int limit = 20, PostModel? lastPost}) async {
    Query<Map<String, dynamic>> q = _communityPosts
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (lastPost?.snapshot != null) {
      q = q.startAfterDocument(lastPost!.snapshot!);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// FAST: Get community posts from cache first (instant), returns cached data
  Future<List<PostModel>> getCommunityPostsFromCache({required String communityId, int limit = 20}) async {
    try {
      Query<Map<String, dynamic>> q = _communityPosts
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      final snap = await q.get(const GetOptions(source: Source.cache));
      return snap.docs.map(_fromDoc).toList();
    } catch (_) {
      return []; // Cache miss - return empty, caller will load from server
    }
  }

  // Unused method - kept for potential future use
  // ignore: unused_element
  Future<List<PostModel>> _getPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <PostModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final end = (i + 10 > ids.length) ? ids.length : (i + 10);
      final chunk = ids.sublist(i, end);
      final snap = await _posts.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_fromDoc));
    }
    // Sort by createdAt desc
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<List<PostModel>> getPostsLikedByUser({required String uid, int limit = 50}) async {
    try {
      // Query all likes, then filter by document ID (which is the user ID)
      final likes = await _db
          .collectionGroup('likes')
          .orderBy('createdAt', descending: true)
          .limit(limit * 5) // Get more to account for filtering
          .get();

      // Collect parent post IDs where the like document ID matches the user ID
      final ids = <String>{};
      for (final d in likes.docs) {
        if (d.id == uid) { // Document ID is the user ID
          final postRef = d.reference.parent.parent; // posts/<postId>
          if (postRef != null) ids.add(postRef.id);
          if (ids.length >= limit) break;
        }
      }
      if (ids.isEmpty) return [];
      return await _getPostsByIds(ids.toList());
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<List<PostModel>> getPostsBookmarkedByUser({required String uid, int limit = 50}) async {
    try {
      // Query all bookmarks, then filter by document ID (which is the user ID)
      final bookmarks = await _db
          .collectionGroup('bookmarks')
          .orderBy('createdAt', descending: true)
          .limit(limit * 5) // Get more to account for filtering
          .get();

      final ids = <String>{};
      for (final d in bookmarks.docs) {
        if (d.id == uid) { // Document ID is the user ID
          final postRef = d.reference.parent.parent; // posts/<postId>
          if (postRef != null) ids.add(postRef.id);
          if (ids.length >= limit) break;
        }
      }
      if (ids.isEmpty) return [];
      return await _getPostsByIds(ids.toList());
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<List<PostModel>> getUserReposts({required String uid, int limit = 50}) async {
    // Fetch recent posts by author and filter for reposts in memory to avoid inequality + orderBy constraint
    final snap = await _posts
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit * 3)
        .get();
    final all = snap.docs.map(_fromDoc).toList();
    final reposts = all.where((m) => (m.repostOf != null && m.repostOf!.isNotEmpty)).take(limit).toList();
    return reposts;
  }

  @override
  Future<void> likePost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    final likeRef = collection.doc(postId).collection('likes').doc(u.uid);
    final likeDoc = await likeRef.get();
    if (likeDoc.exists) return; // already liked; idempotent
    await likeRef.set({'createdAt': Timestamp.now()});
  }

  @override
  Future<void> unlikePost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    final likeRef = collection.doc(postId).collection('likes').doc(u.uid);
    final likeDoc = await likeRef.get();
    if (!likeDoc.exists) return; // nothing to unlike; idempotent
    await likeRef.delete();
  }

  @override
  Future<void> bookmarkPost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    final ref = collection.doc(postId).collection('bookmarks').doc(u.uid);
    final bmDoc = await ref.get();
    if (bmDoc.exists) return; // already bookmarked
    await ref.set({'createdAt': Timestamp.now()});
  }

  @override
  Future<void> unbookmarkPost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    final ref = collection.doc(postId).collection('bookmarks').doc(u.uid);
    final bmDoc = await ref.get();
    if (!bmDoc.exists) return; // nothing to unbookmark
    await ref.delete();
  }

  @override
  Future<void> repostPost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    await createPost(text: '', mediaUrls: const [], repostOf: postId);
  }

  @override
  Future<void> unrepostPost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    
    // Check both collections for the repost
    var q = await _posts.where('authorId', isEqualTo: u.uid).where('repostOf', isEqualTo: postId).limit(1).get();
    if (q.docs.isNotEmpty) {
      await _posts.doc(q.docs.first.id).delete();
      return;
    }
    
    q = await _communityPosts.where('authorId', isEqualTo: u.uid).where('repostOf', isEqualTo: postId).limit(1).get();
    if (q.docs.isNotEmpty) {
      await _communityPosts.doc(q.docs.first.id).delete();
    }
  }

  @override
  Future<List<String>> getPostLikes({required String postId, int limit = 20, String? lastUserId}) async {
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    Query<Map<String, dynamic>> q = collection.doc(postId).collection('likes').orderBy('createdAt', descending: true).limit(limit);
    if (lastUserId != null) {
      final lastDoc = await collection.doc(postId).collection('likes').doc(lastUserId).get();
      if (lastDoc.exists) {
        q = q.startAfterDocument(lastDoc);
      }
    }
    final snap = await q.get();
    return snap.docs.map((d) => d.id).toList();
  }

  @override
  Future<bool> hasUserLikedPost({required String postId, required String uid}) async {
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    final doc = await collection.doc(postId).collection('likes').doc(uid).get();
    return doc.exists;
  }

  @override
  Future<bool> hasUserBookmarkedPost({required String postId, required String uid}) async {
    // Check which collection the post is in
    final regularDoc = await _posts.doc(postId).get();
    final collection = regularDoc.exists ? _posts : _communityPosts;
    
    final doc = await collection.doc(postId).collection('bookmarks').doc(uid).get();
    return doc.exists;
  }

  @override
  Stream<PostModel?> postStream(String postId) {
    // Try regular posts stream first, then fallback to community posts
    return _posts.doc(postId).snapshots().asyncMap((d) async {
      if (d.exists) return _fromDoc(d);
      
      // Check community posts if not found in regular posts
      final communityDoc = await _communityPosts.doc(postId).get();
      return communityDoc.exists ? _fromDoc(communityDoc) : null;
    });
  }

  @override
  Stream<List<PostModel>> feedStream({int limit = 20}) {
    return _posts.orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Stream<List<PostModel>> userPostsStream({required String uid, int limit = 20}) {
    return _posts.where('authorId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }
}
