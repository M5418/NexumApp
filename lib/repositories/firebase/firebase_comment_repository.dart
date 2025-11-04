import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/comment_repository.dart';

class FirebaseCommentRepository implements CommentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _comments => _db.collection('comments');

  DocumentReference<Map<String, dynamic>> _commentRef(String commentId) => _comments.doc(commentId);

  CommentModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CommentModel(
      id: doc.id,
      postId: d['postId'] ?? '',
      authorId: d['authorId'] ?? '',
      text: d['text'] ?? '',
      parentCommentId: d['parentCommentId'],
      likesCount: d['likesCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<String> createComment({required String postId, required String text, String? parentCommentId}) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final ref = await _comments.add({
      'postId': postId,
      'authorId': u.uid,
      'text': text,
      'parentCommentId': parentCommentId,
      'likesCount': 0,
      'createdAt': Timestamp.now(),
    });
    // Best-effort increment on post summary
    try {
      await _db.collection('posts').doc(postId).update({'summary.comments': FieldValue.increment(1)});
    } catch (_) {}
    return ref.id;
  }

  @override
  Future<List<CommentModel>> getComments({required String postId, int limit = 20, CommentModel? lastComment}) async {
    Query<Map<String, dynamic>> q = _comments.where('postId', isEqualTo: postId).orderBy('createdAt', descending: false).limit(limit);
    if (lastComment?.createdAt != null) {
      q = q.startAfter([Timestamp.fromDate(lastComment!.createdAt)]);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<CommentModel?> getComment(String commentId) async {
    final doc = await _commentRef(commentId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<void> updateComment({required String commentId, required String text}) async {
    await _commentRef(commentId).update({'text': text, 'updatedAt': Timestamp.now()});
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final doc = await _commentRef(commentId).get();
    final data = doc.data();
    await _commentRef(commentId).delete();
    // Best-effort decrement on post summary
    try {
      final postId = data?['postId'] as String?;
      if (postId != null && postId.isNotEmpty) {
        await _db.collection('posts').doc(postId).update({'summary.comments': FieldValue.increment(-1)});
      }
    } catch (_) {}
  }

  @override
  Future<void> likeComment(String commentId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final likeRef = _commentRef(commentId).collection('likes').doc(u.uid);
    final batch = _db.batch();
    batch.set(likeRef, {'createdAt': Timestamp.now()});
    batch.update(_commentRef(commentId), {'likesCount': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> unlikeComment(String commentId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final likeRef = _commentRef(commentId).collection('likes').doc(u.uid);
    final batch = _db.batch();
    batch.delete(likeRef);
    batch.update(_commentRef(commentId), {'likesCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  @override
  Stream<List<CommentModel>> commentsStream({required String postId, int limit = 50}) {
    return _comments
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }
}
