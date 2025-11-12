import 'dart:async';

/// Model for muted users
class MutedUser {
  final String id; // mutedUserId
  final String mutedByUid;
  final String mutedUid;
  final String? mutedUsername;
  final String? mutedAvatarUrl;
  final DateTime createdAt;
  
  MutedUser({
    required this.id,
    required this.mutedByUid,
    required this.mutedUid,
    this.mutedUsername,
    this.mutedAvatarUrl,
    required this.createdAt,
  });
}

/// Repository interface for muting users (notifications only)
abstract class MuteRepository {
  /// Mute a user's notifications
  Future<void> muteUser({
    required String mutedUid,
    String? mutedUsername,
    String? mutedAvatarUrl,
  });
  
  /// Unmute a user's notifications
  Future<void> unmuteUser(String mutedUid);
  
  /// Check if current user has muted another user
  Future<bool> hasMuted(String otherUid);
  
  /// Get list of users muted by current user
  Future<List<MutedUser>> getMutedUsers();
  
  /// Stream of muted users
  Stream<List<MutedUser>> mutedUsersStream();
}
