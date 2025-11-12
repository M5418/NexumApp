import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_wrapper.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'repositories/interfaces/bookmark_repository.dart';
import 'repositories/firebase/firebase_bookmark_repository.dart';
import 'repositories/interfaces/block_repository.dart';
import 'repositories/firebase/firebase_block_repository.dart';
import 'repositories/interfaces/mute_repository.dart';
import 'repositories/firebase/firebase_mute_repository.dart';
import 'services/community_interest_sync_service.dart';

// Firebase App Check reCAPTCHA Enterprise site key
// Pass via --dart-define when running:
// flutter run -d chrome --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<your_key>
const String kRecaptchaEnterpriseSiteKey = String.fromEnvironment(
  'RECAPTCHA_ENTERPRISE_SITE_KEY',
  defaultValue: '',
);

/// Sanity check: log Firebase configuration (dev only)
void _sanityLogFirebase() {
  final options = Firebase.app().options;
  debugPrint('Firebase initialized: projectId=${options.projectId} appId=${options.appId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Prevent duplicate Firebase initialization on hot reload
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // App already initialized (hot restart), ignore
    debugPrint('Firebase already initialized: $e');
  }
  
  // Sanity check (dev only)
  _sanityLogFirebase();
  
  // Initialize interest-based communities (one-time setup, safe to call multiple times)
  CommunityInterestSyncService().initializeInterestCommunities().catchError((e) {
    debugPrint('Community initialization error (non-critical): $e');
  });
  
  // App Check Configuration
  // Firebase Console: Keep all services in Monitoring (not Enforced)
  // Web: reCAPTCHA Enterprise only
  // Mobile: Platform-specific providers
  if (kIsWeb) {
    if (kRecaptchaEnterpriseSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(kRecaptchaEnterpriseSiteKey),
      );
    }
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode 
        ? AndroidProvider.playIntegrity 
        : AndroidProvider.debug,
      appleProvider: kReleaseMode 
        ? AppleProvider.appAttest 
        : AppleProvider.debug,
    );
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
        Provider<NotificationRepository>(create: (_) => FirebaseNotificationRepository()),
        Provider<ConversationRepository>(create: (_) => FirebaseConversationRepository()),
        Provider<MessageRepository>(create: (_) => FirebaseMessageRepository()),
        Provider<CommunityRepository>(create: (_) => FirebaseCommunityRepository()),
        Provider<MentorshipRepository>(create: (_) => FirebaseMentorshipRepository()),
        Provider<BookRepository>(create: (_) => FirebaseBookRepository()),
        Provider<PodcastRepository>(create: (_) => FirebasePodcastRepository()),
        Provider<StoryRepository>(create: (_) => FirebaseStoryRepository()),
        Provider<KycRepository>(create: (_) => FirebaseKycRepository()),
        Provider<ReportRepository>(create: (_) => FirebaseReportRepository()),
        Provider<SearchRepository>(create: (_) => FirebaseSearchRepository()),
        Provider<TranslateRepository>(create: (_) => FirebaseTranslateRepository()),
        Provider<InvitationRepository>(create: (_) => FirebaseInvitationRepository()),
        Provider<DraftRepository>(create: (_) => FirebaseDraftRepository()),
        Provider<BookmarkRepository>(create: (_) => FirebaseBookmarkRepository()),
        Provider<BlockRepository>(create: (_) => FirebaseBlockRepository()),
        Provider<MuteRepository>(create: (_) => FirebaseMuteRepository()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Nexum',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            // Drive theme from in-app toggle
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
