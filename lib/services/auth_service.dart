import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isLoggedIn = false;
  String? _userId;
  String? _userToken;
  String? _userName;
  String? _userEmail;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userToken => _userToken;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  /// Initialize auth service and check for existing login
  Future<void> initialize() async {
    // In a real app, you would check SharedPreferences or secure storage
    // For now, we'll simulate checking for stored credentials
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate being already logged in as Dehoua Guy
    _isLoggedIn = true;
    _userId = 'user_dehoua_guy';
    _userToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
    _userName = 'Dehoua Guy';
    _userEmail = 'dehoua.guy@nexum.com';

    notifyListeners();
  }

  /// Sign in user
  Future<bool> signIn(String email, String password) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // For demo purposes, accept any email/password
      if (email.isNotEmpty && password.isNotEmpty) {
        _isLoggedIn = true;
        _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
        _userToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
        _userName = 'Dehoua Guy';
        _userEmail = email;

        // In a real app, save to secure storage here

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      _isLoggedIn = false;
      _userId = null;
      _userToken = null;
      _userName = null;
      _userEmail = null;

      // In a real app, clear secure storage here

      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Check if user session is still valid
  Future<bool> validateSession() async {
    if (!_isLoggedIn || _userToken == null) {
      return false;
    }

    try {
      // Simulate API call to validate token
      await Future.delayed(const Duration(milliseconds: 300));

      // For demo, assume session is always valid if we have a token
      return true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      await signOut();
      return false;
    }
  }
}
