import 'dart:async';
import 'dart:typed_data';

abstract class UserRepository {
  // Get user profile
  Future<UserProfile?> getUserProfile(String uid);
  
  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile();
  
  // Create/update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data);
  
  // Get suggested users
  Future<List<UserProfile>> getSuggestedUsers({int limit = 12});
  
  // Upload profile photo
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List imageBytes,
    required String extension,
  });
  
  // Upload cover photo
  Future<String> uploadCoverPhoto({
    required String uid,
    required Uint8List imageBytes,
    required String extension,
  });
  
  // Search users
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 20,
  });
  
  // Get multiple users
  Future<List<UserProfile>> getUsers(List<String> uids);
  
  // Update FCM token
  Future<void> updateFCMToken(String token);
  
  // Remove FCM token
  Future<void> removeFCMToken(String token);
  
  // Listen to user profile changes
  Stream<UserProfile?> userProfileStream(String uid);
}

class UserProfile {
  final String uid;
  final String? displayName;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? status;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final List<Map<String, dynamic>>? professionalExperiences;
  final List<Map<String, dynamic>>? trainings;
  final List<String>? interestDomains;
  final int? followersCount;
  final int? followingCount;
  final int? postsCount;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final List<String>? fcmTokens;
  
  UserProfile({
    required this.uid,
    this.displayName,
    this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.status,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.professionalExperiences,
    this.trainings,
    this.interestDomains,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.createdAt,
    this.lastActive,
    this.fcmTokens,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'status': status,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'professionalExperiences': professionalExperiences,
      'trainings': trainings,
      'interestDomains': interestDomains,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'createdAt': createdAt?.toIso8601String(),
      'lastActive': lastActive?.toIso8601String(),
      'fcmTokens': fcmTokens,
    };
  }
}
