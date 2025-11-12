import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/block_repository.dart';

class FirebaseBlockRepository implements BlockRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  CollectionReference get _blocks => _firestore.collection('blocks');
  
  String? get _currentUid => _auth.currentUser?.uid;
  
  BlockedUser _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedUser(
      id: doc.id,
      blockedByUid: data['blockedByUid'] ?? '',
      blockedUid: data['blockedUid'] ?? '',
      blockedUsername: data['blockedUsername'],
      blockedAvatarUrl: data['blockedAvatarUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  @override
  Future<void> blockUser({
    required String blockedUid,
    String? blockedUsername,
    String? blockedAvatarUrl,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Not authenticated');
    if (uid == blockedUid) throw Exception('Cannot block yourself');
    
    await _blocks.add({
      'blockedByUid': uid,
      'blockedUid': blockedUid,
      'blockedUsername': blockedUsername,
      'blockedAvatarUrl': blockedAvatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  Future<void> unblockUser(String blockedUid) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Not authenticated');
    
    final snapshot = await _blocks
        .where('blockedByUid', isEqualTo: uid)
        .where('blockedUid', isEqualTo: blockedUid)
        .limit(1)
        .get();
    
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
  
  @override
  Future<bool> hasBlocked(String otherUid) async {
    final uid = _currentUid;
    if (uid == null) return false;
    
    final snapshot = await _blocks
        .where('blockedByUid', isEqualTo: uid)
        .where('blockedUid', isEqualTo: otherUid)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
  
  @override
  Future<bool> isBlockedBy(String otherUid) async {
    final uid = _currentUid;
    if (uid == null) return false;
    
    final snapshot = await _blocks
        .where('blockedByUid', isEqualTo: otherUid)
        .where('blockedUid', isEqualTo: uid)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
  
  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    final uid = _currentUid;
    if (uid == null) return [];
    
    final snapshot = await _blocks
        .where('blockedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map(_fromDoc).toList();
  }
  
  @override
  Stream<List<BlockedUser>> blockedUsersStream() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);
    
    return _blocks
        .where('blockedByUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }
  
  @override
  Future<bool> hasBlockRelationship(String uid1, String uid2) async {
    // Check if uid1 blocked uid2 OR uid2 blocked uid1
    final snapshot = await _blocks
        .where('blockedByUid', whereIn: [uid1, uid2])
        .where('blockedUid', whereIn: [uid1, uid2])
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
}
