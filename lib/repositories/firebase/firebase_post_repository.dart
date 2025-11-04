import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/post_repository.dart';
import '../models/post_model.dart';

class FirebasePostRepository implements PostRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  PostModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PostModel.fromFirestore(doc);
  }

  @override
  Future<String> createPost({required String text, List<String>? mediaUrls, String? repostOf}) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final data = PostModel(
      id: '',
      authorId: u.uid,
      text: text,
      mediaUrls: mediaUrls ?? const [],
      summary: PostSummary(),
      repostOf: repostOf,
      createdAt: DateTime.now(),
    ).toMap();
    final ref = await _posts.add(data);
    if (repostOf != null && repostOf.isNotEmpty) {
      await _posts.doc(repostOf).update({'summary.reposts': FieldValue.increment(1)});
    }
    return ref.id;
  }

  @override
  Future<PostModel?> getPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<void> updatePost({required String postId, required String text, List<String>? mediaUrls}) async {
    await _posts.doc(postId).update({'text': text, if (mediaUrls != null) 'mediaUrls': mediaUrls, 'updatedAt': Timestamp.now()});
  }

  @override
  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
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

  @override
  Future<List<PostModel>> getUserPosts({required String uid, int limit = 20, PostModel? lastPost}) async {
    Query<Map<String, dynamic>> q = _posts.where('authorId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(limit);
    if (lastPost?.snapshot != null) {
      q = q.startAfterDocument(lastPost!.snapshot!);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<PostModel>> getCommunityPosts({required String communityId, int limit = 20, PostModel? lastPost}) async {
    Query<Map<String, dynamic>> q = _posts.where('communityId', isEqualTo: communityId).orderBy('createdAt', descending: true).limit(limit);
    if (lastPost?.snapshot != null) {
      q = q.startAfterDocument(lastPost!.snapshot!);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> likePost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final likeRef = _posts.doc(postId).collection('likes').doc(u.uid);
    final batch = _db.batch();
    batch.set(likeRef, {'createdAt': Timestamp.now()});
    batch.update(_posts.doc(postId), {'summary.likes': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> unlikePost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final likeRef = _posts.doc(postId).collection('likes').doc(u.uid);
    final batch = _db.batch();
    batch.delete(likeRef);
    batch.update(_posts.doc(postId), {'summary.likes': FieldValue.increment(-1)});
    await batch.commit();
  }

  @override
  Future<void> bookmarkPost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final ref = _posts.doc(postId).collection('bookmarks').doc(u.uid);
    final batch = _db.batch();
    batch.set(ref, {'createdAt': Timestamp.now()});
    batch.update(_posts.doc(postId), {'summary.bookmarks': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> unbookmarkPost(String postId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final ref = _posts.doc(postId).collection('bookmarks').doc(u.uid);
    final batch = _db.batch();
    batch.delete(ref);
    batch.update(_posts.doc(postId), {'summary.bookmarks': FieldValue.increment(-1)});
    await batch.commit();
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
    final q = await _posts.where('authorId', isEqualTo: u.uid).where('repostOf', isEqualTo: postId).limit(1).get();
    if (q.docs.isNotEmpty) {
      await _posts.doc(q.docs.first.id).delete();
      await _posts.doc(postId).update({'summary.reposts': FieldValue.increment(-1)});
    }
  }

  @override
  Future<List<String>> getPostLikes({required String postId, int limit = 20, String? lastUserId}) async {
    Query<Map<String, dynamic>> q = _posts.doc(postId).collection('likes').orderBy('createdAt', descending: true).limit(limit);
    if (lastUserId != null) {
      final lastDoc = await _posts.doc(postId).collection('likes').doc(lastUserId).get();
      if (lastDoc.exists) {
        q = q.startAfterDocument(lastDoc);
      }
    }
    final snap = await q.get();
    return snap.docs.map((d) => d.id).toList();
  }

  @override
  Future<bool> hasUserLikedPost({required String postId, required String uid}) async {
    final doc = await _posts.doc(postId).collection('likes').doc(uid).get();
    return doc.exists;
  }

  @override
  Future<bool> hasUserBookmarkedPost({required String postId, required String uid}) async {
    final doc = await _posts.doc(postId).collection('bookmarks').doc(uid).get();
    return doc.exists;
  }

  @override
  Stream<PostModel?> postStream(String postId) {
    return _posts.doc(postId).snapshots().map((d) => d.exists ? _fromDoc(d) : null);
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
