import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'app_wrapper.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'repositories/interfaces/storage_repository.dart';
import 'repositories/interfaces/user_repository.dart';
import 'repositories/interfaces/post_repository.dart';
import 'repositories/interfaces/comment_repository.dart';
import 'repositories/interfaces/follow_repository.dart';
import 'repositories/interfaces/notification_repository.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'repositories/interfaces/message_repository.dart';
import 'repositories/interfaces/community_repository.dart';
import 'repositories/interfaces/mentorship_repository.dart';
import 'repositories/interfaces/book_repository.dart';
import 'repositories/interfaces/podcast_repository.dart';
import 'repositories/interfaces/playlist_repository.dart';
import 'repositories/interfaces/story_repository.dart';
import 'repositories/firebase/firebase_auth_repository.dart';
import 'repositories/firebase/firebase_storage_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_comment_repository.dart';
import 'repositories/firebase/firebase_follow_repository.dart';
import 'repositories/firebase/firebase_notification_repository.dart';
import 'repositories/firebase/firebase_conversation_repository.dart';
import 'repositories/firebase/firebase_message_repository.dart';
import 'repositories/firebase/firebase_community_repository.dart';
import 'repositories/firebase/firebase_mentorship_repository.dart';
import 'repositories/firebase/firebase_book_repository.dart';
import 'repositories/firebase/firebase_podcast_repository.dart';
import 'repositories/firebase/firebase_playlist_repository.dart';
import 'repositories/firebase/firebase_story_repository.dart';
import 'repositories/firebase/firebase_kyc_repository.dart';
import 'repositories/firebase/firebase_report_repository.dart';
import 'repositories/firebase/firebase_search_repository.dart';
import 'repositories/firebase/firebase_translate_repository.dart';
import 'repositories/firebase/firebase_invitation_repository.dart';
import 'repositories/interfaces/kyc_repository.dart';
import 'repositories/interfaces/report_repository.dart';
import 'repositories/interfaces/search_repository.dart';
import 'repositories/interfaces/translate_repository.dart';
import 'repositories/interfaces/invitation_repository.dart';
import 'repositories/interfaces/draft_repository.dart';
import 'repositories/firebase/firebase_draft_repository.dart';
import 'repositories/interfaces/livestream_repository.dart';
import 'repositories/firebase/firebase_livestream_repository.dart';
import 'repositories/interfaces/bookmark_repository.dart';
import 'repositories/firebase/firebase_bookmark_repository.dart';
import 'repositories/interfaces/block_repository.dart';
import 'repositories/firebase/firebase_block_repository.dart';
import 'repositories/interfaces/mute_repository.dart';
import 'repositories/firebase/firebase_mute_repository.dart';
import 'repositories/interfaces/analytics_repository.dart';
import 'repositories/firebase/firebase_analytics_repository.dart';
import 'repositories/interfaces/support_repository.dart';
import 'repositories/firebase/firebase_support_repository.dart';
import 'repositories/interfaces/monetization_repository.dart';
import 'repositories/firebase/firebase_monetization_repository.dart';
import 'services/community_interest_sync_service.dart';
import 'services/content_analytics_service.dart';
import 'services/analytics_route_observer.dart';
import 'fix_communities.dart';
import 'providers/follow_state.dart';
import 'config/cache_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background handling
  await Firebase.initializeApp();
  debugPrint('Background message received: ${message.messageId}');
}

