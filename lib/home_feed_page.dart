import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/story_ring.dart' as story_widget;
import 'widgets/post_card.dart';
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
import 'repositories/interfaces/user_repository.dart';
import 'repositories/models/post_model.dart';
import 'repositories/interfaces/story_repository.dart';
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
import 'widgets/my_stories_bottom_sheet.dart';
import 'podcasts/podcasts_home_page.dart';
import 'books/books_home_page.dart';
import 'mentorship/mentorship_home_page.dart';
import 'video_scroll_page.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'repositories/firebase/firebase_notification_repository.dart';
import 'repositories/interfaces/block_repository.dart';
import 'core/post_events.dart';
import 'core/profile_api.dart'; // Feed preferences
import 'responsive/responsive_breakpoints.dart';
import 'core/i18n/language_provider.dart';
import 'services/auth_service.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  int _selectedNavIndex = 0;
  List<Post> _posts = [];
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
  static const int _postsPerPage = 10;

  final FirebasePostRepository _postRepo = FirebasePostRepository();
  final FirebaseCommentRepository _commentRepo = FirebaseCommentRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    // Load critical data first, then load secondary data in parallel
    () async {
      // Load user ID first (required for everything else)
      await _loadCurrentUserId();
      
      // Load everything else in parallel
      await Future.wait([
        _loadBlockedUsers(),
        _loadFeedPrefs(),
        _loadUnreadCount(),
      ]);
      
      // Load feed data (depends on blocked users and prefs)
      await _loadData();
      
      // Load suggested users in background (not critical)
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

  Future<void> _loadData() async {
    List<Post> posts = [];
    // removed unused _myStoriesRing
    final storyRepo = context.read<StoryRepository>();
    List<StoryRingModel> rings = [];
    String? errMsg;

    // LOG CURRENT USER STATUS (critical for TestFlight debugging)
    debugPrint('🔐 =================================');
    debugPrint('🔐 HOME FEED LOADING DATA');
    debugPrint('🔐 Current User ID: ${_currentUserId ?? "NOT SET"}');
    debugPrint('🔐 Auth Service Logged In: ${AuthService().isLoggedIn}');
    debugPrint('🔐 Auth Service User ID: ${AuthService().userId ?? "NULL"}');
    debugPrint('🔐 =================================');

    try {
      debugPrint('📊 Fetching initial feed from Firestore...');
      final models = await _postRepo.getFeed(limit: _postsPerPage);
      debugPrint('📨 Fetched ${models.length} post models from Firebase');
      
      // Store last post for pagination
      if (models.isNotEmpty) {
        _lastPost = models.last;
        _hasMorePosts = models.length == _postsPerPage;
      } else {
        _hasMorePosts = false;
      }
      
      if (models.isEmpty) {
        debugPrint('⚠️ NO POSTS FOUND IN FIRESTORE - Check:');
        debugPrint('   1. Are there posts in the "posts" collection?');
        debugPrint('   2. Are Firestore rules allowing reads?');
        debugPrint('   3. Is App Check blocking requests?');
      }
      
      posts = await _mapModelsToPosts(models);
      debugPrint('📬 Mapped to ${posts.length} posts');
      final repostCount = posts.where((p) => p.isRepost).length;
      debugPrint('🔁 Found $repostCount reposts before hydration');
      posts = await _hydrateReposts(posts);
      debugPrint('💧 After hydration: ${posts.length} posts');
      posts = _applyFeedFilters(posts);
      debugPrint('🔍 After filters: ${posts.length} posts (reposts: ${posts.where((p) => p.isRepost).length})');
      debugPrint('📄 Has more posts: $_hasMorePosts');
    } catch (e, stackTrace) {
      errMsg = 'Posts failed: ${_toError(e)}';
      debugPrint('❌ CRITICAL ERROR LOADING POSTS:');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
    }

    try {
      rings = await storyRepo.getStoryRings();
    } catch (e) {
      final s = 'Stories failed: ${_toError(e)}';
      errMsg = errMsg == null ? s : '$errMsg | $s';
    }

    // Always put "Your Story" ring first, at the left
    if (_currentUserId != null) {
      // Find user's ring if it exists
      final myRingIndex = rings.indexWhere((r) => r.userId == _currentUserId);
      
      if (myRingIndex > 0) {
        // User has stories but not in first position - move to front
        final myRing = rings.removeAt(myRingIndex);
        rings.insert(0, myRing);
      } else if (myRingIndex == -1) {
        // User has no stories - add empty "Your Story" ring at front
        rings.insert(0, StoryRingModel(
          userId: _currentUserId!,
          userName: '',
          userAvatar: null,
          hasUnseen: false,
          lastStoryAt: DateTime.now(),
          thumbnailUrl: null,
          storyCount: 0,
          stories: const [],
        ));
      }
      // If myRingIndex == 0, it's already first - do nothing
    }

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _storyRings = rings;
      _isLoadingMore = false;
    });

    if (errMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg, style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _lastPost == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      debugPrint('📊 Loading more posts... (starting after: ${_lastPost!.id})');
      final models = await _postRepo.getFeed(
        limit: _postsPerPage,
        lastPost: _lastPost,
      );
      debugPrint('📨 Fetched ${models.length} more posts');

      if (models.isEmpty) {
        debugPrint('🏁 No more posts to load');
        if (!mounted) return;
        setState(() {
          _hasMorePosts = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Update last post for next pagination
      _lastPost = models.last;
      _hasMorePosts = models.length == _postsPerPage;

      // Process new posts
      var newPosts = await _mapModelsToPosts(models);
      debugPrint('📬 Mapped ${newPosts.length} new posts');
      newPosts = await _hydrateReposts(newPosts);
      debugPrint('💧 Hydrated ${newPosts.length} new posts');
      newPosts = _applyFeedFilters(newPosts);
      debugPrint('🔍 After filters: ${newPosts.length} new posts');

      if (!mounted) return;
      setState(() {
        _posts.addAll(newPosts);
        _isLoadingMore = false;
      });
      debugPrint('✅ Total posts in feed: ${_posts.length}');
      debugPrint('📄 Has more posts: $_hasMorePosts');
    } catch (e) {
      debugPrint('❌ Error loading more posts: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
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

  // Fetch original posts for repost items when the backend didn't hydrate them.
  Future<List<Post>> _hydrateReposts(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    
    // Process all reposts in parallel
    final futures = <Future<Post>>[];
    for (final p in posts) {
      if (!p.isRepost || p.originalPostId == null || p.originalPostId!.isEmpty) {
        futures.add(Future.value(p));
        continue;
      }

      futures.add(() async {
        try {
          final m = await _postRepo.getPost(p.originalPostId!);
          if (m == null) return p;
          final og = await _toPost(m);
          // Merge original post content but keep the repost metadata (repostedBy, etc.)
          return p.copyWith(
            authorId: og.authorId,  // Use original author's ID
            userName: og.userName,
            userAvatarUrl: og.userAvatarUrl,
            text: og.text,
            mediaType: og.mediaType,
            imageUrls: og.imageUrls,
            videoUrl: og.videoUrl,
            counts: og.counts,
            // Keep repostedBy from the original repost entry (p.repostedBy)
          );
        } catch (_) {
          return p; // Return original on error
        }
      }());
    }

    return await Future.wait(futures);
  }

  // Normalize storage URLs so UI can load images reliably
  Future<String> _normalizeUrl(String u) async {
    final s = u.trim();
    if (s.isEmpty) return s;
    // Auto-upgrade insecure http to https when possible
    if (s.startsWith('http://')) {
      final https = 'https://${s.substring('http://'.length)}';
      return https;
    }
    // For firebase storage http URLs, resolve to a fresh tokened download URL
    if (s.startsWith('https://') &&
        (s.contains('firebasestorage.googleapis.com') ||
         s.contains('firebasestorage.app') ||
         s.contains('storage.googleapis.com'))) {
      try {
        return await fs.FirebaseStorage.instance.refFromURL(s).getDownloadURL();
      } catch (_) {
        // fallthrough
      }
      return s;
    }
    if (s.startsWith('http')) return s;
    try {
      if (s.startsWith('gs://')) {
        return await fs.FirebaseStorage.instance.refFromURL(s).getDownloadURL();
      }
      // Treat as storage path like "uploads/uid/file.jpg"
      return await fs.FirebaseStorage.instance.ref(s).getDownloadURL();
    } catch (_) {
      return s;
    }
  }

  Future<List<String>> _normalizeUrls(List<String> urls) async {
    // Parallelize URL normalization
    final normalized = await Future.wait(
      urls.map((u) => _normalizeUrl(u))
    );
    return normalized.where((n) => n.isNotEmpty).toList();
  }

  Future<Post> _toPost(PostModel m) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    
    // Parallelize all async operations
    final results = await Future.wait([
      _userRepo.getUserProfile(m.authorId),
      _normalizeUrls(m.mediaUrls),
      if (uid != null) _postRepo.hasUserBookmarkedPost(postId: m.id, uid: uid) else Future.value(false),
      if (uid != null) _postRepo.hasUserLikedPost(postId: m.id, uid: uid) else Future.value(false),
    ]);
    
    final author = results[0] as UserProfile?;
    final normUrls = results[1] as List<String>;
    final isBookmarked = results[2] as bool;
    final isLiked = results[3] as bool;
    
    // If this is a repost, get the reposter's info (the author of this repost entry)
    RepostedBy? repostedBy;
    if (m.repostOf != null && m.repostOf!.isNotEmpty) {
      debugPrint('🔁 Processing repost: ${m.id} -> original: ${m.repostOf}');
      // Build full name for reposter
      final repostFirstName = author?.firstName?.trim() ?? '';
      final repostLastName = author?.lastName?.trim() ?? '';
      final repostFullName = (repostFirstName.isNotEmpty || repostLastName.isNotEmpty)
          ? '$repostFirstName $repostLastName'.trim()
          : (author?.displayName ?? author?.username ?? 'User');
      
      repostedBy = RepostedBy(
        userId: m.authorId,
        userName: repostFullName,
        userAvatarUrl: author?.avatarUrl ?? '',
        actionType: 'reposted this',
      );
    }

    MediaType mediaType;
    String? videoUrl;
    if (normUrls.isEmpty) {
      mediaType = MediaType.none;
      videoUrl = null;
    } else {
      final hasVideo = normUrls.any((u) {
        final l = u.toLowerCase();
        return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.webm');
      });
      if (hasVideo) {
        mediaType = MediaType.video;
        videoUrl = normUrls.firstWhere(
          (u) {
            final l = u.toLowerCase();
            return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.webm');
          },
          orElse: () => normUrls.first,
        );
      } else {
        mediaType = (normUrls.length == 1) ? MediaType.image : MediaType.images;
        videoUrl = null;
      }
    }
    int clamp(int v) => v < 0 ? 0 : v;
    
    // Normalize avatar URL (still needs await but only one operation)
    final avatarUrl = await _normalizeUrl(author?.avatarUrl ?? '');
    
    // Build full name from firstName and lastName
    final firstName = author?.firstName?.trim() ?? '';
    final lastName = author?.lastName?.trim() ?? '';
    final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '$firstName $lastName'.trim()
        : (author?.displayName ?? author?.username ?? author?.email ?? 'User');
    
    
    return Post(
      id: m.id,
      authorId: m.authorId,
      userName: fullName,
      userAvatarUrl: avatarUrl,
      createdAt: m.createdAt,
      text: m.text,
      mediaType: mediaType,
      imageUrls: normUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: clamp(m.summary.likes),
        comments: clamp(m.summary.comments),
        shares: clamp(m.summary.shares),
        reposts: clamp(m.summary.reposts),
        bookmarks: clamp(m.summary.bookmarks),
      ),
      userReaction: isLiked ? ReactionType.like : null,
      isBookmarked: isBookmarked,
      isRepost: (m.repostOf != null && m.repostOf!.isNotEmpty),
      repostedBy: repostedBy,
      originalPostId: m.repostOf,
    );
  }

  Future<List<Post>> _mapModelsToPosts(List<PostModel> models) async {
    // Parallelize post conversion
    return await Future.wait(
      models.map((m) => _toPost(m))
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
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );
        if (created == true) {
          await _loadData();
        }
      }();
    } else if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VideoScrollPage()),
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

  Future<List<Comment>> _loadCommentsForPost(String postId) async {
    final list = await _commentRepo.getComments(postId: postId, limit: 200);
    final uids = list.map((m) => m.authorId).toSet().toList();
    final profiles = await _userRepo.getUsers(uids);
    final byId = {for (final p in profiles) p.uid: p};
    return list.map((m) {
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
        isLikedByUser: false,
        replies: const [],
        parentCommentId: m.parentCommentId,
      );
    }).toList();
  }

  Future<void> _openCommentsSheet(String originalId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Comment> comments = [];
    try {
      comments = await _loadCommentsForPost(originalId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.load_comments_failed')}: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;

    CommentBottomSheet.show(
      context,
      postId: originalId,
      comments: comments,
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

  void _onPostTap(String originalId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostPage(postId: originalId)),
    );
    // Refresh after returning from Post page
    await _loadData();
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
                  ? FloatingActionButton(
                      heroTag: 'toolsFabMain',
                      onPressed: _showToolsOverlay,
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.widgets_outlined),
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
            MaterialPageRoute(builder: (_) => const PodcastsHomePage()));
      },
      onBooks: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BooksHomePage()));
      },
      onMentorship: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MentorshipHomePage()));
      },
      onVideos: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VideoScrollPage()));
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
          ? FloatingActionButton(
              heroTag: 'toolsFabWeb',
              onPressed: _showToolsOverlay,
              backgroundColor: const Color(0xFFBFAE01),
              foregroundColor: Colors.black,
              child: const Icon(Icons.widgets_outlined),
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
                            ? 'Your Story'
                            : (ring.userName.isNotEmpty
                                ? ring.userName
                                : '@user'),
                        isMine: isMine,
                        isSeen: !ring.hasUnseen,
                        onAddTap: isMine
                            ? () {
                                if (ring.storyCount > 0 &&
                                    _currentUserId != null) {
                                  MyStoriesBottomSheet.show(
                                    context,
                                    currentUserId: _currentUserId!,
                                    onAddStory: () {
                                      StoryTypePicker.show(
                                        context,
                                        onSelected: (type) async {
                                          if (_useDesktopPopup(context)) {
                                            await StoryComposerPopup.show(
                                                context,
                                                type: type);
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      _composerPage(type)),
                                            );
                                          }
                                        },
                                      );
                                    },
                                  );
                                } else {
                                  StoryTypePicker.show(
                                    context,
                                    onSelected: (type) async {
                                      if (_useDesktopPopup(context)) {
                                        await StoryComposerPopup.show(context,
                                            type: type);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  _composerPage(type)),
                                        );
                                      }
                                    },
                                  );
                                }
                              }
                            : null,
                        onTap: () async {
                          if (isMine) {
                            if (ring.storyCount > 0 && _currentUserId != null) {
                              MyStoriesBottomSheet.show(
                                context,
                                currentUserId: _currentUserId!,
                                onAddStory: () {
                                  StoryTypePicker.show(
                                    context,
                                    onSelected: (type) async {
                                      if (_useDesktopPopup(context)) {
                                        await StoryComposerPopup.show(context,
                                            type: type);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  _composerPage(type)),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            } else {
                              StoryTypePicker.show(
                                context,
                                onSelected: (type) async {
                                  if (_useDesktopPopup(context)) {
                                    await StoryComposerPopup.show(context,
                                        type: type);
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => _composerPage(type)),
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
                                MaterialPageRoute(
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
              onTap: _onPostTap,
              onShare: _onShare,
              onComment: _onComment,
              onRepost: _onRepost,
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
                      'Loading more posts...',
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
                'You\'re all caught up! 🎉',
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
                  'Connections',
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
          if (notification is ScrollStartNotification) {
            // Hide reaction picker when scrolling starts
            ReactionPickerManager.hideReactions();
          }
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
                      height: 90,
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
                                  width: 70,
                                  margin: EdgeInsets.only(
                                    right: index < _storyRings.length - 1 ? 16 : 0,
                                  ),
                                  child: story_widget.StoryRing(
                                    imageUrl: ring.userAvatar,
                                    label: isMine
                                        ? 'Your Story'
                                        : (ring.userName.isNotEmpty
                                            ? ring.userName
                                            : '@user'),
                                    isMine: isMine,
                                    isSeen: !ring.hasUnseen,

                                    // Remove the + icon from Your Story ring
                                    onAddTap: null,
                                    onTap: () async {
                                  if (isMine) {
                                    // Check if user has any ACTIVE stories (not expired)
                                    final now = DateTime.now();
                                    final activeStories = ring.stories.where((story) {
                                      final age = now.difference(story.createdAt);
                                      return age.inHours < 24; // Stories expire after 24 hours
                                    }).toList();
                                    
                                    if (activeStories.isNotEmpty && _currentUserId != null) {
                                      // User has active stories - show bottom sheet
                                      MyStoriesBottomSheet.show(
                                        context,
                                        currentUserId: _currentUserId!,
                                        onAddStory: () {
                                          StoryTypePicker.show(
                                            context,
                                            onSelected: (type) async {
                                              if (_useDesktopPopup(context)) {
                                                await StoryComposerPopup.show(
                                                    context,
                                                    type: type);
                                              } else {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          _composerPage(type)),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      );
                                    } else {
                                      // No active stories - show type picker directly
                                      StoryTypePicker.show(
                                        context,
                                        onSelected: (type) async {
                                          if (_useDesktopPopup(context)) {
                                            await StoryComposerPopup.show(
                                                context,
                                                type: type);
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
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
                                        MaterialPageRoute(
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

          // Feed as a sliver list so it scrolls together with the header
          SliverPadding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return PostCard(
                  post: _posts[index],
                  onReactionChanged: _onReactionChanged,
                  onBookmarkToggle: _onBookmarkToggle,
                  onTap: _onPostTap,
                  onShare: _onShare,
                  onComment: _onComment,
                  onRepost: _onRepost,
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
                        'Loading more posts...',
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
                    'You\'re all caught up! 🎉',
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
