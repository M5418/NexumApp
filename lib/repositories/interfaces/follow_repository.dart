import 'dart:async';

abstract class FollowRepository {
  // Follow a user
  Future<void> followUser(String targetUserId);
  
  // Unfollow a user
  Future<void> unfollowUser(String targetUserId);
  
  // Check if following
  Future<bool> isFollowing({
    required String followerId,
    required String followedId,
  });
  
  // Get followers (paginated)
  Future<List<FollowModel>> getFollowers({
    required String userId,
    int limit = 20,
    FollowModel? lastFollow,
  });
  
  // Get following (paginated)
  Future<List<FollowModel>> getFollowing({
    required String userId,
    int limit = 20,
    FollowModel? lastFollow,
  });
  
  // Get mutual followers
  Future<List<String>> getMutualFollowers({
    required String userId1,
    required String userId2,
    int limit = 20,
  });
  
  // Real-time followers stream
  Stream<List<FollowModel>> followersStream({
    required String userId,
    int limit = 50,
  });
  
  // Real-time following stream
  Stream<List<FollowModel>> followingStream({
    required String userId,
    int limit = 50,
  });

  // Get connections status (for compatibility with ConnectionsApi)
  Future<ConnectionsStatus> getConnectionsStatus();
}

class ConnectionsStatus {
  final Set<String> inbound; // they follow you
  final Set<String> outbound; // you follow them

  ConnectionsStatus({required this.inbound, required this.outbound});
}

class FollowModel {
  final String id;
  final String followerId;
  final String followedId;
  final DateTime createdAt;
  
  FollowModel({
    required this.id,
    required this.followerId,
    required this.followedId,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followedId': followedId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
