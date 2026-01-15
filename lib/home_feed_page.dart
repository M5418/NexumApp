import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/story_ring.dart' as story_widget;
import 'widgets/post_card.dart';
import 'widgets/post_skeleton.dart';
import 'widgets/badge_icon.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'widgets/connection_card.dart';
import 'connections_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart';
import 'profile_page.dart';
import 'post_page.dart';
// removed PostsApi usage
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_comment_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/models/post_model.dart';
import 'repositories/interfaces/story_repository.dart';
import 'repositories/firebase/firebase_story_repository.dart';
import 'repositories/interfaces/bookmark_repository.dart';
import 'repositories/models/bookmark_model.dart';
import 'models/post.dart';
import 'models/comment.dart';
import 'theme_provider.dart';
import 'search_page.dart';
import 'notification_page.dart';
import 'story_viewer_page.dart';
import 'story_compose_pages.dart';
import 'widgets/tools_overlay.dart';
import 'podcasts/podcasts_home_page.dart';
import 'books/books_home_page.dart';
import 'mentorship/mentorship_home_page.dart';
import 'video_scroll_page.dart';
import 'livestream/livestream_list_page.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'repositories/firebase/firebase_notification_repository.dart';
import 'repositories/interfaces/block_repository.dart';
import 'core/post_events.dart';
import 'core/profile_api.dart'; // Feed preferences
import 'responsive/responsive_breakpoints.dart';
import 'core/i18n/language_provider.dart';
import 'core/performance_monitor.dart';
import 'core/performance/performance_coordinator.dart';
import 'local/local_store.dart';
import 'local/repositories/local_post_repository.dart';
import 'local/repositories/local_story_repository.dart';

class HomeFeedPage extends StatefulWidget {
  final int initialNavIndex;
  
  const HomeFeedPage({super.key, this.initialNavIndex = 0});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  late int _selectedNavIndex;
  List<Post> _posts = [];
  bool _isInitialLoading = true; // Show skeletons on first load
  List<StoryRingModel> _storyRings = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  int _conversationsInitialTabIndex = 0; // 0: Chats, 1: Communities
  String? _currentUserId;
  int _desktopSectionIndex =
      0; // 0=Home, 1=Connections, 2=Conversations, 3=Profile

  // Unread notifications badge
  int _unreadCount = 0;

  // Live updates between feed and post page
  StreamSubscription<PostUpdateEvent>? _postEventsSub;

  // Feed preferences (defaults)
  bool _prefShowReposts = true;
  bool _prefShowSuggested = true;
  bool _prefPrioritizeInterests = true;
  List<String> _myInterests = [];
  
  // Blocked users list
  Set<String> _blockedUserIds = {};

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  PostModel? _lastPost;
  
  // Performance-adaptive page size (from PerformanceCoordinator)
  int get _postsPerPage => PerformanceCoordinator().feedPageSize;

  final FirebasePostRepository _postRepo = FirebasePostRepository();
  final FirebaseCommentRepository _commentRepo = FirebaseCommentRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = widget.initialNavIndex;
    // ULTRA-FAST: Load cached posts INSTANTLY, then refresh
    () async {
      // 1. INSTANT: Show cached posts immediately (no await on user ID)
      await _loadFromCacheInstantly();
      
      // 2. PARALLEL: Load user ID + fresh posts + everything else simultaneously
      _loadCurrentUserId();
      _loadFreshPosts(); // Will update UI when ready
      _loadBlockedUsers().then((_) {
        if (mounted) setState(() => _posts = _applyFeedFilters(_posts));
      });
      _loadFeedPrefs().then((_) {
        if (mounted) setState(() => _posts = _applyFeedFilters(_posts));
      });
      _loadUnreadCount();
      _loadStoriesInBackground();
      _loadSuggestedUsers();
    }();

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Subscribe to post update events to keep feed in sync with PostPage
    _postEventsSub = PostEvents.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _posts = _posts.map((p) {
          if (p.id == e.originalPostId ||
              p.originalPostId == e.originalPostId) {
            return p.copyWith(
              counts: e.counts,
              userReaction: e.userReaction ?? p.userReaction,
              isBookmarked: e.isBookmarked ?? p.isBookmarked,
            );
          }
          return p;
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postEventsSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // User scrolled to 80% of the content
      if (!_isLoadingMore && _hasMorePosts) {
        _loadMorePosts();
      }
    }
  }

