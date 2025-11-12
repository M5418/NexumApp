import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/mute_repository.dart';

class FirebaseMuteRepository implements MuteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  CollectionReference get _mutes => _firestore.collection('mutes');
  
  String? get _currentUid => _auth.currentUser?.uid;
  
  MutedUser _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MutedUser(
      id: doc.id,
      mutedByUid: data['mutedByUid'] ?? '',
      mutedUid: data['mutedUid'] ?? '',
      mutedUsername: data['mutedUsername'],
      mutedAvatarUrl: data['mutedAvatarUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  @override
  Future<void> muteUser({
    required String mutedUid,
    String? mutedUsername,
    String? mutedAvatarUrl,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Not authenticated');
    if (uid == mutedUid) throw Exception('Cannot mute yourself');
    
    await _mutes.add({
      'mutedByUid': uid,
      'mutedUid': mutedUid,
      'mutedUsername': mutedUsername,
      'mutedAvatarUrl': mutedAvatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<void> unmuteUser(String mutedUid) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Not authenticated');
    
    final snapshot = await _mutes
        .where('mutedByUid', isEqualTo: uid)
        .where('mutedUid', isEqualTo: mutedUid)
        .limit(1)
        .get();
    
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
  
  @override
  Future<bool> hasMuted(String otherUid) async {
    final uid = _currentUid;
    if (uid == null) return false;
    
    final snapshot = await _mutes
        .where('mutedByUid', isEqualTo: uid)
        .where('mutedUid', isEqualTo: otherUid)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
  
  @override
  Future<List<MutedUser>> getMutedUsers() async {
    final uid = _currentUid;
    if (uid == null) return [];
    
    final snapshot = await _mutes
        .where('mutedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map(_fromDoc).toList();
  }
  
  @override
  Stream<List<MutedUser>> mutedUsersStream() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);
    
    return _mutes
        .where('mutedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }
}
