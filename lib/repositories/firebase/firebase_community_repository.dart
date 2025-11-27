import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/community_repository.dart';

class FirebaseCommunityRepository implements CommunityRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _communities => _db.collection('communities');

  CommunityModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return CommunityModel(
      id: doc.id,
      name: (data?['name'] ?? '').toString(),
      avatarUrl: (data?['avatarUrl'] ?? '').toString(),
      bio: (data?['bio'] ?? '').toString(),
      coverUrl: (data?['coverUrl'] ?? '').toString().isEmpty ? null : data?['coverUrl'].toString(),
      friendsInCommon: (data?['friendsInCommon'] ?? '+0').toString(),
      unreadPosts: (data?['unreadPosts'] is num) ? (data?['unreadPosts'] as num).toInt() : 0,
      postsCount: (data?['postsCount'] is num) ? (data?['postsCount'] as num).toInt() : 0,
      memberCount: (data?['memberCount'] is num) ? (data?['memberCount'] as num).toInt() : 0,
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
  Future<List<CommunityModel>> listAll({int limit = 100, String? lastCommunityId}) async {
    try {
      // Admin sees communities sorted alphabetically A-Z
      Query<Map<String, dynamic>> q = _communities.orderBy('name', descending: false).limit(limit);
      
      // Add pagination cursor if provided
      if (lastCommunityId != null) {
        final lastDoc = await _communities.doc(lastCommunityId).get();
        if (lastDoc.exists) {
          q = q.startAfterDocument(lastDoc);
        }
      }
      
      final snap = await q.get();
      return snap.docs.map(_fromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<CommunityModel>> listMine({int limit = 100, String? lastCommunityId}) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        return [];
      }
      
      final ids = <String>{};
      final q1 = await _db
          .collectionGroup('members')
          .where('userId', isEqualTo: u.uid)
          .limit(500)
          .get();

      var docs = q1.docs;

      if (docs.isEmpty) {
        final q2 = await _db
            .collectionGroup('members')
            .where('uid', isEqualTo: u.uid)
            .limit(500)
            .get();
        docs = q2.docs;
      }

      for (final m in docs) {
        final parent = m.reference.parent.parent;
        if (parent != null) ids.add(parent.id);
      }

      if (ids.isEmpty) {
        final all = await _communities.limit(200).get();
        for (final c in all.docs) {
          final exists = await c.reference.collection('members').doc(u.uid).get();
          if (exists.exists) {
            ids.add(c.id);
          }
        }
      }

      // Get all communities and sort by createdAt
      final results = <CommunityModel>[];
      for (final chunk in _chunk(ids.toList(), 10)) {
        final snap = await _communities.where(FieldPath.documentId, whereIn: chunk).get();
        results.addAll(snap.docs.map(_fromDoc));
      }
      
      // Sort by createdAt descending
      results.sort((a, b) => b.id.compareTo(a.id));
      
      // Apply pagination if lastCommunityId is provided
      if (lastCommunityId != null) {
        final startIndex = results.indexWhere((c) => c.id == lastCommunityId);
        if (startIndex >= 0 && startIndex + 1 < results.length) {
          return results.sublist(startIndex + 1).take(limit).toList();
        }
        return [];
      }
      
      return results.take(limit).toList();
    } catch (e) {
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
      return q.docs.map(_memberFrom).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateCommunity({
    required String communityId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
      if (coverUrl != null) updates['coverUrl'] = coverUrl;
      
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await _communities.doc(communityId).update(updates);
      }
    } catch (e) {
      rethrow;
    }
  }
}
