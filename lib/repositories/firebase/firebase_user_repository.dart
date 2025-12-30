import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/foundation.dart';
import '../interfaces/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final fs.FirebaseStorage _storage = fs.FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  UserProfile? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return null;
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    return UserProfile(
      uid: doc.id,
      displayName: d['displayName'],
      username: d['username'],
      firstName: d['firstName'],
      lastName: d['lastName'],
      email: d['email'],
      status: d['status'],
      bio: d['bio'],
      avatarUrl: d['avatarUrl'],
      coverUrl: d['coverUrl'],
      professionalExperiences: (d['professionalExperiences'] as List?)?.cast<Map<String, dynamic>>(),
      trainings: (d['trainings'] as List?)?.cast<Map<String, dynamic>>(),
      interestDomains: (d['interestDomains'] as List?)?.cast<String>(),
      followersCount: d['followersCount'],
      followingCount: d['followingCount'],
      postsCount: d['postsCount'],
      createdAt: ts(d['createdAt']),
      fcmTokens: (d['fcmTokens'] as List?)?.cast<String>(),
      isPremium: d['isPremium'] ?? false,
      premiumSince: ts(d['premiumSince']),
    );
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return _fromDoc(doc);
  }

  /// FAST: Get user profile from cache first (instant)
  Future<UserProfile?> getUserProfileFromCache(String uid) async {
    try {
      final doc = await _users.doc(uid).get(const GetOptions(source: Source.cache));
      return _fromDoc(doc);
    } catch (_) {
      return null; // Cache miss
    }
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return await getUserProfile(u.uid);
  }

  /// FAST: Get current user profile from cache first (instant)
  Future<UserProfile?> getCurrentUserProfileFromCache() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return await getUserProfileFromCache(u.uid);
  }

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }
  
  @override
  Future<List<UserProfile>> getSuggestedUsers({int limit = 12}) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      
      // Try to get recent active users as suggestions
      final snap = await _users
          .orderBy('createdAt', descending: true) // Use createdAt instead of lastActive
          .limit(limit * 3) // Get more to filter out current user
          .get();
      
      final users = snap.docs
          .map(_fromDoc)
          .whereType<UserProfile>()
          .where((u) => u.uid != currentUid) // Exclude current user
          .take(limit)
          .toList();
      
      return users;
    } catch (e) {
      debugPrint('⚠️ Error fetching suggested users: $e');
      // Fallback: get any users without ordering
      try {
        final currentUid = _auth.currentUser?.uid;
        final snap = await _users.limit(limit * 2).get();
        
        final users = snap.docs
            .map(_fromDoc)
            .whereType<UserProfile>()
            .where((u) => u.uid != currentUid)
            .take(limit)
            .toList();
        
        return users;
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  /// FAST: Get suggested users from cache first (instant)
  Future<List<UserProfile>> getSuggestedUsersFromCache({int limit = 12}) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      final snap = await _users
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get(const GetOptions(source: Source.cache));
      
      return snap.docs
          .map(_fromDoc)
          .whereType<UserProfile>()
          .where((u) => u.uid != currentUid)
          .take(limit)
          .toList();
    } catch (_) {
      return []; // Cache miss
    }
  }

  /// FAST: Get users by IDs from cache first (instant)
  Future<List<UserProfile>> getUsersFromCache(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      final results = <UserProfile>[];
      for (final uid in uids) {
        try {
          final doc = await _users.doc(uid).get(const GetOptions(source: Source.cache));
          final profile = _fromDoc(doc);
          if (profile != null) results.add(profile);
        } catch (_) {
          // Skip cache miss for this user
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> uploadProfilePhoto({required String uid, required Uint8List imageBytes, required String extension}) async {
    final path = 'profiles/$uid/avatar/profile-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(path);
    await ref.putData(imageBytes, fs.SettableMetadata(contentType: 'image/$extension'));
    return await ref.getDownloadURL();
  }

  @override
  Future<String> uploadCoverPhoto({required String uid, required Uint8List imageBytes, required String extension}) async {
    final path = 'profiles/$uid/cover/cover-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(path);
    await ref.putData(imageBytes, fs.SettableMetadata(contentType: 'image/$extension'));
    return await ref.getDownloadURL();
  }

  @override
  Future<List<UserProfile>> searchUsers({required String query, int limit = 20}) async {
    final q = query.toLowerCase();
    final snap = await _users
        .where('usernameLower', isGreaterThanOrEqualTo: q)
        .where('usernameLower', isLessThan: '$q\uf8ff')
        .limit(limit)
        .get();
    return snap.docs.map(_fromDoc).whereType<UserProfile>().toList();
  }

  @override
  Future<List<UserProfile>> getUsers(List<String> uids) async {
    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, (i + 10).clamp(0, uids.length)));
    }
    final results = <UserProfile>[];
    for (final c in chunks) {
      final snap = await _users.where(FieldPath.documentId, whereIn: c).get();
      results.addAll(snap.docs.map(_fromDoc).whereType<UserProfile>());
    }
    return results;
  }

  @override
  Future<void> updateFCMToken(String token) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _users.doc(u.uid).set({'fcmTokens': FieldValue.arrayUnion([token])}, SetOptions(merge: true));
  }

  @override
  Future<void> removeFCMToken(String token) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _users.doc(u.uid).set({'fcmTokens': FieldValue.arrayRemove([token])}, SetOptions(merge: true));
  }

  @override
  Stream<UserProfile?> userProfileStream(String uid) {
    return _users.doc(uid).snapshots().map(_fromDoc);
  }
}