  bool _useDesktopPopup(BuildContext context) {
    if (kIsWeb) {
      // On web, use width to decide "desktop" vs "mobile"
      final w = MediaQuery.of(context).size.width;
      return w >= 900;
    }
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final u = fb.FirebaseAuth.instance.currentUser;
      final id = u?.uid;
      if (!mounted) return;
      setState(() {
        _currentUserId = id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
      });
    }
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final blockRepo = context.read<BlockRepository>();
      final blockedUsers = await blockRepo.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedUserIds = blockedUsers.map((u) => u.blockedUid).toSet();
      });
    } catch (e) {
      // Ignore error, defaults to empty set
    }
  }

  Future<void> _loadFeedPrefs() async {
    try {
      final res = await ProfileApi().me();
      final data = (res['ok'] == true && res['data'] != null)
          ? Map<String, dynamic>.from(res['data'])
          : Map<String, dynamic>.from(res);

      final interestsRaw = data['interest_domains'];
      final interestsList = (interestsRaw is List)
          ? interestsRaw.map((e) => e.toString()).toList()
          : <String>[];

      if (!mounted) return;
      setState(() {
        // Default to true if not set
        if (data['show_reposts'] == null) {
          _prefShowReposts = true;
        } else {
          _prefShowReposts = (data['show_reposts'] is bool)
              ? data['show_reposts']
              : (data['show_reposts'] == 1 ||
                  data['show_reposts'] == '1' ||
                  (data['show_reposts'] is String &&
                      (data['show_reposts'] as String).toLowerCase() == 'true'));
        }
        debugPrint('🔁 Repost preference: $_prefShowReposts (from backend: ${data['show_reposts']})');

        _prefShowSuggested = (data['show_suggested_posts'] is bool)
            ? data['show_suggested_posts']
            : (data['show_suggested_posts'] == 1 ||
                data['show_suggested_posts'] == '1' ||
                (data['show_suggested_posts'] is String &&
                    (data['show_suggested_posts'] as String).toLowerCase() ==
                        'true'));

        _prefPrioritizeInterests = (data['prioritize_interests'] is bool)
            ? data['prioritize_interests']
            : (data['prioritize_interests'] == 1 ||
                data['prioritize_interests'] == '1' ||
                (data['prioritize_interests'] is String &&
                    (data['prioritize_interests'] as String).toLowerCase() ==
                        'true'));

        _myInterests = interestsList;
      });
    } catch (_) {
      // Use defaults
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final c = await FirebaseNotificationRepository().getUnreadCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = c;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
      });
    }
  }

  /// BACKGROUND: Load like/bookmark status for posts (non-blocking)
  Future<void> _loadUserInteractionsInBackground(List<Post> posts) async {
    if (_currentUserId == null || posts.isEmpty) return;
    
    try {
      // Get unique post IDs (use originalPostId for reposts)
      final postIds = posts.map((p) => p.originalPostId ?? p.id).toSet().toList();
      
      // Check like/bookmark status for each post in parallel
      final results = await Future.wait(postIds.map((postId) async {
        try {
          final liked = await _postRepo.hasUserLikedPost(postId: postId, uid: _currentUserId!);
          final bookmarked = await _postRepo.hasUserBookmarkedPost(postId: postId, uid: _currentUserId!);
          return {'postId': postId, 'liked': liked, 'bookmarked': bookmarked};
        } catch (_) {
          return {'postId': postId, 'liked': false, 'bookmarked': false};
        }
      }));
      
      if (!mounted) return;
      
      // Build lookup map
      final statusMap = <String, Map<String, bool>>{};
      for (final r in results) {
        statusMap[r['postId'] as String] = {
          'liked': r['liked'] as bool,
          'bookmarked': r['bookmarked'] as bool,
        };
      }
      
      // Update posts with actual status
      setState(() {
        _posts = _posts.map((p) {
          final effectiveId = p.originalPostId ?? p.id;
          final status = statusMap[effectiveId];
          if (status != null) {
            return p.copyWith(
              userReaction: status['liked'] == true ? ReactionType.like : null,
              isBookmarked: status['bookmarked'] ?? false,
            );
          }
          return p;
        }).toList();
      });
    } catch (e) {
      debugPrint('⚠️ [FastFeed] Failed to load user interactions: $e');
    }
  }

  /// INSTANT: Load from Isar first (mobile), then Firestore cache (web/fallback)
  Future<void> _loadFromCacheInstantly() async {
    PerformanceMonitor().startFeedLoad();
    final stopwatch = Stopwatch()..start();
    
    // Try Isar first (mobile-only, instant)
    if (isIsarSupported) {
      final isarPosts = LocalPostRepository().getLocalSync(limit: _postsPerPage);
      if (isarPosts.isNotEmpty && mounted) {
        final posts = _mapIsarPostsToUI(isarPosts);
        if (posts.isNotEmpty) {
          setState(() {
            _posts = posts;
            _isInitialLoading = false;
          });
          stopwatch.stop();
          PerformanceMonitor().stopFeedLoad(postCount: posts.length);
          PerformanceCoordinator().recordFeedLoadTime(stopwatch.elapsedMilliseconds);
          debugPrint('📱 [FastFeed] Loaded ${posts.length} posts from Isar');
          return;
        }
      }
    }
    
    // Fallback to Firestore cache (web or Isar empty)
    try {
      final models = await _postRepo.getFeedFromCache(limit: _postsPerPage);
      if (models.isNotEmpty && mounted) {
        // Only show posts that have complete author data (not "User" placeholder)
        final postsWithValidData = models.where((m) => 
          m.authorName != null && 
          m.authorName!.isNotEmpty && 
          m.authorName != 'User'
        ).toList();
        
        if (postsWithValidData.isNotEmpty) {
          final posts = _mapModelsToPostsFast(postsWithValidData);
          setState(() {
            _posts = posts;
            _isInitialLoading = false; // Hide skeletons INSTANTLY
          });
          stopwatch.stop();
          PerformanceMonitor().stopFeedLoad(postCount: posts.length);
          PerformanceCoordinator().recordFeedLoadTime(stopwatch.elapsedMilliseconds);
        }
        // If no valid posts in cache, keep showing skeletons until fresh data loads
      }
    } catch (_) {
      // Cache miss - will load from server
      stopwatch.stop();
      PerformanceMonitor().stopFeedLoad(postCount: 0);
      PerformanceCoordinator().recordFeedLoadTime(stopwatch.elapsedMilliseconds);
    }
  }
  
  /// Convert Isar PostLite models to UI Post objects
  List<Post> _mapIsarPostsToUI(List<PostLite> isarPosts) {
    return isarPosts.where((p) => 
      p.authorName != null && 
      p.authorName!.isNotEmpty && 
      p.authorName != 'User'
    ).map((p) {
      // Determine media type from stored types
      MediaType mediaType = MediaType.none;
      String? videoUrl;
      if (p.mediaTypes.isNotEmpty) {
        if (p.mediaTypes.any((t) => t == 'video')) {
          mediaType = MediaType.video;
          // Find video URL
          for (int i = 0; i < p.mediaTypes.length && i < p.mediaUrls.length; i++) {
            if (p.mediaTypes[i] == 'video') {
              videoUrl = p.mediaUrls[i];
              break;
            }
          }
        } else {
          mediaType = p.mediaUrls.length > 1 ? MediaType.images : MediaType.image;
        }
      }
      
      // Use mediaThumbUrls for images (fast loading), fallback to mediaUrls
      final imageUrls = p.mediaThumbUrls.isNotEmpty ? p.mediaThumbUrls : p.mediaUrls;
      
      return Post(
        id: p.id,
        authorId: p.authorId,
        userName: p.authorName ?? 'User',
        userAvatarUrl: p.authorPhotoUrl ?? '',
        text: p.caption ?? '',
        mediaType: mediaType,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        counts: PostCounts(
          likes: p.likeCount,
          comments: p.commentCount,
          shares: p.shareCount,
          reposts: p.repostCount,
          bookmarks: p.bookmarkCount,
        ),
        createdAt: p.createdAt,
        isBookmarked: false, // Will be loaded in background
        isRepost: p.repostOf != null && p.repostOf!.isNotEmpty,
        originalPostId: p.repostOf,
      );
    }).toList();
  }

  /// BACKGROUND: Load fresh posts from server and update UI
  Future<void> _loadFreshPosts() async {
    try {
      final models = await _postRepo.getFeed(limit: _postsPerPage);
      if (models.isNotEmpty) {
        _lastPost = models.last;
        _hasMorePosts = models.length == _postsPerPage;
      } else {
        _hasMorePosts = false;
      }
      
      // Hydrate ALL author data BEFORE displaying (blocking) to avoid "User" flash
      // This includes both regular posts AND original posts for reposts
      final hydratedModels = await _hydrateAllAuthorData(models);
      
      final posts = _mapModelsToPostsFast(hydratedModels);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isInitialLoading = false;
      });
      
      // Load like/bookmark status in background (non-blocking)
      _loadUserInteractionsInBackground(posts);
      
      // Prefetch next page in background
      _prefetchNextBatch();
    } catch (e) {
      if (!mounted) return;
      if (_posts.isEmpty) {
        setState(() => _isInitialLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('feed.load_failed')}: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// BACKGROUND: Load stories without blocking posts
  Future<void> _loadStoriesInBackground() async {
    final storyRepo = context.read<StoryRepository>();
    // FASTFEED: Load from cache first for instant display
    await _loadStoriesFromCacheInstantly();
    
    // Then refresh from server
    try {
      var rings = await storyRepo.getStoryRings();
      
      rings = await _sortStoryRingsAsync(rings, storyRepo);
      
      if (!mounted) return;
      setState(() {
        _storyRings = rings;
      });
    } catch (e) {
      debugPrint('⚠️ [FastFeed] Stories failed: ${_toError(e)}');
    }
  }

  /// INSTANT: Load cached stories (no network wait)
  Future<void> _loadStoriesFromCacheInstantly() async {
    // ISAR-FIRST: Try Isar local cache first (mobile only)
    if (isIsarSupported) {
      final isarStories = LocalStoryRepository().getLocalSync(limit: 50);
      if (isarStories.isNotEmpty && mounted) {
        final rings = _mapIsarStoriesToRings(isarStories);
        if (rings.isNotEmpty) {
          setState(() {
            _storyRings = _sortStoryRings(rings);
          });
          debugPrint('📱 [FastStories] Loaded ${rings.length} story rings from Isar');
          return;
        }
      }
    }
    
    // Fallback: Firestore cache
    try {
      final storyRepo = context.read<StoryRepository>();
      // Use the cache method if available (FirebaseStoryRepository)
      if (storyRepo is FirebaseStoryRepository) {
        var rings = await storyRepo.getStoryRingsFromCache();
        if (rings.isNotEmpty && mounted) {
          rings = _sortStoryRings(rings);
          setState(() {
            _storyRings = rings;
          });
        }
      }
    } catch (_) {
      // Cache miss - will load from server
    }
  }
  
  /// Convert Isar StoryLite models to StoryRingModel (grouped by author)
  List<StoryRingModel> _mapIsarStoriesToRings(List<StoryLite> stories) {
    final Map<String, List<StoryLite>> byAuthor = {};
    for (final s in stories) {
      byAuthor.putIfAbsent(s.authorId, () => []).add(s);
    }
    
    return byAuthor.entries.map((e) {
      final authorStories = e.value;
      final first = authorStories.first;
      final hasUnseen = authorStories.any((s) => !s.viewed);
      
      return StoryRingModel(
        userId: first.authorId,
        userName: first.authorName ?? 'User',
        userAvatar: first.authorPhotoUrl,
        hasUnseen: hasUnseen,
        lastStoryAt: authorStories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b),
        thumbnailUrl: first.mediaThumbUrl ?? first.mediaUrl,
        storyCount: authorStories.length,
        stories: authorStories.map((s) => StoryModel(
          id: s.id,
          userId: s.authorId,
          userName: s.authorName ?? 'User',
          userAvatar: s.authorPhotoUrl,
          mediaType: s.type,
          mediaUrl: s.mediaUrl,
          thumbnailUrl: s.mediaThumbUrl,
          durationSec: s.durationSeconds ?? 5,
          createdAt: s.createdAt,
          expiresAt: s.expiresAt,
          viewed: s.viewed,
          viewsCount: s.viewCount,
          liked: false,
          likesCount: 0,
          commentsCount: 0,
          viewerIds: const [],
          mentionedUserIds: const [],
        )).toList(),
      );
    }).toList();
  }

  /// Sort story rings: Your Story | Unseen | All Seen
  List<StoryRingModel> _sortStoryRings(List<StoryRingModel> rings) {
    if (_currentUserId == null) return rings;
    
    final myRingIndex = rings.indexWhere((r) => r.userId == _currentUserId);
    StoryRingModel? myRing;
    
    if (myRingIndex >= 0) {
      myRing = rings.removeAt(myRingIndex);
    } else {
      myRing = StoryRingModel(
        userId: _currentUserId!,
        userName: '',
        userAvatar: null,
        hasUnseen: false,
        lastStoryAt: DateTime.now(),
        thumbnailUrl: null,
        storyCount: 0,
        stories: const [],
      );
    }
    
    final unseenRings = rings.where((r) => r.hasUnseen).toList();
    final seenRings = rings.where((r) => !r.hasUnseen).toList();
    return [myRing, ...unseenRings, ...seenRings];
  }

  /// Sort story rings with async fetch for user's own stories
  Future<List<StoryRingModel>> _sortStoryRingsAsync(List<StoryRingModel> rings, StoryRepository storyRepo) async {
    if (_currentUserId == null) return rings;
    
    final myRingIndex = rings.indexWhere((r) => r.userId == _currentUserId);
    StoryRingModel? myRing;
    
    if (myRingIndex >= 0) {
      myRing = rings.removeAt(myRingIndex);
    } else {
      // User's ring not in list - fetch their stories directly
      try {
        final myStories = await storyRepo.getUserStories(_currentUserId!);
        myRing = StoryRingModel(
          userId: _currentUserId!,
          userName: '',
          userAvatar: null,
          hasUnseen: false,
          lastStoryAt: myStories.isNotEmpty ? myStories.first.createdAt : DateTime.now(),
          thumbnailUrl: myStories.isNotEmpty ? myStories.first.mediaUrl : null,
          storyCount: myStories.length,
          stories: myStories,
        );
      } catch (_) {
        myRing = StoryRingModel(
          userId: _currentUserId!,
          userName: '',
          userAvatar: null,
          hasUnseen: false,
          lastStoryAt: DateTime.now(),
          thumbnailUrl: null,
          storyCount: 0,
          stories: const [],
        );
      }
    }
    
    final unseenRings = rings.where((r) => r.hasUnseen).toList();
    final seenRings = rings.where((r) => !r.hasUnseen).toList();
    return [myRing, ...unseenRings, ...seenRings];
  }

  /// BACKGROUND: Hydrate reposts without blocking first paint
  Future<void> _hydrateRepostsInBackground() async {
    if (_posts.isEmpty) return;
    
    // Find posts that need hydration (reposts with originalPostId)
    final needsHydration = _posts.where((p) => 
      p.isRepost && p.originalPostId != null && p.originalPostId!.isNotEmpty
    ).toList();
    
    if (needsHydration.isEmpty) return;
    
    debugPrint('💧 [FastFeed] Hydrating ${needsHydration.length} reposts in background...');
    
    // Hydrate each repost and update UI incrementally
    for (final repost in needsHydration) {
      try {
        final m = await _postRepo.getPost(repost.originalPostId!);
        if (m == null || !mounted) continue;
        
        // Use fast conversion for original post (no N+1 queries)
        final og = _toPostFast(m);
        
        // Update the repost with original content
        setState(() {
          _posts = _posts.map((p) {
            if (p.id == repost.id) {
              return p.copyWith(
                authorId: og.authorId,
                userName: og.userName,
                userAvatarUrl: og.userAvatarUrl,
                text: og.text,
                mediaType: og.mediaType,
                imageUrls: og.imageUrls,
                videoUrl: og.videoUrl,
                counts: og.counts,
              );
            }
            return p;
          }).toList();
        });
      } catch (_) {
        // Skip failed hydrations
      }
    }
    debugPrint('💧 [FastFeed] Repost hydration complete');
  }

  // Cache for hydrated original posts (used for reposts)
  final Map<String, PostModel> _hydratedOriginalPosts = {};
  final Map<String, Map<String, String>> _authorProfilesCache = {};

  /// SYNC: Hydrate ALL author data before displaying (prevents "User" flash)
  /// Handles both regular posts AND fetches original posts for reposts
  Future<List<PostModel>> _hydrateAllAuthorData(List<PostModel> models) async {
    final userRepo = FirebaseUserRepository();
    
    // Collect ALL author IDs we need (post authors + repost original authors)
    final authorIds = <String>{};
    final repostOriginalIds = <String>{};
    
    for (final m in models) {
      // Always add the post author
      if (m.authorName == null || m.authorName!.isEmpty || m.authorName == 'User') {
        authorIds.add(m.authorId);
      }
      // Track reposts that need original post fetched
      if (m.repostOf != null && m.repostOf!.isNotEmpty) {
        repostOriginalIds.add(m.repostOf!);
      }
    }
    
    // Fetch original posts for reposts (to get their author IDs)
    if (repostOriginalIds.isNotEmpty) {
      await Future.wait(repostOriginalIds.map((postId) async {
        if (_hydratedOriginalPosts.containsKey(postId)) return;
        try {
          final original = await _postRepo.getPost(postId);
          if (original != null) {
            _hydratedOriginalPosts[postId] = original;
            // Add original author to fetch list if missing
            if (original.authorName == null || original.authorName!.isEmpty || original.authorName == 'User') {
              authorIds.add(original.authorId);
            }
          }
        } catch (_) {}
      }));
    }
    
    // Fetch ALL author profiles in parallel
    if (authorIds.isNotEmpty) {
      debugPrint('💧 [FastFeed] Hydrating ${authorIds.length} authors before display...');
      await Future.wait(authorIds.map((authorId) async {
        if (_authorProfilesCache.containsKey(authorId)) return;
        try {
          final profile = await userRepo.getUserProfile(authorId);
          if (profile != null) {
            final fn = profile.firstName?.trim() ?? '';
            final ln = profile.lastName?.trim() ?? '';
            final fullName = (fn.isNotEmpty || ln.isNotEmpty)
                ? '$fn $ln'.trim()
                : (profile.displayName ?? profile.username ?? 'User');
            _authorProfilesCache[authorId] = {
              'name': fullName,
              'avatarUrl': profile.avatarUrl ?? '',
            };
          }
        } catch (_) {}
      }));
    }
    
    // Update models with fetched data
    return models.map((m) {
      var updated = m;
      
      // Update post author if needed
      if ((m.authorName == null || m.authorName!.isEmpty || m.authorName == 'User') && 
          _authorProfilesCache.containsKey(m.authorId)) {
        final profile = _authorProfilesCache[m.authorId]!;
        updated = updated.copyWith(
          authorName: profile['name'],
          authorAvatarUrl: profile['avatarUrl'],
        );
      }
      
      return updated;
    }).toList();
  }

  /// BACKGROUND: Hydrate missing author names without blocking first paint
  Future<void> _hydrateAuthorNamesInBackground() async {
    if (_posts.isEmpty) return;
    
    // Find posts with missing author names (showing "User")
    final needsHydration = _posts.where((p) => 
      p.userName == 'User' || p.userName.isEmpty
    ).toList();
    
    if (needsHydration.isEmpty) return;
    
    debugPrint('💧 [FastFeed] Hydrating ${needsHydration.length} author names in background...');
    
    // Batch fetch unique author IDs
    final authorIds = needsHydration.map((p) => p.authorId).toSet().toList();
    final authorProfiles = <String, Map<String, String>>{};
    
    final userRepo = FirebaseUserRepository();
    for (final authorId in authorIds) {
      try {
        final profile = await userRepo.getUserProfile(authorId);
        if (profile != null) {
          final fn = profile.firstName?.trim() ?? '';
          final ln = profile.lastName?.trim() ?? '';
          final fullName = (fn.isNotEmpty || ln.isNotEmpty)
              ? '$fn $ln'.trim()
              : (profile.displayName ?? profile.username ?? 'User');
          authorProfiles[authorId] = {
            'name': fullName,
            'avatarUrl': profile.avatarUrl ?? '',
          };
        }
      } catch (_) {
        // Skip failed lookups
      }
    }
    
    if (authorProfiles.isEmpty || !mounted) return;
    
    // Update posts with fetched author names
    setState(() {
      _posts = _posts.map((p) {
        if ((p.userName == 'User' || p.userName.isEmpty) && authorProfiles.containsKey(p.authorId)) {
          final profile = authorProfiles[p.authorId]!;
          return p.copyWith(
            userName: profile['name'],
            userAvatarUrl: profile['avatarUrl'],
          );
        }
        return p;
      }).toList();
    });
    
    debugPrint('💧 [FastFeed] Author name hydration complete');
  }

  // Legacy _loadData kept for refresh functionality
  Future<void> _loadData() async {
    await _loadFreshPosts();
    _loadStoriesInBackground();
  }

  // Prefetched posts ready to display instantly
  List<Post> _prefetchedPosts = [];
  bool _isPrefetching = false;

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _lastPost == null) return;

    // If we have prefetched posts, use them instantly
    if (_prefetchedPosts.isNotEmpty) {
      setState(() {
        _posts.addAll(_prefetchedPosts);
        _prefetchedPosts = [];
      });
      // Prefetch next batch in background
      _prefetchNextBatch();
      return;
    }

    setState(() => _isLoadingMore = true);
    PerformanceMonitor().startFeedPagination();

    try {
      final models = await _postRepo.getFeed(
        limit: _postsPerPage,
        lastPost: _lastPost,
      );

      if (models.isEmpty) {
        if (!mounted) return;
        setState(() {
          _hasMorePosts = false;
          _isLoadingMore = false;
        });
        return;
      }

      _lastPost = models.last;
      _hasMorePosts = models.length == _postsPerPage;

      // FAST sync conversion - render immediately
      var newPosts = _mapModelsToPostsFast(models);
      newPosts = _applyFeedFilters(newPosts);

      if (!mounted) return;
      setState(() {
        _posts.addAll(newPosts);
        _isLoadingMore = false;
      });
      PerformanceMonitor().stopFeedPagination(postCount: newPosts.length);
      
      // Load like/bookmark status for new posts
      _loadUserInteractionsInBackground(newPosts);
      
      // Prefetch next batch + hydrate reposts + author names in background
      _prefetchNextBatch();
      _hydrateRepostsInBackground();
      _hydrateAuthorNamesInBackground();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      PerformanceMonitor().stopFeedPagination(postCount: 0);
    }
  }

  /// Prefetch next page in background so it's ready instantly when user scrolls
  Future<void> _prefetchNextBatch() async {
    if (_isPrefetching || !_hasMorePosts || _lastPost == null) return;
    _isPrefetching = true;
    
    try {
      final models = await _postRepo.getFeed(
        limit: _postsPerPage,
        lastPost: _lastPost,
      );
      
      if (models.isEmpty) {
        _hasMorePosts = false;
      } else {
        _lastPost = models.last;
        _hasMorePosts = models.length == _postsPerPage;
        _prefetchedPosts = _applyFeedFilters(_mapModelsToPostsFast(models));
      }
    } catch (_) {
      // Prefetch failed - will load on demand
    }
    _isPrefetching = false;
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final userRepo = FirebaseUserRepository();
      final models = await userRepo.getSuggestedUsers(limit: 12);
      if (!mounted) return;
      setState(() {
        _suggestedUsers = models
            .where((u) => u.uid != (_currentUserId ?? ''))
            .map((u) {
              // Build full name
              final fn = u.firstName?.trim() ?? '';
              final ln = u.lastName?.trim() ?? '';
              final fullName = (fn.isNotEmpty || ln.isNotEmpty)
                  ? '$fn $ln'.trim()
                  : (u.displayName ?? u.username ?? 'User');
              
              return {
                'id': u.uid,
                'name': fullName,
                'username': u.username,
                'profile_photo_url': u.avatarUrl,
                'bio': u.bio,
              };
            })
            .toList();
      });
    } catch (_) {
      // ignore suggestions errors
    }
  }



  /// FAST synchronous conversion using denormalized data
  /// No async calls - uses authorName, authorAvatarUrl, mediaThumbs from post document
  List<Post> _mapModelsToPostsFast(List<PostModel> models) {
    return models.map((m) => _toPostFast(m)).toList();
  }

  /// Convert PostModel to Post synchronously using denormalized data
  /// Falls back to authorId if denormalized data is missing
  /// For reposts, uses cached original post data
  Post _toPostFast(PostModel m) {
    // For reposts, use the original post's data
    if (m.repostOf != null && m.repostOf!.isNotEmpty && _hydratedOriginalPosts.containsKey(m.repostOf)) {
      final original = _hydratedOriginalPosts[m.repostOf]!;
      
      // Get original author name from cache or original post
      String origAuthorName = original.authorName ?? 'User';
      String origAuthorAvatarUrl = original.authorAvatarUrl ?? '';
      
      if ((origAuthorName == 'User' || origAuthorName.isEmpty) && _authorProfilesCache.containsKey(original.authorId)) {
        final profile = _authorProfilesCache[original.authorId]!;
        origAuthorName = profile['name'] ?? 'User';
        origAuthorAvatarUrl = profile['avatarUrl'] ?? '';
      }
      
      // Get reposter name from cache
      String reposterName = m.authorName ?? 'User';
      String reposterAvatarUrl = m.authorAvatarUrl ?? '';
      if ((reposterName == 'User' || reposterName.isEmpty) && _authorProfilesCache.containsKey(m.authorId)) {
        final profile = _authorProfilesCache[m.authorId]!;
        reposterName = profile['name'] ?? 'User';
        reposterAvatarUrl = profile['avatarUrl'] ?? '';
      }
      
      // Build the repost with original content
      return _buildRepostFromOriginal(m, original, origAuthorName, origAuthorAvatarUrl, reposterName, reposterAvatarUrl);
    }
    
    // Regular post - use denormalized author data (no user query needed)
    String authorName = m.authorName ?? 'User';
    String authorAvatarUrl = m.authorAvatarUrl ?? '';
    
    // Check cache for author data
    if ((authorName == 'User' || authorName.isEmpty) && _authorProfilesCache.containsKey(m.authorId)) {
      final profile = _authorProfilesCache[m.authorId]!;
      authorName = profile['name'] ?? 'User';
      authorAvatarUrl = profile['avatarUrl'] ?? '';
    }
    
    // Determine media type from mediaThumbs or mediaUrls
    MediaType mediaType;
    String? videoUrl;
    List<String> imageUrls;
    
    // Helper to detect video URLs (handles Firebase Storage URLs with query params)
    bool isVideoUrl(String url) {
      final l = url.toLowerCase();
      // Check for video extensions (before query params)
      if (l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') || 
          l.contains('.avi') || l.contains('.mkv') || l.contains('.m4v') ||
          l.contains('.wmv') || l.contains('.flv') || l.contains('.3gp') ||
          l.contains('.3g2') || l.contains('.ogv') || l.contains('.ts')) {
        return true;
      }
      // Check for video path patterns in Firebase Storage URLs
      if (l.contains('/videos/') || l.contains('video_') || l.contains('video%2f')) {
        return true;
      }
      return false;
    }
    
    if (m.mediaThumbs.isNotEmpty) {
      // Use mediaThumbs for images (preferred - small thumbnails for fast feed)
      // But use full mediaUrls for video playback
      final hasVideo = m.mediaThumbs.any((t) => t.type == 'video');
      if (hasVideo) {
        mediaType = MediaType.video;
        // Use full video URL for playback, not thumbnail
        videoUrl = m.mediaUrls.firstWhere(
          (u) => isVideoUrl(u),
          orElse: () => m.mediaUrls.isNotEmpty ? m.mediaUrls.first : '',
        );
        imageUrls = [];
      } else {
        mediaType = m.mediaThumbs.length == 1 ? MediaType.image : MediaType.images;
        videoUrl = null;
        // Use thumbnails for images in feed (fast loading)
        imageUrls = m.mediaThumbs.map((t) => t.thumbUrl).toList();
      }
    } else if (m.mediaUrls.isNotEmpty) {
      // Fallback to mediaUrls (legacy posts without mediaThumbs)
      final hasVideo = m.mediaUrls.any((u) => isVideoUrl(u));
      
      if (hasVideo) {
        mediaType = MediaType.video;
        videoUrl = m.mediaUrls.firstWhere(
          (u) => isVideoUrl(u),
          orElse: () => m.mediaUrls.first,
        );
        imageUrls = [];
      } else {
        mediaType = m.mediaUrls.length == 1 ? MediaType.image : MediaType.images;
        videoUrl = null;
        imageUrls = m.mediaUrls;
      }
    } else {
      mediaType = MediaType.none;
      videoUrl = null;
      imageUrls = [];
    }
    
    int clamp(int v) => v < 0 ? 0 : v;
    
    // Build repostedBy if this is a repost
    RepostedBy? repostedBy;
    if (m.repostOf != null && m.repostOf!.isNotEmpty) {
      repostedBy = RepostedBy(
        userId: m.authorId,
        userName: authorName,
        userAvatarUrl: authorAvatarUrl,
        actionType: 'reposted this',
      );
    }
    
    // Convert tagged users from PostModel to Post format
    final taggedUsers = m.taggedUsers.map((t) => TaggedUser(
      id: t.id,
      name: t.name,
      avatarUrl: t.avatarUrl,
    )).toList();
    
    return Post(
      id: m.id,
      authorId: m.authorId,
      userName: authorName,
      userAvatarUrl: authorAvatarUrl,
      createdAt: m.createdAt,
      text: m.text,
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: clamp(m.summary.likes),
        comments: clamp(m.summary.comments),
        shares: clamp(m.summary.shares),
        reposts: clamp(m.summary.reposts),
        bookmarks: clamp(m.summary.bookmarks),
      ),
      userReaction: null, // Will be checked lazily or on interaction
      isBookmarked: false, // Will be checked lazily or on interaction
      isRepost: (m.repostOf != null && m.repostOf!.isNotEmpty),
      repostedBy: repostedBy,
      originalPostId: m.repostOf,
      taggedUsers: taggedUsers,
    );
  }

  /// Build a Post from a repost using the original post's content
  Post _buildRepostFromOriginal(
    PostModel repost, 
    PostModel original, 
    String origAuthorName, 
    String origAuthorAvatarUrl,
    String reposterName,
    String reposterAvatarUrl,
  ) {
    // Determine media type from original post
    MediaType mediaType;
    String? videoUrl;
    List<String> imageUrls;
    
    // Helper to detect video URLs (handles Firebase Storage URLs with query params)
    bool isVideoUrl(String url) {
      final l = url.toLowerCase();
      if (l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') || 
          l.contains('.avi') || l.contains('.mkv') || l.contains('.m4v') ||
          l.contains('.wmv') || l.contains('.flv') || l.contains('.3gp') ||
          l.contains('.3g2') || l.contains('.ogv') || l.contains('.ts')) {
        return true;
      }
      if (l.contains('/videos/') || l.contains('video_') || l.contains('video%2f')) {
        return true;
      }
      return false;
    }
    
    if (original.mediaThumbs.isNotEmpty) {
      final hasVideo = original.mediaThumbs.any((t) => t.type == 'video');
      if (hasVideo) {
        mediaType = MediaType.video;
        videoUrl = original.mediaUrls.firstWhere(
          (u) => isVideoUrl(u),
          orElse: () => original.mediaUrls.isNotEmpty ? original.mediaUrls.first : '',
        );
        imageUrls = [];
      } else {
        mediaType = original.mediaThumbs.length == 1 ? MediaType.image : MediaType.images;
        videoUrl = null;
        imageUrls = original.mediaThumbs.map((t) => t.thumbUrl).toList();
      }
    } else if (original.mediaUrls.isNotEmpty) {
      final hasVideo = original.mediaUrls.any((u) => isVideoUrl(u));
      if (hasVideo) {
        mediaType = MediaType.video;
        videoUrl = original.mediaUrls.firstWhere(
          (u) => isVideoUrl(u),
          orElse: () => original.mediaUrls.first,
        );
        imageUrls = [];
      } else {
        mediaType = original.mediaUrls.length == 1 ? MediaType.image : MediaType.images;
        videoUrl = null;
        imageUrls = original.mediaUrls;
      }
    } else {
      mediaType = MediaType.none;
      videoUrl = null;
      imageUrls = [];
    }
    
    int clamp(int v) => v < 0 ? 0 : v;
    
    // Convert tagged users from original post
    final taggedUsers = original.taggedUsers.map((t) => TaggedUser(
      id: t.id,
      name: t.name,
      avatarUrl: t.avatarUrl,
    )).toList();
    
    return Post(
      id: repost.id,
      authorId: original.authorId,
      userName: origAuthorName,
      userAvatarUrl: origAuthorAvatarUrl,
      createdAt: repost.createdAt,
      text: original.text,
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: clamp(original.summary.likes),
        comments: clamp(original.summary.comments),
        shares: clamp(original.summary.shares),
        reposts: clamp(original.summary.reposts),
        bookmarks: clamp(original.summary.bookmarks),
      ),
      userReaction: null,
      isBookmarked: false,
      isRepost: true,
      repostedBy: RepostedBy(
        userId: repost.authorId,
        userName: reposterName,
        userAvatarUrl: reposterAvatarUrl,
        actionType: 'reposted this',
      ),
      originalPostId: repost.repostOf,
      taggedUsers: taggedUsers,
    );
  }

  String _toError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final reason = (data['error'] ?? data['message'] ?? data).toString();
        return 'HTTP ${code ?? 'error'}: $reason';
      }
      return 'HTTP ${code ?? 'error'}';
    }
    return e.toString();
  }

  // === FEED FILTERING HELPERS (hashtags + preference logic) ===
  String _normTag(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<String> _extractTags(String text) {
    final re = RegExp(r'#([A-Za-z0-9_]+)');
    return re
        .allMatches(text)
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .map(_normTag)
        .toList();
  }

  List<String> _normInterests(List<String> list) =>
      list.map((s) => _normTag(s)).toList();

  List<Post> _applyFeedFilters(List<Post> items) {
    if (items.isEmpty) return items;
    final interestTokens = _normInterests(_myInterests);

    // If the dataset has no hashtags at all, don't apply hashtag-based filters
    final datasetHasTags = items.any((p) => _extractTags(p.text).isNotEmpty);

    return items.where((p) {
      // Filter out posts still uploading (have placeholder URLs)
      final hasPlaceholderImages = p.imageUrls.any((url) => url.startsWith('uploading_'));
      final hasPlaceholderVideo = p.videoUrl != null && p.videoUrl!.startsWith('uploading_');
      if (hasPlaceholderImages || hasPlaceholderVideo) return false;
      
      // Filter out blocked users
      if (_blockedUserIds.contains(p.authorId)) return false;
      
      // Repost visibility
      if (!_prefShowReposts && p.isRepost) return false;

      if (!datasetHasTags) return true;

      // Hashtags in text (already hydrated to original content if repost)
      final tags = _extractTags(p.text);
      final hasAnyHashtag = tags.isNotEmpty;
      final matchesInterest = interestTokens.isNotEmpty &&
          tags.any((t) => interestTokens.contains(t));

      // Only enforce interest if user actually has interests set
      final enforceInterest =
          _prefPrioritizeInterests && interestTokens.isNotEmpty;
      final enforceSuggested = _prefShowSuggested;

      // No hashtag filters requested
      if (!enforceInterest && !enforceSuggested) return true;

      if (enforceInterest && enforceSuggested) {
        // Interest OR any hashtag
        return matchesInterest || hasAnyHashtag;
      } else if (enforceInterest) {
        // Only interest matches
        return matchesInterest;
      } else {
        // Only "suggested" (any hashtag)
        return hasAnyHashtag;
      }
    }).toList();
  }

  void _onNavTabChange(int index) {
    setState(() {
      _selectedNavIndex = index;
      if (index != 3) {
        _conversationsInitialTabIndex = 0;
      }
    });

    if (index == 2) {
      () async {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(settings: const RouteSettings(name: 'create_post'), builder: (context) => const CreatePostPage()),
        );
        if (created == true) {
          await _loadData();
        }
      }();
    } else if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(settings: const RouteSettings(name: 'video_scroll'), builder: (context) => const VideoScrollPage()),
      );
    }
  }

  // Helpers for updating all feed entries tied to the same original post
  List<int> _indexesForOriginal(String originalId) {
    final idxs = <int>[];
    for (int i = 0; i < _posts.length; i++) {
      final p = _posts[i];
      if (p.id == originalId || p.originalPostId == originalId) {
        idxs.add(i);
      }
    }
    return idxs;
  }

  Post? _baseForOriginal(String originalId) {
    final direct = _posts.where((p) => p.id == originalId).toList();
    if (direct.isNotEmpty) return direct.first;
    final viaRepost =
        _posts.where((p) => p.originalPostId == originalId).toList();
    if (viaRepost.isNotEmpty) return viaRepost.first;
    return null;
  }

  void _applyToOriginal(String originalId,
      {required PostCounts counts,
      ReactionType? userReaction,
      bool? isBookmarked}) {
    final idxs = _indexesForOriginal(originalId);
    for (final i in idxs) {
      final p = _posts[i];
      _posts[i] = p.copyWith(
        counts: counts,
        userReaction: userReaction ?? p.userReaction,
        isBookmarked: isBookmarked ?? p.isBookmarked,
      );
    }
  }

  void _onBookmarkToggle(String originalId) async {
    final base = _baseForOriginal(originalId);
    if (base == null) return;

    final willBookmark = !base.isBookmarked;
    final newBookmarks =
        (base.counts.bookmarks + (willBookmark ? 1 : -1)).clamp(0, 1 << 30);

    final updatedCounts = PostCounts(
      likes: base.counts.likes,
      comments: base.counts.comments,
      shares: base.counts.shares,
      reposts: base.counts.reposts,
      bookmarks: newBookmarks,
    );

    final prevPosts = List<Post>.from(_posts);
    setState(() {
      _applyToOriginal(originalId,
          counts: updatedCounts, isBookmarked: willBookmark);
    });

    try {
      if (willBookmark) {
        await _postRepo.bookmarkPost(originalId);
        // Save to bookmarks collection
        if (!mounted) return;
        final bookmarkRepo = context.read<BookmarkRepository>();
        await bookmarkRepo.bookmarkPost(
          postId: originalId,
          title: base.text.length > 100 ? base.text.substring(0, 100) : base.text,
          authorName: base.userName,
          coverUrl: base.imageUrls.isNotEmpty ? base.imageUrls.first : null,
        );
      } else {
        await _postRepo.unbookmarkPost(originalId);
        // Remove from bookmarks collection
        if (!mounted) return;
        final bookmarkRepo = context.read<BookmarkRepository>();
        await bookmarkRepo.removeBookmarkByItem(originalId, BookmarkType.post);
      }
      // Emit for PostPage listeners
      PostEvents.emit(PostUpdateEvent(
        originalPostId: originalId,
        counts: updatedCounts,
        userReaction: base.userReaction,
        isBookmarked: willBookmark,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = prevPosts;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.bookmark_failed')}: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onReactionChanged(String originalId, ReactionType reaction) async {
    final base = _baseForOriginal(originalId);
    if (base == null) return;

    final hadReaction = base.userReaction != null;
    final isSameReaction = base.userReaction == reaction;

    final prevPosts = List<Post>.from(_posts);

    if (!hadReaction) {
      final updatedCounts = PostCounts(
        likes: base.counts.likes + 1,
        comments: base.counts.comments,
        shares: base.counts.shares,
        reposts: base.counts.reposts,
        bookmarks: base.counts.bookmarks,
      );
      setState(() {
        _applyToOriginal(originalId,
            counts: updatedCounts, userReaction: reaction);
      });
      try {
        await _postRepo.likePost(originalId);
        PostEvents.emit(PostUpdateEvent(
          originalPostId: originalId,
          counts: updatedCounts,
          userReaction: reaction,
          isBookmarked: base.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _posts = prevPosts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.like_failed')}: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (isSameReaction) {
      final newLikes = (base.counts.likes > 0 ? base.counts.likes - 1 : 0);
      final updatedCounts = PostCounts(
        likes: newLikes,
        comments: base.counts.comments,
        shares: base.counts.shares,
        reposts: base.counts.reposts,
        bookmarks: base.counts.bookmarks,
      );

      setState(() {
        _applyToOriginal(originalId, counts: updatedCounts, userReaction: null);
      });

      try {
        await _postRepo.unlikePost(originalId);
        PostEvents.emit(PostUpdateEvent(
          originalPostId: originalId,
          counts: updatedCounts,
          userReaction: null,
          isBookmarked: base.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _posts = prevPosts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.unlike_failed')}: ${_toError(e)}',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Different reaction but still a "like" concept: update icon only (no extra like API)
    setState(() {
      _applyToOriginal(originalId, counts: base.counts, userReaction: reaction);
    });
  }

  void _onShare(String originalId) {
    ShareBottomSheet.show(
      context,
      onStories: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.shared_stories'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
      onCopyLink: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.link_copied'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF9E9E9E),
          ),
        );
      },
      onTelegram: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.shared_telegram'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF0088CC),
          ),
        );
      },
      onFacebook: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.shared_facebook'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      },
      onMore: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.more_share'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      onSendToUsers: (selectedUsers, message) {
        final userNames = selectedUsers.map((user) => user.name).join(', ');
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.t('community.sent_to')}$userNames${message.isNotEmpty ? '${lang.t('community.with_message')}$message"' : ''}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFFBFAE01),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<List<Comment>> _loadCommentsForPost(String postId) async {
    final list = await _commentRepo.getComments(postId: postId, limit: 200);
    final uids = list.map((m) => m.authorId).toSet().toList();
    final profiles = await _userRepo.getUsers(uids);
    final byId = {for (final p in profiles) p.uid: p};
    
    // Check which comments the user has liked
    final likedCommentIds = <String>{};
    for (final m in list) {
      final isLiked = await _commentRepo.hasUserLikedComment(m.id);
      if (isLiked) likedCommentIds.add(m.id);
    }
    
    final allComments = list.map((m) {
      final u = byId[m.authorId];
      // Build full name for comment author
      final commentFirstName = u?.firstName?.trim() ?? '';
      final commentLastName = u?.lastName?.trim() ?? '';
      final commentFullName = (commentFirstName.isNotEmpty || commentLastName.isNotEmpty)
          ? '$commentFirstName $commentLastName'.trim()
          : (u?.displayName ?? u?.username ?? 'User');
      
      return Comment(
        id: m.id,
        userId: m.authorId,
        userName: commentFullName,
        userAvatarUrl: (u?.avatarUrl ?? ''),
        text: m.text,
        createdAt: m.createdAt,
        likesCount: m.likesCount,
        isLikedByUser: likedCommentIds.contains(m.id),
        replies: const [],
        parentCommentId: m.parentCommentId,
      );
    }).toList();
    
    // Build tree structure
    return _buildCommentTree(allComments);
  }
  
  List<Comment> _buildCommentTree(List<Comment> allComments) {
    final List<Comment> topLevelComments = [];
    final Map<String, List<Comment>> repliesMap = {};
    
    for (final comment in allComments) {
      if (comment.parentCommentId == null || comment.parentCommentId!.isEmpty) {
        topLevelComments.add(comment);
      } else {
        repliesMap.putIfAbsent(comment.parentCommentId!, () => []).add(comment);
      }
    }
    
    Comment attachReplies(Comment comment) {
      final replies = repliesMap[comment.id] ?? [];
      if (replies.isEmpty) return comment;
      final nestedReplies = replies.map((r) => attachReplies(r)).toList();
      nestedReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comment.copyWith(replies: nestedReplies);
    }
    
    final result = topLevelComments.map((c) => attachReplies(c)).toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  Future<void> _openCommentsSheet(String originalId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show bottom sheet INSTANTLY with empty comments (will load inside)
    if (!mounted) return;

    CommentBottomSheet.show(
      context,
      postId: originalId,
      comments: const [], // Empty - will load inside the sheet
      currentUserId: _currentUserId ?? '',
      isDarkMode: isDark,
      onAddComment: (text) async {
        try {
          await _commentRepo.createComment(postId: originalId, text: text);

          final base = _baseForOriginal(originalId);
          if (base != null) {
            final updatedCounts = PostCounts(
              likes: base.counts.likes,
              comments: base.counts.comments + 1,
              shares: base.counts.shares,
              reposts: base.counts.reposts,
              bookmarks: base.counts.bookmarks,
            );
            setState(() {
              _applyToOriginal(originalId, counts: updatedCounts);
            });
            PostEvents.emit(PostUpdateEvent(
              originalPostId: originalId,
              counts: updatedCounts,
              userReaction: base.userReaction,
              isBookmarked: base.isBookmarked,
            ));
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.comment_posted'), style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.post_comment_failed')}: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onReplyToComment: (commentId, replyText) async {
        try {
          await _commentRepo.createComment(
              postId: originalId, text: replyText, parentCommentId: commentId);

          // Count reply as part of comments for the action row
          final base = _baseForOriginal(originalId);
          if (base != null) {
            final updatedCounts = PostCounts(
              likes: base.counts.likes,
              comments: base.counts.comments + 1,
              shares: base.counts.shares,
              reposts: base.counts.reposts,
              bookmarks: base.counts.bookmarks,
            );
            setState(() {
              _applyToOriginal(originalId, counts: updatedCounts);
            });
            PostEvents.emit(PostUpdateEvent(
              originalPostId: originalId,
              counts: updatedCounts,
              userReaction: base.userReaction,
              isBookmarked: base.isBookmarked,
            ));
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.reply_posted'), style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.reply_failed')}: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _onComment(String originalId) => _openCommentsSheet(originalId);

  void _onRepost(String originalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final lang = Provider.of<LanguageProvider>(ctx, listen: false);
        return AlertDialog(
          title: Text(lang.t('dialogs.repost.title'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Text(lang.t('dialogs.repost.message'),
              style: GoogleFonts.inter()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(lang.t('common.cancel'), style: GoogleFonts.inter()),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(lang.t('post.repost'),
                  style: GoogleFonts.inter(color: const Color(0xFFBFAE01))),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await _postRepo.repostPost(originalId);
      if (!mounted) return;
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(lang.t('messages.repost_success'), style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      await _loadData();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      final msg = _toError(e);

      final isAlreadyReposted = code == 409 ||
          (data is Map &&
              ((data['error'] ?? data['message'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('already')));

      if (isAlreadyReposted) {
        if (!mounted) return;
        final remove = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('dialogs.unrepost.title'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            content: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('dialogs.unrepost.message'),
                style: GoogleFonts.inter()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child:
                    Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.remove'), style: GoogleFonts.inter(color: Colors.red)),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (remove == true) {
          try {
            await _postRepo.unrepostPost(originalId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.unrepost_success'), style: GoogleFonts.inter()),
                backgroundColor: const Color(0xFF9E9E9E),
              ),
            );
            await _loadData();
          } catch (e2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.remove_repost_failed')}: ${_toError(e2)}',
                    style: GoogleFonts.inter()),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.repost_failed')}: $msg', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.repost_failed')}: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ----------------------------
  // BUILD
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor =
            isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

        // Responsive: desktop and largeDesktop → desktop layout; others → mobile
        if (kIsWeb && (context.isDesktop || context.isLargeDesktop)) {
          return _buildDesktopLayout(context, isDark, backgroundColor);
        }

        // Mobile/tablet: keep existing design
        return Scaffold(
          backgroundColor: backgroundColor,
          body: _selectedNavIndex == 1
              ? ConnectionsPage(isDarkMode: isDark, onThemeToggle: () {})
              : _selectedNavIndex == 3
                  ? ConversationsPage(
                      isDarkMode: isDark,
                      onThemeToggle: () {},
                      initialTabIndex: _conversationsInitialTabIndex,
                    )
                  : _selectedNavIndex == 4
                      ? const ProfilePage()
                      : _selectedNavIndex == 5
                          ? const VideoScrollPage()
                          : _buildHomeFeedMobile(
                              context, isDark, backgroundColor),
          bottomNavigationBar: AnimatedNavbar(
            selectedIndex: _selectedNavIndex,
            onTabChange: _onNavTabChange,
            isDarkMode: isDark,
          ),
          floatingActionButton:
              (_selectedNavIndex == 0 || _selectedNavIndex == 1)
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4C100), Color(0xFFBFAE01)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBFAE01).withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'toolsFabMain',
                        onPressed: _showToolsOverlay,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        foregroundColor: Colors.black,
                        child: const Icon(Icons.apps_rounded, size: 28),
                      ),
                    )
                  : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  void _showToolsOverlay() {
    ToolsOverlay.show(
      context,
      onCommunities: () {
        setState(() {
          _conversationsInitialTabIndex = 1;
          _selectedNavIndex = 3;
        });
      },
      onPodcasts: () {
        Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'podcasts_home'), builder: (_) => const PodcastsHomePage()));
      },
      onBooks: () {
        Navigator.push(
            context, MaterialPageRoute(settings: const RouteSettings(name: 'books_home'), builder: (_) => const BooksHomePage()));
      },
      onMentorship: () {
        Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'mentorship_home'), builder: (_) => const MentorshipHomePage()));
      },
      onVideos: () {
        Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'video_scroll'), builder: (_) => const VideoScrollPage()));
      },
      onLive: () {
        Navigator.push(context,
            MaterialPageRoute(settings: const RouteSettings(name: 'livestream_list'), builder: (_) => const LiveStreamListPage()));
      },
    );
  }

  // ===========================
  // Desktop (Web) Layout
  // ===========================
  Widget _buildDesktopLayout(
      BuildContext context, bool isDark, Color backgroundColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildDesktopTopNav(isDark),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: IndexedStack(
                        index: _desktopSectionIndex,
                        children: [
                          _buildDesktopColumns(isDark), // Home
                          ConnectionsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            hideDesktopTopNav: true,
                          ),
                          ConversationsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            initialTabIndex: _conversationsInitialTabIndex,
                            hideDesktopTopNav: true,
                          ),
                          const ProfilePage(hideDesktopTopNav: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_desktopSectionIndex == 0)
            Positioned(
              left: 24,
              bottom: 24,
              child: FloatingActionButton(
                heroTag: 'createPostFabWeb',
                onPressed: () async {
                  await CreatePostPage.showPopup<bool>(context);
                  // Refresh feed instantly after posting
                  await _loadData();
                },
                backgroundColor: const Color(0xFFBFAE01),
                foregroundColor: Colors.black,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
            floatingActionButton: (_desktopSectionIndex == 0 || _desktopSectionIndex == 1)
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4C100), Color(0xFFBFAE01)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBFAE01).withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'toolsFabWeb',
                onPressed: _showToolsOverlay,
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.black,
                child: const Icon(Icons.apps_rounded, size: 28),
              ),
            )
          : null,
    );
  }

  Widget _buildDesktopTopNav(bool isDark) {
    final barColor = isDark ? Colors.black : Colors.white;
    return Material(
      color: barColor,
      elevation: isDark ? 0 : 2,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.menu, color: const Color(0xFF666666)),
                  const Spacer(),
                  Text(
                    'NEXUM',
                    style: GoogleFonts.inika(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  BadgeIcon(
                    icon: Icons.notifications_outlined,
                    badgeCount: _unreadCount,
                    iconColor: const Color(0xFF666666),
                    onTap: () async {
                      final size = MediaQuery.of(context).size;
                      final desktop =
                          kIsWeb && size.width >= 1280 && size.height >= 800;
                      if (desktop) {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.black26,
                          builder: (_) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final double width = 420;
                            final double height = size.height * 0.8;
                            return SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, right: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: Material(
                                        color: isDark
                                            ? const Color(0xFF000000)
                                            : Colors.white,
                                        child: const NotificationPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              settings: const RouteSettings(name: 'notifications'),
                              builder: (_) => const NotificationPage()),
                        );
                      }
                      if (!mounted) return;
                      await _loadUnreadCount();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TopNavItem(
                    icon: Icons.home_outlined,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.home'),
                    selected: _desktopSectionIndex == 0,
                    onTap: () => setState(() => _desktopSectionIndex = 0),
                  ),
                  _TopNavItem(
                    icon: Icons.people_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.connections'),
                    selected: _desktopSectionIndex == 1,
                    onTap: () => setState(() => _desktopSectionIndex = 1),
                  ),
                  _TopNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.conversations'),
                    selected: _desktopSectionIndex == 2,
                    onTap: () => setState(() => _desktopSectionIndex = 2),
                  ),
                  _TopNavItem(
                    icon: Icons.person_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.profile'),
                    selected: _desktopSectionIndex == 3,
                    onTap: () => setState(() => _desktopSectionIndex = 3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopColumns(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Stories panel
        SizedBox(width: 240, child: _buildLeftStoriesPanel(isDark)),

        const SizedBox(width: 16),

        // Center: Feed
        Expanded(child: _buildCenterFeedPanel(isDark)),

        const SizedBox(width: 16),

        // Right: Suggestions panel
        SizedBox(width: 360, child: _buildRightSuggestionsPanel(isDark)),
      ],
    );
  }

  Widget _buildLeftStoriesPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Provider.of<LanguageProvider>(context).t('common.stories'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                )),
            const SizedBox(height: 12),
            // Vertical list of story rings
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _storyRings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ring = _storyRings[index];
                  final isMine = ring.userId == _currentUserId;

                  return Row(
                    children: [
                      story_widget.StoryRing(
                        imageUrl: ring.userAvatar,
                        label: isMine
                            ? Provider.of<LanguageProvider>(context, listen: false).t('feed.your_story')
                            : (ring.userName.isNotEmpty
                                ? ring.userName
                                : ring.stories.isNotEmpty
                                    ? ring.stories.first.userName
                                    : Provider.of<LanguageProvider>(context, listen: false).t('feed.user')),
                        isMine: isMine,
                        isSeen: !ring.hasUnseen,
                        hasActiveStories: isMine && ring.stories.isNotEmpty,
                        onAddTap: (isMine && ring.stories.isNotEmpty)
                            ? () {
                                StoryTypePicker.show(
                                  context,
                                  position: const Offset(320, 120),
                                  onSelected: (type) async {
                                    if (_useDesktopPopup(context)) {
                                      await StoryComposerPopup.show(context, type: type);
                                    } else {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          settings: const RouteSettings(name: 'story_composer'),
                                          builder: (_) => _composerPage(type),
                                        ),
                                      );
                                    }
                                  },
                                );
                              }
                            : null,
                        onTap: () async {
                          if (isMine) {
                            if (ring.stories.isNotEmpty && _currentUserId != null) {
                              // User has active stories - open story viewer
                              await StoryViewerPopup.show(
                                context,
                                rings: _storyRings
                                    .map((r) => {
                                          'userId': r.userId,
                                          'imageUrl': r.userAvatar,
                                          'label': r.userName,
                                          'isMine': r.userId == _currentUserId,
                                          'isSeen': !r.hasUnseen,
                                        })
                                    .toList(),
                                initialRingIndex: index,
                              );
                              await _loadData();
                            } else {
                              // No stories - show type picker as popup
                              StoryTypePicker.show(
                                context,
                                position: const Offset(320, 120),
                                onSelected: (type) async {
                                  if (_useDesktopPopup(context)) {
                                    await StoryComposerPopup.show(context, type: type);
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(name: 'story_composer'),
                                        builder: (_) => _composerPage(type),
                                      ),
                                    );
                                  }
                                },
                              );
                            }
                          } else {
                            if (_useDesktopPopup(context)) {
                              await StoryViewerPopup.show(
                                context,
                                rings: _storyRings
                                    .map((r) => {
                                          'userId': r.userId,
                                          'imageUrl': r.userAvatar,
                                          'label': r.userName,
                                          'isMine': r.userId == _currentUserId,
                                          'isSeen': !r.hasUnseen,
                                        })
                                    .toList(),
                                initialRingIndex: index,
                              );
                            } else {
                              await Navigator.push(
                                context,
                                TransparentRoute(
                                  builder: (_) => StoryViewerPage(
                                    rings: _storyRings
                                        .map((r) => {
                                              'userId': r.userId,
                                              'imageUrl': r.userAvatar,
                                              'label': r.userName,
                                              'isMine':
                                                  r.userId == _currentUserId,
                                              'isSeen': !r.hasUnseen,
                                            })
                                        .toList(),
                                    initialRingIndex: index,
                                  ),
                                ),
                              );
                            }
                            await _loadData();
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterFeedPanel(bool isDark) {
    // Show skeleton placeholders during initial load
    if (_isInitialLoading) {
      return Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: 3,
          itemBuilder: (context, index) => PostSkeleton(isDarkMode: isDark),
        ),
      );
    }
    
    // Calculate item count including loading and end indicators
    int itemCount = _posts.length;
    if (_isLoadingMore) itemCount++;
    if (!_hasMorePosts && _posts.isNotEmpty) itemCount++;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Show posts
          if (index < _posts.length) {
            return PostCard(
              post: _posts[index],
              onReactionChanged: _onReactionChanged,
              onBookmarkToggle: _onBookmarkToggle,
              onShare: _onShare,
              onComment: _onComment,
              onRepost: _onRepost,
              onTap: (postId) async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'post_detail'),
                    builder: (context) => PostPage(postId: postId),
                  ),
                );
                // Refresh feed after returning from post page
                await _loadData();
              },
              isDarkMode: isDark,
              currentUserId: _currentUserId,
            );
          }
          
          // Show loading indicator
          if (_isLoadingMore && index == _posts.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Provider.of<LanguageProvider>(context, listen: false).t('feed.loading_more'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Show end of feed indicator
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('feed.all_caught_up'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF999999),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightSuggestionsPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;

    List<Map<String, dynamic>> users = _suggestedUsers;
    if (users.isEmpty) {
      // Create a small placeholder list to avoid an empty panel
      users = List.generate(6, (i) {
        return {
          'id': 'user_$i',
          'name': 'User $i',
          'username': '@user$i',
          'bio': 'Hello Nexum',
          'avatarUrl': '',
          'coverUrl': '',
        };
      });
    }

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('feed.connections'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: const RouteSettings(name: 'connections'),
                          builder: (_) => ConnectionsPage(
                              isDarkMode: isDark, onThemeToggle: () {})),
                    );
                  },
                  child:
                      Text(Provider.of<LanguageProvider>(context).t('common.see_more'), style: GoogleFonts.inter(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Card rail
            SizedBox(
              height: 276, // fits ConnectionCard height + padding
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final u = users[i];
                  final uid = (u['id'] ?? '').toString();
                  final fullName = _pickFullName(u);
                  final username = _pickUsername(u);
                  final bio = (u['bio'] ?? '').toString();
                  final avatar = _pickAvatar(u);
                  final cover = _pickCover(u);
                  return ConnectionCard(
                    userId: uid,
                    coverUrl: cover,
                    avatarUrl: avatar,
                    fullName: fullName,
                    username: username,
                    bio: bio,
                    initialConnectionStatus: false,
                    theyConnectToYou: false,
                    onMessage: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'conversations'),
                          builder: (_) => ConversationsPage(
                              isDarkMode: isDark,
                              onThemeToggle: () {},
                              initialTabIndex: 0),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Spacer for visual balance (tools are via FAB bottom-right)
            Expanded(child: Container()),
          ],
        ),
      ),
    );
  }

  // Helpers to safely map user fields from /api/users/all
  String _pickFullName(Map u) {
    final name = (u['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final fn = (u['firstName'] ?? u['first_name'] ?? '').toString().trim();
    final ln = (u['lastName'] ?? u['last_name'] ?? '').toString().trim();
    final both = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
    if (both.isNotEmpty) return both;
    final username = _pickUsername(u);
    if (username.isNotEmpty) return username.replaceFirst('@', '');
    final email = (u['email'] ?? '').toString();
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String _pickUsername(Map u) {
    final un = (u['username'] ?? u['userName'] ?? '').toString().trim();
    if (un.isNotEmpty) return un.startsWith('@') ? un : '@$un';
    final email = (u['email'] ?? '').toString();
    if (email.contains('@')) return '@${email.split('@').first}';
    return '@user';
  }

  String _pickAvatar(Map u) {
    return (u['avatarUrl'] ??
            u['avatar_url'] ??
            u['imageUrl'] ??
            u['image_url'] ??
            '')
        .toString();
  }

  String _pickCover(Map u) {
    final cover = (u['coverUrl'] ?? u['cover_url'] ?? '').toString();
    if (cover.isNotEmpty) return cover;
    // fallback to avatar to avoid empty image blocks
    return _pickAvatar(u);
  }

  // ===========================
  // Mobile layout (unchanged)
  // ===========================
  Widget _buildHomeFeedMobile(
    BuildContext context,
    bool isDark,
    Color backgroundColor,
  ) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFBFAE01),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          // No need to manage reaction picker with HomePostCard
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
          // App bar + stories as a scrollable sliver
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(25),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row with search, title, and notifications
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(name: 'search'),
                                  builder: (_) => const SearchPage(),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.search,
                              color: Color(0xFF666666),
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'NEXUM',
                                style: GoogleFonts.inika(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          BadgeIcon(
                            icon: Icons.notifications_outlined,
                            badgeCount: _unreadCount,
                            iconColor: const Color(0xFF666666),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(name: 'notifications'),
                                  builder: (_) => const NotificationPage(),
                                ),
                              );
                              await _loadUnreadCount();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stories row
                    SizedBox(
                      height: 110,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _storyRings.length,
                              itemBuilder: (context, index) {
                                final ring = _storyRings[index];
                                final isMine = ring.userId == _currentUserId;

                                return Container(
                                  width: 80,
                                  margin: EdgeInsets.only(
                                    right: index < _storyRings.length - 1 ? 12 : 0,
                                  ),
                                  child: story_widget.StoryRing(
                                    imageUrl: ring.userAvatar,
                                    label: isMine
                                        ? Provider.of<LanguageProvider>(context, listen: false).t('feed.your_story')
                                        : (ring.userName.isNotEmpty
                                            ? ring.userName
                                            : ring.stories.isNotEmpty
                                                ? ring.stories.first.userName
                                                : Provider.of<LanguageProvider>(context, listen: false).t('feed.user')),
                                    isMine: isMine,
                                    isSeen: !ring.hasUnseen,
                                    hasActiveStories: isMine && ring.stories.isNotEmpty,

                                    // Show + icon only when user has active stories
                                    onAddTap: (isMine && ring.stories.isNotEmpty) ? () {
                                      StoryTypePicker.show(
                                        context,
                                        position: const Offset(16, 120),
                                        onSelected: (type) async {
                                          if (_useDesktopPopup(context)) {
                                            await StoryComposerPopup.show(context, type: type);
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                settings: const RouteSettings(name: 'story_composer'),
                                                builder: (_) => _composerPage(type),
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    } : null,
                                    onTap: () async {
                                  if (isMine) {
                                    // Check if user has any ACTIVE stories (not expired)
                                    final now = DateTime.now();
                                    final activeStories = ring.stories.where((story) {
                                      final age = now.difference(story.createdAt);
                                      return age.inHours < 24; // Stories expire after 24 hours
                                    }).toList();
                                    
                                    if (activeStories.isNotEmpty && _currentUserId != null) {
                                      // User has active stories - open story viewer (like other users)
                                      if (_useDesktopPopup(context)) {
                                        await StoryViewerPopup.show(
                                          context,
                                          rings: _storyRings
                                              .map((r) => {
                                                    'userId': r.userId,
                                                    'imageUrl': r.userAvatar,
                                                    'label': r.userName,
                                                    'isMine': r.userId == _currentUserId,
                                                    'isSeen': !r.hasUnseen,
                                                  })
                                              .toList(),
                                          initialRingIndex: index,
                                        );
                                      } else {
                                        await Navigator.push(
                                          context,
                                          TransparentRoute(
                                            builder: (_) => StoryViewerPage(
                                              rings: _storyRings
                                                  .map((r) => {
                                                        'userId': r.userId,
                                                        'imageUrl': r.userAvatar,
                                                        'label': r.userName,
                                                        'isMine': r.userId == _currentUserId,
                                                        'isSeen': !r.hasUnseen,
                                                      })
                                                  .toList(),
                                              initialRingIndex: index,
                                            ),
                                          ),
                                        );
                                      }
                                      await _loadData(); // refresh rings after viewing
                                    } else {
                                      // No active stories - show type picker as popup near ring
                                      StoryTypePicker.show(
                                        context,
                                        position: const Offset(16, 120), // Position below "Your Story" ring
                                        onSelected: (type) async {
                                          if (_useDesktopPopup(context)) {
                                            await StoryComposerPopup.show(
                                                context,
                                                type: type);
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  settings: const RouteSettings(name: 'story_composer'),
                                                  builder: (_) =>
                                                      _composerPage(type)),
                                            );
                                          }
                                        },
                                      );
                                    }
                                  } else {
                                    if (_useDesktopPopup(context)) {
                                      await StoryViewerPopup.show(
                                        context,
                                        rings: _storyRings
                                            .map((r) => {
                                                  'userId': r.userId,
                                                  'imageUrl': r.userAvatar,
                                                  'label': r.userName,
                                                  'isMine': r.userId ==
                                                      _currentUserId,
                                                  'isSeen': !r.hasUnseen,
                                                })
                                            .toList(),
                                        initialRingIndex: index,
                                      );
                                    } else {
                                      await Navigator.push(
                                        context,
                                        TransparentRoute(
                                          builder: (_) => StoryViewerPage(
                                            rings: _storyRings
                                                .map((r) => {
                                                      'userId': r.userId,
                                                      'imageUrl': r.userAvatar,
                                                      'label': r.userName,
                                                      'isMine': r.userId ==
                                                          _currentUserId,
                                                      'isSeen': !r.hasUnseen,
                                                    })
                                                .toList(),
                                            initialRingIndex: index,
                                          ),
                                        ),
                                      );
                                    }
                                    await _loadData(); // refresh rings after viewing
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Show skeleton placeholders during initial load for perceived < 1s
          if (_isInitialLoading)
            SliverPadding(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => PostSkeleton(isDarkMode: isDark),
                  childCount: 3, // Show 3 skeleton cards
                ),
              ),
            )
          else
            // Feed as a sliver list so it scrolls together with the header
            SliverPadding(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return PostCard(
                    post: _posts[index],
                    onReactionChanged: _onReactionChanged,
                    onBookmarkToggle: _onBookmarkToggle,
                    onShare: _onShare,
                    onComment: _onComment,
                    onRepost: _onRepost,
                    onTap: (postId) async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'post_detail'),
                          builder: (_) => PostPage(postId: postId),
                        ),
                      );
                      // Refresh feed after returning from post page
                      await _loadData();
                    },
                    isDarkMode: isDark,
                    currentUserId: _currentUserId,
                  );
                }, childCount: _posts.length),
              ),
            ),

          // Loading indicator for pagination
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('feed.loading_more'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF666666),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // End of feed indicator
          if (!_hasMorePosts && _posts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('feed.all_caught_up'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  // Map story compose type to its page
  Widget _composerPage(StoryComposeType type) {
    switch (type) {
      case StoryComposeType.text:
        return const TextStoryComposerPage();
      case StoryComposeType.image:
      case StoryComposeType.video:
      case StoryComposeType.mixed:
        return const MixedMediaStoryComposerPage();
    }
  }
}

// Simple top navigation item used in desktop header
class _TopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TopNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFBFAE01) : const Color(0xFF666666);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 14, color: color, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }
}
