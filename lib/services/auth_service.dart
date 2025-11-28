import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/firebase/firebase_notification_repository.dart';
import '../repositories/interfaces/user_repository.dart';
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
    // Skip messaging setup on web - FCM requires platform-specific configuration
    if (kIsWeb) {
      debugPrint('📱 Messaging setup skipped on web platform');
      return;
    }
    
    final fu = _fbAuth.currentUser;
    if (fu == null) return;
    
    try {
      // Add timeout to prevent hanging/freezing
      await fm.FirebaseMessaging.instance.setAutoInitEnabled(true).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ Messaging auto-init timed out - likely on simulator');
          return;
        },
      );
      
      final settings = await fm.FirebaseMessaging.instance.requestPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ Messaging permission request timed out');
          return fm.NotificationSettings(
            authorizationStatus: fm.AuthorizationStatus.denied,
            alert: fm.AppleNotificationSetting.disabled,
            announcement: fm.AppleNotificationSetting.disabled,
            badge: fm.AppleNotificationSetting.disabled,
            carPlay: fm.AppleNotificationSetting.disabled,
            lockScreen: fm.AppleNotificationSetting.disabled,
            notificationCenter: fm.AppleNotificationSetting.disabled,
            showPreviews: fm.AppleShowPreviewSetting.never,
            timeSensitive: fm.AppleNotificationSetting.disabled,
            criticalAlert: fm.AppleNotificationSetting.disabled,
            sound: fm.AppleNotificationSetting.disabled,
            providesAppNotificationSettings: fm.AppleNotificationSetting.disabled,
          );
        },
      );
      
      if (settings.authorizationStatus == fm.AuthorizationStatus.denied) return;

      final token = await fm.FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ FCM token request timed out');
          return null;
        },
      );
      
      if (token != null && token.isNotEmpty) {
        await _fbUsers.updateFCMToken(token);
        await _fbNotifs.subscribeTopic('direct:user:${fu.uid}');
        await _fbNotifs.subscribeTopic('feed:new-post');
        await _fbNotifs.subscribeTopic('system:announcements');
      }
    } catch (e) {
      debugPrint('Messaging setup error (non-critical): $e');
    }
  }

  /// Fetch current user id/email and profile; notify listeners
  Future<void> refreshUser() async {
    try {
      final fu = _fbAuth.currentUser;
      debugPrint('🔍 refreshUser: currentUser=${fu?.uid ?? "NULL"}');
      debugPrint('🔍 refreshUser: email=${fu?.email ?? "NULL"}');
      
      if (fu == null) {
        debugPrint('❌ No authenticated user, skipping profile fetch');
        notifyListeners();
        return;
      }

      // Ensure auth token is available before Firestore query
      try {
        final fbUser = fb.FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final token = await fbUser.getIdToken(true); // Force refresh to ensure token is ready
          debugPrint('✅ Auth token refreshed: ${token != null && token.isNotEmpty}');
        }
      } catch (e) {
        debugPrint('⚠️  Token refresh failed: $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _userId = fu.uid;
      _userEmail = fu.email;
      debugPrint('🔍 Attempting to fetch profile for uid: ${fu.uid}');
      
      // Retry logic for profile fetch (handles timing issues)
      UserProfile? prof;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          debugPrint('📥 Fetch attempt ${attempt + 1}/3...');
          prof = await _fbUsers.getCurrentUserProfile();
          if (prof != null) {
            debugPrint('✅ Profile fetched successfully');
            break;
          } else {
            debugPrint('⚠️  Profile returned null (document may not exist)');
            
            // CREATE USER DOCUMENT IF IT DOESN'T EXIST (critical for TestFlight)
            if (attempt == 0) {
              debugPrint('📝 Creating user document for ${fu.uid}...');
              try {
                await _fbUsers.updateUserProfile(fu.uid, {
                  'uid': fu.uid,
                  'email': fu.email ?? '',
                  'displayName': fu.displayName ?? '',
                  'avatarUrl': fu.photoURL ?? '',
                  'createdAt': FieldValue.serverTimestamp(),
                  'lastActive': FieldValue.serverTimestamp(),
                  'firstName': '',
                  'lastName': '',
                  'username': '',
                  'bio': '',
                  'status': '',
                  'dateOfBirth': '',
                  'gender': '',
                  'address': '',
                  'city': '',
                  'country': '',
                  'isVerified': false,
                  'followersCount': 0,
                  'followingCount': 0,
                  'postsCount': 0,
                  'professionalExperiences': [],
                  'trainings': [],
                  'interestDomains': [],
                });
                debugPrint('✅ User document created, retrying profile fetch...');
                // Continue to next attempt to fetch the newly created profile
              } catch (createError) {
                debugPrint('❌ Failed to create user document: $createError');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Attempt ${attempt + 1} failed: $e');
          if (attempt == 2) {
            debugPrint('🚨 CRITICAL: Profile fetch failed after 3 attempts: $e');
            debugPrint('🔍 Check: 1) Firestore rules deployed? 2) Auth token valid? 3) Network connection?');
          } else {
            await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
          }
        }
      }
      
      if (prof != null) {
        final first = (prof.firstName ?? '').trim();
        final last = (prof.lastName ?? '').trim();
        final dn = (prof.displayName ?? '').trim();
        final fullName = [first, last].where((s) => s.isNotEmpty).join(' ');
        _userName = fullName.isNotEmpty ? fullName : (dn.isNotEmpty ? dn : (_userEmail ?? 'User'));
        _avatarUrl = prof.avatarUrl ?? _avatarUrl;
        await _setupMessaging();
      }
    } catch (e) {
      debugPrint('AuthService.refreshUser critical error: $e');
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
      final uid = _userId; // capture before clearing
      try {
        final t = await fm.FirebaseMessaging.instance.getToken();
        if (t != null && t.isNotEmpty) {
          await _fbUsers.removeFCMToken(t);
        }
        if (uid != null && uid.isNotEmpty) {
          await _fbNotifs.unsubscribeTopic('direct:user:$uid');
        }
        await _fbNotifs.unsubscribeTopic('feed:new-post');
        await _fbNotifs.unsubscribeTopic('system:announcements');
      } catch (_) {}
      try {
        await _fbAuth.signOut();
      } catch (_) {}
      _isLoggedIn = false;
      _userId = null;
      _userToken = null;
      _userName = null;
      _userEmail = null;
      _avatarUrl = null;
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
