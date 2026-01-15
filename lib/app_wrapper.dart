import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/onboarding_service.dart';
import 'home_feed_page.dart';
import 'sign_in_page.dart';
import 'profile_flow_start.dart';
import 'profile_name_page.dart';
import 'profile_birthday_page.dart';
import 'profile_gender_page.dart';
import 'profile_address_page.dart';
import 'profile_bio_page.dart';
import 'interest_selection_page.dart';
import 'connect_friends_page.dart';
import 'profile_photo_page.dart';
import 'profile_cover_page.dart';
import 'profile_completion_welcome.dart';
import 'status_selection_page.dart';
import 'profile_experience_page.dart';
import 'profile_training_page.dart';
import 'repositories/interfaces/post_repository.dart';
import 'repositories/interfaces/story_repository.dart';
import 'repositories/models/post_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'services/profile_cache_service.dart';
import 'services/app_cache_service.dart';
import 'local/web/web_cache_warmer.dart';
import 'core/admin_config.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  final AuthService _authService = AuthService();
  final PushNotificationService _pushService = PushNotificationService();
  final OnboardingService _onboardingService = OnboardingService();
  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  bool _onboardingChecked = false;

  @override
  void initState() {
    super.initState();
    _initializeAndPreload();
    
    // Failsafe: Force onboarding check after 3 seconds on web
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_onboardingChecked) {
          debugPrint('⏰ Forcing onboarding check on web');
          setState(() => _onboardingChecked = true);
        }
      });
    }
  }

  Future<void> _initializeAndPreload() async {
    try {
      // Initialize auth with timeout to prevent hanging on web
      await _authService.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ Auth initialization timed out');
        },
      );
      
      // Initialize onboarding service if user is logged in
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _onboardingService.initialize(currentUser.uid).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⚠️ Onboarding initialization timed out');
          },
        );
      }
    } catch (e) {
      debugPrint('⚠️ Initialization error: $e');
    }
    
    if (mounted) {
      setState(() => _onboardingChecked = true);
    }
    
    // Initialize push notifications and splash (skip on web)
    if (!kIsWeb) {
      await _pushService.initialize();
      
      // Listen for notification taps
      _notificationSub = _pushService.onNotificationTap.listen((data) {
        if (mounted && _authService.isLoggedIn) {
          _handleNotificationNavigation(data);
        }
      });
      
      // Remove native splash screen - app is ready
      FlutterNativeSplash.remove();
    }
    
    // Continue preloading in background (non-blocking)
    _preloadInBackground();
  }
  
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // TODO: Implement notification navigation when needed
    // For now, just log the notification data to avoid crashes
    debugPrint('📱 Notification tapped: $data');
  }

  void _preloadInBackground() {
    // Run preload async without blocking UI
    () async {
      try {
        final currentUser = fb.FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        
        if (!mounted) return;
        
        // Refresh user token in background
        _authService.refreshUser().catchError((_) {});
        
        // Get repositories
        final postRepo = context.read<PostRepository>();
        final storyRepo = context.read<StoryRepository>();
        
        // Preload all data in parallel (background, non-blocking)
        await Future.wait([
          postRepo.getFeed(limit: 15).catchError((_) => <PostModel>[]),
          storyRepo.getStoryRings().catchError((_) => <StoryRingModel>[]),
          ProfileCacheService().preloadCurrentUserData(currentUser.uid).catchError((_) {}),
          AppCacheService().preloadAppData(currentUser.uid).catchError((_) {}),
        ]);
        
        debugPrint('✅ Background preload complete');
      } catch (e) {
        debugPrint('⚠️ Background preload error (non-critical): $e');
      }
    }();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  /// Get the appropriate page based on onboarding step
  Widget _getOnboardingPage(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.signUp:
      case OnboardingStep.profileFlowStart:
        return const ProfileFlowStart();
      case OnboardingStep.name:
        return const ProfileNamePage();
      case OnboardingStep.birthday:
        return const ProfileBirthdayPage();
      case OnboardingStep.gender:
        return const ProfileGenderPage();
      case OnboardingStep.address:
        return const ProfileAddressPage();
      case OnboardingStep.photo:
        return const ProfilePhotoPage();
      case OnboardingStep.cover:
        return const ProfileCoverPage();
      case OnboardingStep.welcome:
        return const ProfileCompletionWelcome();
      case OnboardingStep.status:
        return const StatusSelectionPage();
      case OnboardingStep.experience:
        return const ProfileExperiencePage();
      case OnboardingStep.training:
        return const ProfileTrainingPage();
      case OnboardingStep.bio:
        return const ProfileBioPage();
      case OnboardingStep.interests:
        return const InterestSelectionPage();
      case OnboardingStep.connectFriends:
        return const ConnectFriendsPage();
      case OnboardingStep.completed:
        return const HomeFeedPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, child) {
        // Not logged in - show sign in page
        if (!_authService.isLoggedIn) {
          return const SignInPage();
        }
        
        // On web, skip onboarding check and show home feed directly
        if (kIsWeb) {
          // Warm user-specific cache data now that we're authenticated
          final userId = fb.FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            WebCacheWarmer().warmUserData(userId);
          }
          return const HomeFeedPage();
        }
        
        // Mobile: User is logged in - check onboarding status
        if (!_onboardingChecked) {
          // Still loading onboarding status - show loading indicator
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
            ),
          );
        }
        
        // Skip onboarding for admin account
        final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
        if (AdminConfig.isAdmin(currentUserId)) {
          return const HomeFeedPage();
        }
        
        // Check if onboarding is complete
        if (_onboardingService.isOnboardingComplete) {
          return const HomeFeedPage();
        }
        
        // User needs to complete onboarding - show appropriate page
        return _getOnboardingPage(_onboardingService.currentStep);
      },
    );
  }
}