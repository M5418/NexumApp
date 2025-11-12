abstract class InvitationRepository {
  // Create invitation
  Future<String> createInvitation({
    required String fromUserId,
    required String toUserId,
    String? message,
  });

  // Get invitations sent by user
  Future<List<InvitationModel>> getSentInvitations(String userId);

  // Get invitations received by user
  Future<List<InvitationModel>> getReceivedInvitations(String userId);

  // Accept invitation (creates conversation)
  Future<String?> acceptInvitation(String invitationId);

  // Decline invitation
  Future<void> declineInvitation(String invitationId);

  // Cancel invitation (by sender)
  Future<void> cancelInvitation(String invitationId);

  // Check if invitation exists between users
  Future<bool> hasInvitationBetween(String userId1, String userId2);
}

class InvitationModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String? message;
  final String status; // 'pending', 'accepted', 'declined', 'cancelled'
  final String? conversationId; // Set when accepted
  final DateTime createdAt;
  final DateTime? respondedAt;
  // User details for UI
  final InvitationUser? sender;
  final InvitationUser? receiver;
  
  // Compatibility properties
  String get senderId => fromUserId;
  String get invitationContent => message ?? '';

  InvitationModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.message,
    required this.status,
    this.conversationId,
    required this.createdAt,
    this.respondedAt,
    this.sender,
    this.receiver,
  });
}

class InvitationUser {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  
  InvitationUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });
}
