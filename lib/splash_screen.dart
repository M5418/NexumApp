import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
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
    final startTime = DateTime.now();
    
    try {
      // Run auth initialization and preloading in parallel
      await Future.wait([
        _initAuth(),
        _preloadHomeFeed(),
        // Minimum 2 seconds for splash
        Future.delayed(const Duration(seconds: 2)),
      ]);
    } catch (e) {
      debugPrint('⚠️ Splash initialization error: $e');
      // Still wait for minimum time
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(seconds: 2)) {
        await Future.delayed(const Duration(seconds: 2) - elapsed);
      }
    }
    
    if (!mounted) return;
    
    // Navigate to appropriate page
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
      
      debugPrint('🚀 Preloading home feed data...');
      
      if (!mounted) return;
      
      // Get repositories
      final postRepo = context.read<PostRepository>();
      final storyRepo = context.read<StoryRepository>();
      
      // Preload first page of posts and stories in parallel
      // This will cache them for instant display when HomeFeedPage opens
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
      ]);
      
      debugPrint('✅ Home feed data preloaded');
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
    // Full screen, no safe area, bezel to bezel
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash/nexumAp.png',
          fit: BoxFit.cover, // Cover entire screen
          errorBuilder: (context, error, stackTrace) {
            // Fallback to solid color if image fails to load
            return Container(
              color: const Color(0xFFBFAE01), // Nexum gold color
              child: Center(
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
      ),
    );
  }
}
