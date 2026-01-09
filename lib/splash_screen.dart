import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/profile_cache_service.dart';
import 'home_feed_page.dart';
import 'sign_in_page.dart';
import 'repositories/interfaces/post_repository.dart';
import 'repositories/interfaces/story_repository.dart';
import 'repositories/models/post_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Hide all system UI for full-screen bezel-to-bezel experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _initializeAndPreload();
  }

  @override
  void dispose() {
    // Restore system UI when leaving splash
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  Future<void> _initializeAndPreload() async {
    try {
      // Run auth initialization and preloading in parallel
      // Standard splash duration: 500ms minimum for branding visibility
      await Future.wait([
        _initAuth(),
        _preloadHomeFeed(),
        Future.delayed(const Duration(milliseconds: 500)),
      ]);
    } catch (e) {
      debugPrint('⚠️ Splash initialization error: $e');
    }
    
    if (!mounted) return;
    
    // Navigate immediately
    _navigateToNextScreen();
  }

  Future<void> _initAuth() async {
    try {
      debugPrint('🔐 Initializing auth...');
      await _authService.initialize();
      if (_authService.isLoggedIn) {
        await _authService.refreshUser();
      }
      debugPrint('✅ Auth initialized');
    } catch (e) {
      debugPrint('⚠️ Auth initialization error: $e');
    }
  }

  Future<void> _preloadHomeFeed() async {
    try {
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('📱 No user logged in, skipping preload');
        return;
      }
      
      debugPrint('🚀 Preloading home feed + profile data...');
      
      if (!mounted) return;
      
      // Get repositories
      final postRepo = context.read<PostRepository>();
      final storyRepo = context.read<StoryRepository>();
      
      // Preload EVERYTHING in parallel for instant display
      await Future.wait([
        // Preload first 15 posts from feed
        postRepo.getFeed(limit: 15).catchError((e) {
          debugPrint('⚠️ Post preload error: $e');
          return <PostModel>[];
        }),
        
        // Preload story rings
        storyRepo.getStoryRings().catchError((e) {
          debugPrint('⚠️ Story preload error: $e');
          return <StoryRingModel>[];
        }),
        
        // Preload current user's profile + posts into global cache
        ProfileCacheService().preloadCurrentUserData(currentUser.uid).catchError((e) {
          debugPrint('⚠️ Profile cache preload error: $e');
        }),
      ]);
      
      debugPrint('✅ Home feed + profile data preloaded');
    } catch (e) {
      debugPrint('⚠️ Preload error (non-critical): $e');
    }
  }

  void _navigateToNextScreen() {
    // Use replacement to prevent back navigation to splash
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
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
        },
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Full screen, no safe area, bezel to bezel - covers entire device including notch/bezels
    return Container(
      color: Colors.black,
      child: Image.asset(
        'assets/splash/nexumAp.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: const Center(
              child: Text(
                'Nexum',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
