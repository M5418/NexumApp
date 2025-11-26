/// Admin configuration for the Nexum app
/// Contains the official Nexum Team account user ID
class AdminConfig {
  /// Official Nexum Team account user ID
  /// This account has special privileges and modified profile display
  static const String adminUserId = 'pRtNrwPbDQZLyo8Sx5Tpski8rLj1';
  
  /// Check if a given user ID is the admin account
  static bool isAdmin(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return userId == adminUserId;
  }
}
