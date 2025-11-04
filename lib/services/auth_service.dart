import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/firebase/firebase_notification_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as fm;

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

  final FirebaseAuthRepository _fbAuth = FirebaseAuthRepository();
  final FirebaseUserRepository _fbUsers = FirebaseUserRepository();
  final FirebaseNotificationRepository _fbNotifs = FirebaseNotificationRepository();
  StreamSubscription? _fbAuthSub;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userToken => _userToken;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get avatarUrl => _avatarUrl;

  /// Initialize auth service and check for existing login
  Future<void> initialize() async {
    _fbAuthSub ??= _fbAuth.authStateChanges.listen((u) async {
      _userId = u?.uid;
      _userEmail = u?.email;
      _isLoggedIn = u != null;
      if (_isLoggedIn) {
        await refreshUser();
      }
      notifyListeners();
    });

    final fbUser = _fbAuth.currentUser;
    _isLoggedIn = fbUser != null;
    if (_isLoggedIn) {
      _userId = fbUser!.uid;
      _userEmail = fbUser.email;
      await refreshUser();
    }
    notifyListeners();
  }

  Future<void> _setupMessaging() async {
    final fu = _fbAuth.currentUser;
    if (fu == null) return;
    final settings = await fm.FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == fm.AuthorizationStatus.denied) return;
    final token = await fm.FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _fbUsers.updateFCMToken(token);
      await _fbNotifs.subscribeTopic('direct:user:${fu.uid}');
      await _fbNotifs.subscribeTopic('feed:new-post');
      await _fbNotifs.subscribeTopic('system:announcements');
    }
  }

  /// Fetch current user id/email and profile; notify listeners
  Future<void> refreshUser() async {
    try {
      final fu = _fbAuth.currentUser;
      if (fu != null) {
        _userId = fu.uid;
        _userEmail = fu.email;
        final prof = await _fbUsers.getCurrentUserProfile();
        if (prof != null) {
          final first = (prof.firstName ?? '').trim();
          final last = (prof.lastName ?? '').trim();
          final dn = (prof.displayName ?? '').trim();
          _userName = [first, last].where((s) => s.isNotEmpty).join(' ');
          if (_userName == null || _userName!.isEmpty) {
            _userName = dn.isNotEmpty ? dn : (_userEmail ?? 'User');
          }
          _avatarUrl = prof.avatarUrl ?? _avatarUrl;
          await _setupMessaging();
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('AuthService.refreshUser firebase error: $e');
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
      try {
        await _fbAuth.signOut();
      } catch (_) {}
      try {
        final t = await fm.FirebaseMessaging.instance.getToken();
        if (t != null && t.isNotEmpty) {
          await _fbUsers.removeFCMToken(t);
        }
        final uid = _userId;
        if (uid != null && uid.isNotEmpty) {
          await _fbNotifs.unsubscribeTopic('direct:user:$uid');
        }
        await _fbNotifs.unsubscribeTopic('feed:new-post');
        await _fbNotifs.unsubscribeTopic('system:announcements');
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Mark user as logged in (called after successful login)
  void setLoggedIn(String token,
      {String? userId, String? userName, String? userEmail}) {
    _isLoggedIn = true;
    _userToken = token;
    _userId = userId ?? _userId;
    _userName = userName ?? _userName;
    _userEmail = userEmail ?? _userEmail;
    notifyListeners();
  }

  /// Optional: validate session
  Future<bool> validateSession() async {
    final fu = _fbAuth.currentUser;
    return fu != null;
  }
}