/// Sanity check: log Firebase configuration (dev only)
void _sanityLogFirebase() {
  final options = Firebase.app().options;
  debugPrint('Firebase initialized: projectId=${options.projectId} appId=${options.appId}');
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Preserve native splash screen until app is ready
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Configure caching for better performance
  CacheConfig.configureImageCache();
  debugPrint('✅ Image cache configured: 500 images, 200MB');
  
  // Prevent duplicate Firebase initialization on hot reload
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // App already initialized (hot restart), ignore
    debugPrint('Firebase already initialized: $e');
  }
  
  // Set up Firebase Messaging background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Enable Firestore offline persistence for faster loads
  if (!kIsWeb) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('✅ Firestore offline persistence enabled');
    } catch (e) {
      debugPrint('⚠️ Firestore persistence setup failed: $e');
    }
  }
  
  // Sanity check (dev only)
  _sanityLogFirebase();
  
  // App Check Configuration - SAFE VERSION WITH FALLBACKS
  // IMPORTANT: App Check is optional - app works without it
  // We activate it when possible but don't require it
  
  bool appCheckActivated = false;
  
  try {
    if (kIsWeb) {
      // Web: App Check disabled (no reCAPTCHA configured)
      debugPrint('ℹ️ App Check not activated on web (no reCAPTCHA configured)');
    } else {
      // Mobile: Careful activation with fallbacks
      if (kReleaseMode) {
        // TEMPORARY: App Check disabled to test data loading
        // If data works without this, the issue is App Check configuration
        debugPrint('⚠️ App Check TEMPORARILY DISABLED for testing');
        debugPrint('   Testing if data loads without App Check');
        debugPrint('   TODO: Re-enable after confirming Firebase Console is in monitoring mode');
        
        // Production: Use App Attest for iOS with proper error handling
        // try {
        //   debugPrint('🔒 Activating App Check for production...');
        //   
        //   // Set a timeout to prevent hanging
        //   await FirebaseAppCheck.instance.activate(
        //     androidProvider: AndroidProvider.playIntegrity,
        //     appleProvider: AppleProvider.appAttest,
        //   ).timeout(
        //     const Duration(seconds: 5),
        //     onTimeout: () {
        //       debugPrint('⚠️ App Check activation timeout - continuing without it');
        //       return;
        //     },
        //   );
        //   
        //   appCheckActivated = true;
        //   debugPrint('✅ App Check activated with production providers');
        //   debugPrint('   iOS: App Attest, Android: Play Integrity');
        //   debugPrint('   Firebase is in monitoring mode - requests will be tracked but not blocked');
        // } catch (e) {
        //   // App Attest might not be available on older devices or simulator
        //   debugPrint('⚠️ Production App Check activation failed (non-critical)');
        //   debugPrint('   Error: $e');
        //   debugPrint('   App will continue normally - Firebase monitoring mode allows this');
        // }
      } else {
        // Debug: TEMPORARILY DISABLED to avoid simulator errors
        // Re-enable when ready to test App Check
        debugPrint('ℹ️ App Check disabled in debug mode for testing');
        debugPrint('   To enable: uncomment debug provider activation in main.dart');
        
        // Debug: Use debug providers
        // try {
        //   await FirebaseAppCheck.instance.activate(
        //     androidProvider: AndroidProvider.debug,
        //     appleProvider: AppleProvider.debug,
        //   );
        //   appCheckActivated = true;
        //   debugPrint('✅ App Check activated with debug providers');
        // } catch (e) {
        //   debugPrint('⚠️ Debug App Check failed (non-critical): $e');
        // }
      }
    }
  } catch (e) {
    // Catch-all for any unexpected errors
    debugPrint('⚠️ App Check setup error (non-critical): $e');
  }
  
  // Log final App Check status
  debugPrint('📱 App Check Status: ${appCheckActivated ? "ACTIVE" : "INACTIVE (app will work normally)"}');
  
  // Initialize interest-based communities (one-time setup, safe to call multiple times)
  // Wrap in try-catch to prevent crashes
  try {
    CommunityInterestSyncService().initializeInterestCommunities().catchError((e) {
      debugPrint('Community initialization error (non-critical): $e');
    });
  } catch (e) {
    debugPrint('Community service initialization failed: $e');
  }
  
  // Fix all communities with missing/null names (with delay to ensure Firebase is ready)
  // Only run in debug mode to avoid potential production issues
  if (!kReleaseMode) {
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('🔥 Starting community fix...');
      fixAllCommunities().then((_) {
        debugPrint('✅ Community fix completed');
      }).catchError((e) {
        debugPrint('❌ Community fix error: $e');
      });
    });
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        Provider<AuthRepository>(create: (_) => FirebaseAuthRepository()),
        Provider<StorageRepository>(create: (_) => FirebaseStorageRepository()),
        Provider<UserRepository>(create: (_) => FirebaseUserRepository()),
        Provider<PostRepository>(create: (_) => FirebasePostRepository()),
        Provider<CommentRepository>(create: (_) => FirebaseCommentRepository()),
        Provider<FollowRepository>(create: (_) => FirebaseFollowRepository()),
        ChangeNotifierProxyProvider<FollowRepository, FollowState>(
          create: (context) => FollowState(context.read<FollowRepository>()),
          update: (context, repo, state) => state ?? FollowState(repo),
        ),
        Provider<NotificationRepository>(create: (_) => FirebaseNotificationRepository()),
        Provider<ConversationRepository>(create: (_) => FirebaseConversationRepository()),
        Provider<MessageRepository>(create: (_) => FirebaseMessageRepository()),
        Provider<CommunityRepository>(create: (_) => FirebaseCommunityRepository()),
        Provider<MentorshipRepository>(create: (_) => FirebaseMentorshipRepository()),
        Provider<BookRepository>(create: (_) => FirebaseBookRepository()),
        Provider<PodcastRepository>(create: (_) => FirebasePodcastRepository()),
        Provider<PlaylistRepository>(create: (_) => FirebasePlaylistRepository()),
        ProxyProvider2<MessageRepository, FollowRepository, StoryRepository>(
          update: (context, messageRepo, followRepo, previous) => FirebaseStoryRepository(
            messageRepository: messageRepo,
            followRepository: followRepo,
          ),
        ),
        Provider<KycRepository>(create: (_) => FirebaseKycRepository()),
        Provider<ReportRepository>(create: (_) => FirebaseReportRepository()),
        Provider<SearchRepository>(create: (_) => FirebaseSearchRepository()),
        Provider<TranslateRepository>(create: (_) => FirebaseTranslateRepository()),
        Provider<InvitationRepository>(create: (_) => FirebaseInvitationRepository()),
        Provider<DraftRepository>(create: (_) => FirebaseDraftRepository()),
        Provider<BookmarkRepository>(create: (_) => FirebaseBookmarkRepository()),
        Provider<BlockRepository>(create: (_) => FirebaseBlockRepository()),
        Provider<MuteRepository>(create: (_) => FirebaseMuteRepository()),
        Provider<AnalyticsRepository>(create: (_) => FirebaseAnalyticsRepository()),
        Provider<SupportRepository>(create: (_) => FirebaseSupportRepository()),
        Provider<MonetizationRepository>(create: (_) => FirebaseMonetizationRepository()),
        Provider<LiveStreamRepository>(create: (_) => FirebaseLiveStreamRepository()),
        ProxyProvider<MonetizationRepository, ContentAnalyticsService>(
          update: (context, monetizationRepo, previous) =>
              ContentAnalyticsService(monetizationRepo),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Nexum',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            // Drive theme from in-app toggle
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            navigatorObservers: [AnalyticsRouteObserver()],
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
