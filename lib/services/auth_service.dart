import 'package:flutter/foundation.dart';
import '../core/token_store.dart';
import '../core/auth_api.dart';
import '../core/profile_api.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isLoggedIn = false;
  String? _userId;
  String? _userToken;
  String? _userName;
  String? _userEmail;
  String? _avatarUrl;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userToken => _userToken;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get avatarUrl => _avatarUrl;

  /// Initialize auth service and check for existing login
  Future<void> initialize() async {
    final token = await TokenStore.read();
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
      _userToken = token;
      await refreshUser(); // populate id/email/profile on app start
    } else {
      _isLoggedIn = false;
    }
    notifyListeners();
  }

  /// Fetch current user id/email and profile; notify listeners
  Future<void> refreshUser() async {
    try {
      final me = await AuthApi().me(); // { ok, data: { id, email } }
      final data = Map<String, dynamic>.from(me['data'] ?? {});
      _userId = data['id']?.toString();
      _userEmail = data['email']?.toString();
    } catch (e) {
      debugPrint('AuthService.refreshUser auth error: $e');
    }

    try {
      final prof = await ProfileApi().me(); // { ok, ... } or minimal
      final pd = Map<String, dynamic>.from(prof['data'] ?? prof);
      final first = (pd['first_name'] ?? '').toString().trim();
      final last = (pd['last_name'] ?? '').toString().trim();
      final username = (pd['username'] ?? '').toString().trim();
      _userName = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (_userName == null || _userName!.isEmpty) {
        _userName = username.isNotEmpty ? username : (_userEmail ?? 'User');
      }
      _avatarUrl = (pd['profile_photo_url'] as String?) ?? _avatarUrl;
    } catch (e) {
      debugPrint('AuthService.refreshUser profile error: $e');
    }

    notifyListeners();
  }

  /// Sign in user (handled by SignInPage with AuthApi; keep for compat)
  Future<bool> signIn(String email, String password) async {
    try {
      return false;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  /// Sign out user and clear token
  Future<void> signOut() async {
    try {
      _isLoggedIn = false;
      _userId = null;
      _userToken = null;
      _userName = null;
      _userEmail = null;
      _avatarUrl = null;
      await TokenStore.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Mark user as logged in (called after successful login)
  void setLoggedIn(String token, {String? userId, String? userName, String? userEmail}) {
    _isLoggedIn = true;
    _userToken = token;
    _userId = userId ?? _userId;
    _userName = userName ?? _userName;
    _userEmail = userEmail ?? _userEmail;
    notifyListeners();
  }

  /// Optional: validate session
  Future<bool> validateSession() async {
    if (!_isLoggedIn || _userToken == null) {
      return false;
    }
    try {
      return true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      await signOut();
      return false;
    }
  }
}