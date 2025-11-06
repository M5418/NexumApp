import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/community_repository.dart';

class FirebaseCommunityRepository implements CommunityRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _communities => _db.collection('communities');

  CommunityModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return CommunityModel(
      id: d.id,
      name: (m['name'] ?? '').toString(),
      avatarUrl: (m['avatarUrl'] ?? '').toString(),
      bio: (m['bio'] ?? '').toString(),
      coverUrl: (m['coverUrl'] ?? '').toString().isEmpty ? null : m['coverUrl'].toString(),
      friendsInCommon: (m['friendsInCommon'] ?? '+0').toString(),
      unreadPosts: (m['unreadPosts'] is num) ? (m['unreadPosts'] as num).toInt() : 0,
      postsCount: (m['postsCount'] is num) ? (m['postsCount'] as num).toInt() : 0,
      memberCount: (m['memberCount'] is num) ? (m['memberCount'] as num).toInt() : 0,
    );
  }

  CommunityMemberModel _memberFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return CommunityMemberModel(
      id: d.id,
      name: (m['name'] ?? m['displayName'] ?? m['username'] ?? 'User').toString(),
      username: (m['username'] ?? '').toString().isEmpty ? null : m['username'].toString(),
      avatarUrl: (m['avatarUrl'] ?? '').toString().isEmpty ? null : m['avatarUrl'].toString(),
      avatarLetter: null,
    );
  }

  @override
  Future<List<CommunityModel>> listAll({int limit = 100}) async {
    final q = await _communities.orderBy('createdAt', descending: true).limit(limit).get();
    return q.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<CommunityModel>> listMine({int limit = 100}) async {
    final u = _auth.currentUser;
    if (u == null) return [];
    // Find all membership docs for this user
    final mems = await _db.collectionGroup('members').where(FieldPath.documentId, isEqualTo: u.uid).limit(500).get();
    final ids = <String>{};
    for (final m in mems.docs) {
      final parent = m.reference.parent.parent; // communities/{id}
      if (parent != null) ids.add(parent.id);
    }
    final results = <CommunityModel>[];
    for (final chunk in _chunk(ids.toList(), 10)) {
      final snap = await _communities.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_fromDoc));
    }
    return results;
  }

  Iterable<List<String>> _chunk(List<String> arr, int size) sync* {
    for (var i = 0; i < arr.length; i += size) {
      final end = (i + size > arr.length) ? arr.length : (i + size);
      yield arr.sublist(i, end);
    }
  }

  @override
  Future<CommunityModel?> details(String communityId) async {
    final d = await _communities.doc(communityId).get();
    if (!d.exists) return null;
    return _fromDoc(d);
  }

  @override
  Future<List<CommunityMemberModel>> members(String communityId, {int limit = 200}) async {
    final q = await _communities.doc(communityId).collection('members').limit(limit).get();
    return q.docs.map(_memberFrom).toList();
  }
}
