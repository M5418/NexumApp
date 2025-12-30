import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'home_feed_page.dart';
import 'sign_in_page.dart';
import 'repositories/interfaces/post_repository.dart';
import 'repositories/interfaces/story_repository.dart';
import 'repositories/models/post_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'services/profile_cache_service.dart';
import 'services/app_cache_service.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  final AuthService _authService = AuthService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAndPreload();
  }

  Future<void> _initializeAndPreload() async {
    // Initialize auth - this is fast, no artificial delays
    await _authService.initialize();
    
    // Show UI immediately after auth check
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
    
    // Continue preloading in background (non-blocking)
    _preloadInBackground();
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
  Widget build(BuildContext context) {
    if (_isInitializing) {
      // Show black screen to match native splash while initializing
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    return ListenableBuilder(
      listenable: _authService,
      builder: (context, child) {
        if (_authService.isLoggedIn) {
          return const HomeFeedPage();
        } else {
          return const SignInPage();
        }
      },
    );
  }
}