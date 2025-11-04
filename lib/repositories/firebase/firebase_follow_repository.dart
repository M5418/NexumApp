import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/follow_repository.dart';

class FirebaseFollowRepository implements FollowRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _follows => _db.collection('follows');

  String _docId(String followerId, String followedId) => '${followerId}_$followedId';

  FollowModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FollowModel(
      id: doc.id,
      followerId: d['followerId'] ?? '',
      followedId: d['followedId'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<void> followUser(String targetUserId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    await _follows.doc(_docId(u.uid, targetUserId)).set({
      'followerId': u.uid,
      'followedId': targetUserId,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Future<void> unfollowUser(String targetUserId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    await _follows.doc(_docId(u.uid, targetUserId)).delete();
  }

  @override
  Future<bool> isFollowing({required String followerId, required String followedId}) async {
    final doc = await _follows.doc(_docId(followerId, followedId)).get();
    return doc.exists;
  }

  @override
  Future<List<FollowModel>> getFollowers({required String userId, int limit = 20, FollowModel? lastFollow}) async {
    Query<Map<String, dynamic>> q = _follows.where('followedId', isEqualTo: userId).orderBy('createdAt', descending: true).limit(limit);
    if (lastFollow != null) {
      q = q.startAfter([Timestamp.fromDate(lastFollow.createdAt)]);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<FollowModel>> getFollowing({required String userId, int limit = 20, FollowModel? lastFollow}) async {
    Query<Map<String, dynamic>> q = _follows.where('followerId', isEqualTo: userId).orderBy('createdAt', descending: true).limit(limit);
    if (lastFollow != null) {
      q = q.startAfter([Timestamp.fromDate(lastFollow.createdAt)]);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<String>> getMutualFollowers({required String userId1, required String userId2, int limit = 20}) async {
    final f1 = await _follows.where('followedId', isEqualTo: userId1).limit(500).get();
    final f2 = await _follows.where('followedId', isEqualTo: userId2).limit(500).get();
    final set1 = f1.docs.map((d) => (d.data()['followerId'] ?? '') as String).toSet();
    final set2 = f2.docs.map((d) => (d.data()['followerId'] ?? '') as String).toSet();
    final mutual = set1.intersection(set2).toList();
    if (mutual.length > limit) {
      return mutual.sublist(0, limit);
    }
    return mutual;
  }

  @override
  Stream<List<FollowModel>> followersStream({required String userId, int limit = 50}) {
    return _follows.where('followedId', isEqualTo: userId).orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Stream<List<FollowModel>> followingStream({required String userId, int limit = 50}) {
    return _follows.where('followerId', isEqualTo: userId).orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }
}
