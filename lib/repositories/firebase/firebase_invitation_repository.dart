import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/invitation_repository.dart';
import '../interfaces/conversation_repository.dart';
import 'firebase_conversation_repository.dart';
import 'firebase_user_repository.dart';

class FirebaseInvitationRepository implements InvitationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ConversationRepository _convRepo = FirebaseConversationRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  @override
  Future<String> createInvitation({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) async {
    // Check if invitation already exists
    final existing = await hasInvitationBetween(fromUserId, toUserId);
    if (existing) {
      throw Exception('Invitation already exists');
    }

    final doc = _db.collection('invitations').doc();
    await doc.set({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'message': message,
      'status': 'pending',
      'conversationId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });
    return doc.id;
  }

  @override
  Future<List<InvitationModel>> getSentInvitations(String userId) async {
    try {
      final snapshot = await _db
          .collection('invitations')
          .where('fromUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final models = <InvitationModel>[];
      for (final doc in snapshot.docs) {
        final model = await _fromFirestoreWithUsers(doc);
        models.add(model);
      }
      return models;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<InvitationModel>> getReceivedInvitations(String userId) async {
    try {
      final snapshot = await _db
          .collection('invitations')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();
      
      final models = <InvitationModel>[];
      for (final doc in snapshot.docs) {
        final model = await _fromFirestoreWithUsers(doc);
        models.add(model);
      }
      return models;
    } catch (e) {
      rethrow;
    }
  }
  
  // Convenience methods without userId for current user
  Future<List<InvitationModel>> getMySentInvitations() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return getSentInvitations(user.uid);
  }
  
  Future<List<InvitationModel>> getMyReceivedInvitations() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return getReceivedInvitations(user.uid);
  }

  @override
  Future<String?> acceptInvitation(String invitationId) async {
    // Get the invitation
    final doc = await _db.collection('invitations').doc(invitationId).get();
    if (!doc.exists) {
      throw Exception('Invitation not found');
    }

    final data = doc.data()!;
    if (data['status'] != 'pending') {
      throw Exception('Invitation already responded');
    }

    // Create or get conversation between users
    // Use the toUserId since the accepter is the current user
    final conversationId = await _convRepo.createOrGet(data['fromUserId']);

    // Update invitation status
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'accepted',
      'conversationId': conversationId,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    return conversationId;
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await _db.collection('invitations').doc(invitationId).update({
      'status': 'cancelled',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> hasInvitationBetween(String userId1, String userId2) async {
    // Check both directions
    final query1 = await _db
        .collection('invitations')
        .where('fromUserId', isEqualTo: userId1)
        .where('toUserId', isEqualTo: userId2)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (query1.docs.isNotEmpty) return true;

    final query2 = await _db
        .collection('invitations')
        .where('fromUserId', isEqualTo: userId2)
        .where('toUserId', isEqualTo: userId1)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return query2.docs.isNotEmpty;
  }

  
  Future<InvitationModel> _fromFirestoreWithUsers(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    
    // Fetch sender and receiver details
    final senderProfile = await _userRepo.getUserProfile(data['fromUserId'] ?? '');
    final receiverProfile = await _userRepo.getUserProfile(data['toUserId'] ?? '');
    
    return InvitationModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      message: data['message'],
      status: data['status'] ?? 'pending',
      conversationId: data['conversationId'],
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      respondedAt: _toDateTime(data['respondedAt']),
      sender: senderProfile != null ? InvitationUser(
        id: senderProfile.uid,
        name: senderProfile.displayName ?? senderProfile.username ?? 'User',
        username: '@${senderProfile.username ?? 'user'}',
        avatarUrl: senderProfile.avatarUrl,
      ) : null,
      receiver: receiverProfile != null ? InvitationUser(
        id: receiverProfile.uid,
        name: receiverProfile.displayName ?? receiverProfile.username ?? 'User',
        username: '@${receiverProfile.username ?? 'user'}',
        avatarUrl: receiverProfile.avatarUrl,
      ) : null,
    );
  }
  
  // Compatibility methods
  Future<void> refuseInvitation(String invitationId) => declineInvitation(invitationId);
  Future<void> deleteInvitation(String invitationId) => cancelInvitation(invitationId);

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
