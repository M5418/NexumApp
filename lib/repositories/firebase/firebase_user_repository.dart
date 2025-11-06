import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fs;
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
      lastActive: ts(d['lastActive']),
      fcmTokens: (d['fcmTokens'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> _toFirestore(UserProfile p) {
    dynamic toTs(DateTime? v) => v == null ? null : Timestamp.fromDate(v);
    return {
      'displayName': p.displayName,
      'username': p.username,
      'firstName': p.firstName,
      'lastName': p.lastName,
      'email': p.email,
      'bio': p.bio,
      'avatarUrl': p.avatarUrl,
      'coverUrl': p.coverUrl,
      'professionalExperiences': p.professionalExperiences,
      'trainings': p.trainings,
      'interestDomains': p.interestDomains,
      'followersCount': p.followersCount,
      'followingCount': p.followingCount,
      'postsCount': p.postsCount,
      'createdAt': toTs(p.createdAt),
      'lastActive': toTs(p.lastActive),
      'fcmTokens': p.fcmTokens,
    };
  }

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return _fromDoc(doc);
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return await getUserProfile(u.uid);
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(_toFirestore(profile), SetOptions(merge: true));
  }

  @override
  Future<String> uploadProfilePhoto({required String uid, required Uint8List imageBytes, required String extension}) async {
    final path = 'users/$uid/profile-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(path);
    await ref.putData(imageBytes);
    return await ref.getDownloadURL();
  }

  @override
  Future<String> uploadCoverPhoto({required String uid, required Uint8List imageBytes, required String extension}) async {
    final path = 'users/$uid/cover-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(path);
    await ref.putData(imageBytes);
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
