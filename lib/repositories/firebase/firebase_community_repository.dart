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
    try {
      final q = await _communities.orderBy('createdAt', descending: true).limit(limit).get();
      print('✅ Communities.listAll fetched: ${q.docs.length} communities');
      return q.docs.map(_fromDoc).toList();
    } catch (e) {
      print('❌ Communities.listAll error: $e');
      print('🔍 Check: 1) Firestore rules for communities 2) Network connectivity');
      rethrow;
    }
  }

  @override
  Future<List<CommunityModel>> listMine({int limit = 100}) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        print('⚠️  Communities.listMine: No authenticated user');
        return [];
      }
      
      print('🔍 Communities.listMine: Authenticated as ${u.uid}');
      print('🔍 Querying collectionGroup("members").where("userId", "==", "${u.uid}")');
      
      final ids = <String>{};
      final q1 = await _db
          .collectionGroup('members')
          .where('userId', isEqualTo: u.uid)
          .limit(500)
          .get();
      
      print('🔍 Query 1 (userId field) returned: ${q1.docs.length} docs');

      var docs = q1.docs;
      if (docs.isEmpty) {
        print('🔍 Trying fallback query with "uid" field...');
        final q2 = await _db
            .collectionGroup('members')
            .where('uid', isEqualTo: u.uid)
            .limit(500)
            .get();
        print('🔍 Query 2 (uid field) returned: ${q2.docs.length} docs');
        docs = q2.docs;
      }

      for (final m in docs) {
        final parent = m.reference.parent.parent;
        if (parent != null) ids.add(parent.id);
      }

      if (ids.isEmpty) {
        print('🔍 No members found via collectionGroup, trying direct lookup...');
        final all = await _communities.limit(200).get();
        print('🔍 Found ${all.docs.length} total communities to check');
        for (final c in all.docs) {
          final exists = await c.reference.collection('members').doc(u.uid).get();
          if (exists.exists) {
            print('🔍 Found membership in community: ${c.id}');
            ids.add(c.id);
          }
        }
      }

      final results = <CommunityModel>[];
      for (final chunk in _chunk(ids.toList(), 10)) {
        final snap = await _communities.where(FieldPath.documentId, whereIn: chunk).get();
        results.addAll(snap.docs.map(_fromDoc));
      }
      print('✅ Communities.listMine fetched: ${results.length} communities');
      return results;
    } catch (e) {
      print('❌ Communities.listMine error: $e');
      print('🔍 Check: 1) Firestore rules for communities/members 2) Auth status');
      rethrow;
    }
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
    try {
      final q = await _communities.doc(communityId).collection('members').limit(limit).get();
      print('✅ Community members fetched: ${q.docs.length} members for $communityId');
      return q.docs.map(_memberFrom).toList();
    } catch (e) {
      print('❌ Communities.members error for $communityId: $e');
      rethrow;
    }
  }
}
