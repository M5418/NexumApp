import 'dart:async';

/// Model for blocked users
class BlockedUser {
  final String id; // blockedUserId
  final String blockedByUid;
  final String blockedUid;
  final String? blockedUsername;
  final String? blockedAvatarUrl;
  final DateTime createdAt;
  
  BlockedUser({
    required this.id,
    required this.blockedByUid,
    required this.blockedUid,
    this.blockedUsername,
    this.blockedAvatarUrl,
    required this.createdAt,
  });
}

/// Repository interface for blocking users
abstract class BlockRepository {
  /// Block a user
  Future<void> blockUser({
    required String blockedUid,
    String? blockedUsername,
    String? blockedAvatarUrl,
  });
  
  /// Unblock a user
  Future<void> unblockUser(String blockedUid);
  
  /// Check if current user has blocked another user
  Future<bool> hasBlocked(String otherUid);
  
  /// Check if current user is blocked by another user
  Future<bool> isBlockedBy(String otherUid);
  
  /// Get list of users blocked by current user
  Future<List<BlockedUser>> getBlockedUsers();
  
  /// Stream of blocked users
  Stream<List<BlockedUser>> blockedUsersStream();
  
  /// Check if there's any block relationship between two users
  Future<bool> hasBlockRelationship(String uid1, String uid2);
}
