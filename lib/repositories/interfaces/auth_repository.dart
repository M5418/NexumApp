import 'dart:async';

abstract class AuthRepository {
  // Auth state stream
  Stream<AuthUser?> get authStateChanges;
  
  // Current user
  AuthUser? get currentUser;
  
  // Sign up with email/password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  });
  
  // Sign in with email/password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });
  
  // Sign out
  Future<void> signOut();
  
  // Password reset
  Future<void> sendPasswordResetEmail(String email);
  
  // Email verification
  Future<void> sendEmailVerification();
  
  // Update password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  });
  
  // Update email
  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  });
  
  // Delete account
  Future<void> deleteAccount({required String password});
  
  // Refresh token
  Future<String?> getIdToken({bool forceRefresh = false});
  
  // Custom claims
  Future<Map<String, dynamic>> getCustomClaims();
}

class AuthUser {
  final String uid;
  final String? email;
  final bool emailVerified;
  final String? displayName;
  final String? photoURL;
  final DateTime? createdAt;
  
  AuthUser({
    required this.uid,
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.photoURL,
    this.createdAt,
  });
}

class AuthResult {
  final bool success;
  final AuthUser? user;
  final String? error;
  
  AuthResult({
    required this.success,
    this.user,
    this.error,
  });
}
