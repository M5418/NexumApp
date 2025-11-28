import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'home_feed_page.dart';
import 'sign_in_page.dart';
import 'repositories/interfaces/post_repository.dart';
import 'repositories/interfaces/story_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

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
    final startTime = DateTime.now();
    
    // Initialize auth first
    await _authService.initialize();
    if (_authService.isLoggedIn) {
      await _authService.refreshUser();
    }
    
    // Preload home feed data in parallel with minimum splash time
    await Future.wait([
      _preloadHomeFeed(),
      Future.delayed(const Duration(seconds: 2)), // Minimum 2 seconds splash
    ]);
    
    // Ensure at least 2 seconds, max 3 seconds
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsed);
    }
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _preloadHomeFeed() async {
    try {
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('📱 No user logged in, skipping preload');
        return;
      }
      
      if (!mounted) return;
      
      debugPrint('🚀 Preloading home feed data...');
      
      // Get repositories
      final postRepo = context.read<PostRepository>();
      final storyRepo = context.read<StoryRepository>();
      
      // Preload first page of posts and stories in parallel
      try {
        await Future.wait([
          postRepo.getFeed(limit: 15),
          storyRepo.getStoryRings(),
        ]);
      } catch (e) {
        debugPrint('⚠️ Feed/story preload error (non-critical): $e');
      }
      
      debugPrint('✅ Home feed data preloaded');
    } catch (e) {
      debugPrint('⚠️ Preload error (non-critical): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      // Native splash is showing, return transparent scaffold
      return Scaffold(
        backgroundColor: Colors.white,
        body: Container(),
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