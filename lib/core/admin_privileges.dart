import '../repositories/interfaces/user_repository.dart';

/// Helper class for managing admin privileges throughout the app
/// Admin accounts are official Nexum Team accounts with special access
class AdminPrivileges {
  /// Check if a user can message another user
  /// Admin can message anyone, regular users need to be connected
  static bool canMessageUser(UserProfile currentUser, String targetUserId) {
    // TODO: Implement admin check when isAdmin field is added to UserProfile
    // if (currentUser.isAdmin) return true;
    
    // TODO: Check connections when connections field is added
    // return currentUser.connections?.contains(targetUserId) ?? false;
    return true;  // Allow all messaging for now
  }
  
  /// Check if a user can access a specific community
  /// Admin can access all communities, regular users see interest-based only
  static bool canAccessCommunity(UserProfile currentUser, String? communityCategory) {
    // TODO: Implement admin check when isAdmin field is added
    // if (currentUser.isAdmin) return true;
    
    if (communityCategory == null) return true;  // Public community
    
    // Regular users must have matching interests
    return currentUser.interestDomains?.contains(communityCategory) ?? false;
  }
  
  /// Check if a user can create books
  /// Only admin can create books (exclusive content curation)
  static bool canCreateBooks(UserProfile currentUser) {
    // TODO: Implement admin check when isAdmin field is added
    // return currentUser.isAdmin;
    return true;  // Allow all users for now
  }
  
  /// Check if a user can create podcasts
  /// Anyone can create podcasts (public feature)
  static bool canCreatePodcasts(UserProfile currentUser) {
    return true;  // Open to all users
  }
  
  /// Check if a user profile should be visible in search/discover
  /// Both admin and regular users are visible
  static bool isVisibleInSearch(UserProfile user) {
    return true;  // Admin is public-facing, appears in search
  }
  
  /// Check if a user can connect with another user
  /// Everyone can connect with everyone (including admin)
  /// Note: Connections to admin are instant and bidirectional (no invitation needed)
  static bool canConnect(UserProfile currentUser, UserProfile targetUser) {
    return true;  // Admin can be connected to, just like regular users
  }
  
  /// Check if professional sections should be shown on profile
  /// Admin profiles hide professional experience, trainings, and interests
  static bool shouldShowProfessionalSections(UserProfile user) {
    // TODO: Implement admin check when isAdmin field is added
    // return !user.isAdmin;
    return true;  // Show for all users for now
  }
  
  /// Get the user badge type for display
  /// Returns: 'admin' for admin users, 'verified' for KYC verified, null for none
  static String? getUserBadgeType(UserProfile user) {
    // TODO: Implement admin check when isAdmin field is added
    // if (user.isAdmin) return 'admin';
    // Add KYC verification check here when implemented
    // if (user.isVerified) return 'verified';
    return null;  // No badges for now
  }
}
