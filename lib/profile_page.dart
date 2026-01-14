import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/community_interest_sync_service.dart';
import 'widgets/post_card.dart';
import 'widgets/home_post_card.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'models/post.dart';
import 'settings_page.dart';
import 'insights_page.dart';
import 'drafts_page.dart';
import 'bookmarks_page.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'my_connections_page.dart';
import 'edit_profil.dart';
import 'monetization_page.dart';
import 'premium_subscription_page.dart';
import 'sign_in_page.dart';
import 'core/profile_api.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/models/post_model.dart';
import 'core/post_events.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'repositories/firebase/firebase_kyc_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'core/admin_config.dart';
import 'repositories/interfaces/podcast_repository.dart';
import 'widgets/badge_icon.dart';
import 'notification_page.dart';
import 'conversations_page.dart';
import 'connections_page.dart';
import 'responsive/responsive_breakpoints.dart';
import 'support_page.dart';
import 'help_center_page.dart';
import 'services/profile_cache_service.dart';
import 'widgets/expandable_photo_viewer.dart';
import 'story_music_list_page.dart';
import 'core/performance_monitor.dart';

class ProfilePage extends StatefulWidget {
  final bool hideDesktopTopNav;

  const ProfilePage({super.key, this.hideDesktopTopNav = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _profile;
  // FASTFEED: Start with false - cache loads instantly before first paint feels slow
  bool _loadingProfile = false;

  String? _myUserId;

  // Activity: posts I engaged with (like/bookmark/share/repost), excluding my own original posts
  List<Post> _activityPosts = [];
  bool _loadingActivity = false;
  String? _errorActivity;
  bool _isLoadingMoreActivity = false;
  final ScrollController _activityScrollController = ScrollController();

  // Posts: created by me
  List<Post> _myPosts = [];
  bool _loadingMyPosts = false;
  String? _errorMyPosts;
  bool _isLoadingMorePosts = false;
  final ScrollController _postsScrollController = ScrollController();

  // Media grid: image URLs from my posts with post IDs
  List<Map<String, String>> _mediaItems = []; // {imageUrl, postId}
  bool _loadingMedia = false;

  // Podcasts: created by me
  List<Map<String, dynamic>> _myPodcasts = [];
  bool _loadingPodcasts = false;
  String? _errorPodcasts;
  
  // Listen to post updates for real-time like/bookmark sync
  StreamSubscription<PostUpdateEvent>? _postEventsSub;

  // Notifications badge
  int _unreadNotifications = 0;
  
  // Caching for user profiles to avoid redundant fetches
  final Map<String, dynamic> _userProfileCache = {};
  
  // Author profile cache for fast hydration (same pattern as home feed)
  final Map<String, Map<String, String>> _authorProfilesCache = {};
  final Map<String, PostModel> _hydratedOriginalPosts = {};
  final FirebasePostRepository _postRepo = FirebasePostRepository();

  late final ProfileCacheService _profileCache;

  @override
  void initState() {
    super.initState();
    _profileCache = ProfileCacheService();

    // Default: show shimmer until cache is applied
    _loadingProfile = true;
    _loadingMyPosts = true;
    _loadingActivity = true;
    _loadingMedia = true;
    _loadingPodcasts = true;

    // Apply whatever is already in memory instantly
    PerformanceMonitor().startProfileLoad();
    _applyProfileCacheSync();

    // Listen for cache becoming ready (preloaded during app start/login)
    _profileCache.addListener(_onProfileCacheChanged);

    // Fallback: If cache not loaded after 500ms, trigger network load
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (!_profileCache.isProfileLoaded) {
        debugPrint('⚠️ [Profile] Cache not ready after 500ms, loading from network');
        _loadProfileFallback();
      }
    });

    _loadUnreadNotifications();
    
    // Setup scroll listeners for pagination
    _postsScrollController.addListener(_onPostsScroll);
    _activityScrollController.addListener(_onActivityScroll);
  }

  void _onProfileCacheChanged() {
    if (!mounted) return;
    _applyProfileCacheSync();
  }
  
  /// Fallback: Load profile from network when cache isn't ready
  Future<void> _loadProfileFallback() async {
    try {
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Trigger cache preload
      await ProfileCacheService().preloadCurrentUserData(currentUser.uid);
      
      // Apply the now-loaded cache
      if (mounted) {
        _applyProfileCacheSync();
      }
    } catch (e) {
      debugPrint('⚠️ [Profile] Fallback load error: $e');
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _loadingMyPosts = false;
          _loadingActivity = false;
          _loadingMedia = false;
          _loadingPodcasts = false;
        });
      }
    }
  }

  bool _activityLoadTriggered = false;
  bool _podcastsLoadTriggered = false;
  bool _postsLoadTriggered = false;
  
  void _applyProfileCacheSync() {
    // Profile map is already in the exact format ProfilePage UI expects (snake_case)
    final p = _profileCache.currentUserProfileMap;
    if (p != null && p.isNotEmpty) {
      _profile = p;
      _myUserId = (p['id'] ?? p['uid'] ?? '').toString();
      _loadingProfile = false;
      PerformanceMonitor().stopProfileLoad();
      
      // Load activity and podcasts once we have userId (only once)
      if (_myUserId != null && _myUserId!.isNotEmpty) {
        if (!_activityLoadTriggered) {
          _activityLoadTriggered = true;
          _loadActivity();
        }
        if (!_podcastsLoadTriggered) {
          _podcastsLoadTriggered = true;
          _loadMyPodcasts();
        }
      }
    }

    // If we have posts preloaded, show them instantly
    final models = _profileCache.currentUserPosts;
    if (models.isNotEmpty) {
      // Do not block UI; hydrate then setState when ready
      _applyCachedPosts(models);
    } else if (_profileCache.isPostsLoaded) {
      _loadingMyPosts = false;
      _loadingMedia = false;
    } else if (_myUserId != null && _myUserId!.isNotEmpty && !_postsLoadTriggered) {
      // Fallback: Load posts from network if cache is empty
      _postsLoadTriggered = true;
      _loadMyPosts();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyCachedPosts(List<PostModel> models) async {
    try {
      final hydratedModels = await _hydrateAllAuthorData(models);
      if (!mounted) return;
      final posts = _mapPostModelsFast(hydratedModels);
      final mediaItems = _extractMediaItems(posts);
      setState(() {
        _myPosts = posts;
        _mediaItems = mediaItems;
        _loadingMyPosts = false;
        _loadingMedia = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMyPosts = false;
        _loadingMedia = false;
      });
    }
  }



  /// FAST: Convert PostModels to Posts synchronously using denormalized data
  List<Post> _mapPostModelsFast(List<PostModel> models) {
    final result = <Post>[];
    for (final m in models) {
      // Skip reposts
      if (m.repostOf != null && m.repostOf!.isNotEmpty) continue;
      
      // Use denormalized data or check cache
      String authorName = m.authorName ?? 'User';
      String authorAvatarUrl = m.authorAvatarUrl ?? '';
      
      // Check cache for author data if missing
      if ((authorName == 'User' || authorName.isEmpty) && _authorProfilesCache.containsKey(m.authorId)) {
        final profile = _authorProfilesCache[m.authorId]!;
        authorName = profile['name'] ?? 'User';
        authorAvatarUrl = profile['avatarUrl'] ?? '';
      }
      
      MediaType mediaType;
      String? videoUrl;
      List<String> imageUrls;
      
      if (m.mediaThumbs.isNotEmpty) {
        final hasVideo = m.mediaThumbs.any((t) => t.type == 'video');
        if (hasVideo) {
          mediaType = MediaType.video;
          videoUrl = m.mediaUrls.firstWhere(
            (u) => u.toLowerCase().contains('.mp4') || u.toLowerCase().contains('.mov'),
            orElse: () => m.mediaUrls.isNotEmpty ? m.mediaUrls.first : '',
          );
          imageUrls = [];
        } else {
          mediaType = m.mediaThumbs.length == 1 ? MediaType.image : MediaType.images;
          videoUrl = null;
          imageUrls = m.mediaThumbs.map((t) => t.thumbUrl).toList();
        }
      } else if (m.mediaUrls.isNotEmpty) {
        final hasVideo = m.mediaUrls.any((u) => 
          u.toLowerCase().contains('.mp4') || u.toLowerCase().contains('.mov')
        );
        if (hasVideo) {
          mediaType = MediaType.video;
          videoUrl = m.mediaUrls.firstWhere(
            (u) => u.toLowerCase().contains('.mp4') || u.toLowerCase().contains('.mov'),
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
      
      result.add(Post(
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
          likes: m.summary.likes,
          comments: m.summary.comments,
          shares: m.summary.shares,
          reposts: m.summary.reposts,
          bookmarks: m.summary.bookmarks,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
        repostedBy: null,
        originalPostId: null,
      ));
    }
    return result;
  }

  /// Extract media items from posts for media grid
  List<Map<String, String>> _extractMediaItems(List<Post> posts) {
    final items = <Map<String, String>>[];
    for (final p in posts) {
      if (p.isRepost) continue;
      for (final url in p.imageUrls) {
        items.add({'imageUrl': url, 'postId': p.id});
      }
    }
    return items;
  }
  
  /// SYNC: Hydrate ALL author data before displaying (same as home feed)
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
      debugPrint('💧 [Profile] Hydrating ${authorIds.length} authors before display...');
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

  @override
  void dispose() {
    _postEventsSub?.cancel();
    _postsScrollController.dispose();
    _activityScrollController.dispose();
    _profileCache.removeListener(_onProfileCacheChanged);
    super.dispose();
  }
  
  // Pagination for posts tab
  void _onPostsScroll() {
    if (_isLoadingMorePosts || _loadingMyPosts) return;
    if (_postsScrollController.position.pixels >= _postsScrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
  }
  
  // Pagination for activity tab
  void _onActivityScroll() {
    if (_isLoadingMoreActivity || _loadingActivity) return;
    if (_activityScrollController.position.pixels >= _activityScrollController.position.maxScrollExtent * 0.8) {
      _loadMoreActivity();
    }
  }
  
  Future<void> _loadMorePosts() async {
    if (_myPosts.isEmpty) return;
    setState(() => _isLoadingMorePosts = true);
    // Add pagination logic here when needed
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoadingMorePosts = false);
  }
  
  Future<void> _loadMoreActivity() async {
    if (_activityPosts.isEmpty) return;
    setState(() => _isLoadingMoreActivity = true);
    // Add pagination logic here when needed
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoadingMoreActivity = false);
  }

  Future<void> _loadUnreadNotifications() async {
    // Placeholder: notifications count will be handled elsewhere
    setState(() => _unreadNotifications = 0);
  }

  List<Map<String, dynamic>> _parseListOfMap(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  List<String> _parseStringList(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _formatCount(dynamic v) {
    final n = _toInt(v);
    if (n >= 1000000) {
      final m = (n / 1000000);
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final k = (n / 1000);
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  DateTime _parseCreatedAt(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$',
    ).firstMatch(s);
    if (m != null) {
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      final second = int.parse(m.group(6)!);
      final ms = int.tryParse(m.group(7) ?? '0') ?? 0;
      return DateTime.utc(year, month, day, hour, minute, second, ms);
    }
    return DateTime.now();
  }

  Post _mapRawPostToModel(Map<String, dynamic> p) {
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    final original = asMap(p['original_post']);
    // Use original post for content/media/author if it was hydrated
    final contentSource = original.isNotEmpty ? original : p;

    // Author (from content source)
    // Try both 'author' and 'user' fields
    final author = asMap(contentSource['author']);
    final user = asMap(contentSource['user']);
    final authorData = author.isNotEmpty ? author : user;
    
    final authorId = (authorData['id'] ?? authorData['uid'] ?? authorData['user_id'] ?? contentSource['author_id'] ?? p['author_id'] ?? p['user_id'] ?? '').toString();
    
    // Build full name from firstName and lastName, fallback to name or username
    final authorFirstName = (authorData['firstName'] ?? authorData['first_name'] ?? '').toString().trim();
    final authorLastName = (authorData['lastName'] ?? authorData['last_name'] ?? '').toString().trim();
    final authorName = (authorFirstName.isNotEmpty || authorLastName.isNotEmpty)
        ? '$authorFirstName $authorLastName'.trim()
        : (authorData['name'] ?? authorData['displayName'] ?? authorData['username'] ?? 'User').toString();
    final authorAvatar = (authorData['avatarUrl'] ?? authorData['avatar_url'] ?? authorData['profile_photo_url'] ?? '')
        .toString();

    // Counts
    Map<String, dynamic> countsMap = {};
    final directCounts = asMap(p['counts']);
    final originalCounts = asMap(contentSource['counts']);
    if (originalCounts.isNotEmpty) {
      countsMap = originalCounts;
    } else if (directCounts.isNotEmpty) {
      countsMap = directCounts;
    } else {
      countsMap = {
        'likes': p['likes_count'] ?? 0,
        'comments': p['comments_count'] ?? 0,
        'shares': p['shares_count'] ?? 0,
        'reposts': p['reposts_count'] ?? 0,
        'bookmarks': p['bookmarks_count'] ?? 0,
      };
    }

    // Media: prefer `media` list; fallback to image_url/image_urls/video_url if needed
    MediaType mediaType = MediaType.none;
    String? videoUrl;
    List<String> imageUrls = [];

    List<dynamic> mediaList = [];
    if (contentSource['media'] is List) {
      mediaList = List<dynamic>.from(contentSource['media']);
    } else if (p['media'] is List) {
      mediaList = List<dynamic>.from(p['media']);
    }

    if (mediaList.isNotEmpty) {
      final asMaps = mediaList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      String urlOf(Map<String, dynamic> m) =>
          (m['url'] ?? m['src'] ?? m['link'] ?? '').toString();

      final videos = asMaps.where((m) {
        final t = (m['type'] ?? m['media_type'] ?? m['kind'] ?? '')
            .toString()
            .toLowerCase();
        return t.contains('video');
      }).toList();

      final images = asMaps.where((m) {
        final t = (m['type'] ?? m['media_type'] ?? m['kind'] ?? '')
            .toString()
            .toLowerCase();
        return t.contains('image') || t.contains('photo') || t.isEmpty;
      }).toList();

      if (videos.isNotEmpty) {
        mediaType = MediaType.video;
        videoUrl = urlOf(videos.first);
      } else if (images.length > 1) {
        mediaType = MediaType.images;
        imageUrls = images.map(urlOf).where((u) => u.isNotEmpty).toList();
      } else if (images.length == 1) {
        mediaType = MediaType.image;
        final u = urlOf(images.first);
        if (u.isNotEmpty) imageUrls = [u];
      }
    } else {
      // Fallbacks for alternate schemas
      List<String> parseImageUrls(dynamic v) {
        if (v == null) return [];
        if (v is List) {
          return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        }
        if (v is String && v.isNotEmpty) {
          try {
            final decoded = jsonDecode(v);
            if (decoded is List) {
              return decoded
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          } catch (_) {}
        }
        return [];
      }

      final csVideo = (contentSource['video_url'] ?? '').toString();
      final csImageUrl = (contentSource['image_url'] ?? '').toString();
      final csImageUrls = parseImageUrls(contentSource['image_urls']);

      if (csVideo.isNotEmpty) {
        mediaType = MediaType.video;
        videoUrl = csVideo;
      } else if (csImageUrls.length > 1) {
        mediaType = MediaType.images;
        imageUrls = csImageUrls;
      } else if (csImageUrls.length == 1) {
        mediaType = MediaType.image;
        imageUrls = csImageUrls;
      } else if (csImageUrl.isNotEmpty) {
        mediaType = MediaType.image;
        imageUrls = [csImageUrl];
      }
    }

    // Me flags (from row, not original)
    final me = asMap(p['me']);
    final likedByMe = (me['liked'] ?? false) == true;
    final bookmarkedByMe = (me['bookmarked'] ?? false) == true;

    // Repost detection
    final isRepost = p['repost_of'] != null || original.isNotEmpty;

    // Reposter info (header)
    final repostAuthor = asMap(p['repost_author']);
    RepostedBy? repostedBy;
    if (repostAuthor.isNotEmpty) {
      // Only show "reposted this" when this repost row belongs to me
      final isRepostRowByMe =
          (_myUserId != null) &&
          (p['user_id'] != null) &&
          p['repost_of'] != null &&
          p['user_id'].toString() == _myUserId;
      // Build full name for reposter
      final repostFirstName = (repostAuthor['firstName'] ?? repostAuthor['first_name'] ?? '').toString().trim();
      final repostLastName = (repostAuthor['lastName'] ?? repostAuthor['last_name'] ?? '').toString().trim();
      final repostName = (repostFirstName.isNotEmpty || repostLastName.isNotEmpty)
          ? '$repostFirstName $repostLastName'.trim()
          : (repostAuthor['name'] ?? repostAuthor['displayName'] ?? repostAuthor['username'] ?? 'User').toString();
      
      repostedBy = RepostedBy(
        userName: repostName,
        userAvatarUrl:
            (repostAuthor['avatarUrl'] ?? repostAuthor['avatar_url'] ?? '')
                .toString(),
        actionType: isRepostRowByMe ? 'reposted this' : null,
      );
    }

    // Text
    final text =
        (contentSource['content'] ??
                contentSource['text'] ??
                p['original_content'] ??
                p['text'] ??
                p['content'] ??
                '')
            .toString();

    return Post(
      id: (p['id'] ?? '').toString(),
      authorId: authorId,
      userName: authorName,
      userAvatarUrl: authorAvatar,
      createdAt: _parseCreatedAt(
        p['created_at'] ??
            p['createdAt'] ??
            contentSource['created_at'] ??
            contentSource['createdAt'],
      ),
      text: text,
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: _toInt(countsMap['likes']),
        comments: _toInt(countsMap['comments']),
        shares: _toInt(countsMap['shares']),
        reposts: _toInt(countsMap['reposts']),
        bookmarks: _toInt(countsMap['bookmarks']),
      ),
      userReaction: likedByMe ? ReactionType.like : null,
      isBookmarked: bookmarkedByMe,
      isRepost: isRepost,
      repostedBy: repostedBy,
      originalPostId:
          (p['repost_of'] ?? original['id'] ?? original['post_id'] ?? '')
              .toString()
              .isEmpty
          ? null
          : (p['repost_of'] ?? original['id'] ?? original['post_id'])
                .toString(),
    );
  }

  Future<void> _loadMyPosts() async {
    if (_myUserId == null || _myUserId!.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingMyPosts = false;
          _loadingMedia = false;
          _errorMyPosts = 'No user ID available';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingMyPosts = true;
        _loadingMedia = true;
        _errorMyPosts = null;
      });
    }

    try {
      final postRepo = FirebasePostRepository();
      final userRepo = FirebaseUserRepository();
      final postModels = await postRepo.getUserPosts(uid: _myUserId!, limit: 50);
      
      if (!mounted) return;

      final newItems = <Map<String, dynamic>>[];

      // ⚡ OPTIMIZATION: Batch fetch all unique author profiles in parallel
      final uniqueAuthorIds = postModels.map((m) => m.authorId).toSet();
      final authorFutures = uniqueAuthorIds.map((authorId) async {
        if (_userProfileCache.containsKey(authorId)) {
          return MapEntry(authorId, _userProfileCache[authorId]);
        }
        final profile = await userRepo.getUserProfile(authorId);
        if (profile != null) {
          _userProfileCache[authorId] = profile;
        }
        return MapEntry(authorId, profile);
      });
      final authors = Map.fromEntries(await Future.wait(authorFutures));
      
      if (!mounted) return;

      // ⚡ OPTIMIZATION: Batch check like/bookmark status for all posts in parallel
      final likeBookmarkFutures = postModels.map((model) async {
        final liked = _myUserId != null 
            ? await postRepo.hasUserLikedPost(postId: model.id, uid: _myUserId!)
            : false;
        final bookmarked = _myUserId != null
            ? await postRepo.hasUserBookmarkedPost(postId: model.id, uid: _myUserId!)
            : false;
        return MapEntry(model.id, {'liked': liked, 'bookmarked': bookmarked});
      });
      final likeBookmarkMap = Map.fromEntries(await Future.wait(likeBookmarkFutures));
      
      if (!mounted) return;

      for (final model in postModels) {
        final isRepost = model.repostOf != null && model.repostOf!.isNotEmpty;
        
        // SKIP reposts - they should only appear in Activity tab
        if (isRepost) {
          continue;
        }
        
        // Get cached author profile
        final author = authors[model.authorId];
        
        // Get cached like/bookmark status
        final status = likeBookmarkMap[model.id] ?? {'liked': false, 'bookmarked': false};
        final isLiked = status['liked'] as bool;
        final isBookmarked = status['bookmarked'] as bool;
        
        // Convert mediaUrls list to media array with proper structure
        final mediaArray = model.mediaUrls.map((url) {
          // Determine if it's an image or video based on extension
          final lowercaseUrl = url.toLowerCase();
          final isVideo = lowercaseUrl.contains('.mp4') || 
                         lowercaseUrl.contains('.mov') || 
                         lowercaseUrl.contains('.avi') ||
                         lowercaseUrl.contains('video');
          
          return {
            'url': url,
            'type': isVideo ? 'video' : 'image',
          };
        }).toList();
        
        // Build full name from firstName and lastName
        final firstName = author?.firstName?.trim() ?? '';
        final lastName = author?.lastName?.trim() ?? '';
        final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : (author?.displayName ?? author?.username ?? 'User');
        
        
        final mp = {
          'id': model.id,
          'user_id': model.authorId,
          'user': {
            'name': fullName,
            'profile_photo_url': author?.avatarUrl ?? '',
          },
          'text': model.text,
          'media': mediaArray,
          'created_at': model.createdAt.toIso8601String(),
          'is_repost': false, // No reposts in Posts tab
          'original_post_id': null,
          'counts': {
            'likes': model.summary.likes.clamp(0, 999999),
            'comments': model.summary.comments.clamp(0, 999999),
            'shares': model.summary.shares.clamp(0, 999999),
            'reposts': model.summary.reposts.clamp(0, 999999),
            'bookmarks': model.summary.bookmarks.clamp(0, 999999),
          },
          'me': {
            'liked': isLiked,
            'bookmarked': isBookmarked,
          },
        };
        newItems.add(mp);
      }

      final posts = newItems.map(_mapRawPostToModel).toList();

      // Build media grid: one thumbnail per post that has media
      // For multi-image posts, show only the first image
      final mediaItems = <Map<String, String>>[];
      for (final post in posts) {
        // Include all posts with images (single or multiple)
        if ((post.mediaType == MediaType.image || post.mediaType == MediaType.images) && 
            post.imageUrls.isNotEmpty) {
          // Always use the first image as thumbnail
          mediaItems.add({'imageUrl': post.imageUrls.first, 'postId': post.id});
        }
      }
      
      if (!mounted) return;
      
      setState(() {
        _myPosts = posts;
        _mediaItems = mediaItems;
        _loadingMyPosts = false;
        _loadingMedia = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Error in _loadMyPosts: $e');
      debugPrint('Stack trace: $stack');
      
      if (!mounted) return;
      
      setState(() {
        _errorMyPosts = 'Failed to load posts: $e';
        _loadingMyPosts = false;
        _loadingMedia = false;
      });
    }
  }

  Future<void> _loadActivity() async {
    if (_myUserId == null || _myUserId!.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingActivity = false;
          _errorActivity = 'No user ID available';
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _loadingActivity = true;
        _errorActivity = null;
      });
    }

    try {
      final postRepo = FirebasePostRepository();
      final userRepo = FirebaseUserRepository();
      
      // ⚡ OPTIMIZATION: Fetch all activity posts in parallel
      final activityResults = await Future.wait([
        postRepo.getPostsLikedByUser(uid: _myUserId!, limit: 50),
        postRepo.getPostsBookmarkedByUser(uid: _myUserId!, limit: 50),
        postRepo.getUserReposts(uid: _myUserId!, limit: 50),
      ]);
      
      if (!mounted) return;
      
      final likedPosts = activityResults[0];
      final bookmarkedPosts = activityResults[1];
      final reposts = activityResults[2];
      
      // Combine all activity posts
      final allActivityModels = [...likedPosts, ...bookmarkedPosts, ...reposts];
      
      // Remove duplicates by ID
      final seen = <String>{};
      final uniqueModels = allActivityModels.where((m) => seen.add(m.id)).toList();
      
      // Sort by date
      uniqueModels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Convert to UI format
      final filtered = <Map<String, dynamic>>[];
      final originals = <String, Map<String, dynamic>>{};
      
      // ⚡ OPTIMIZATION: Batch fetch all unique author profiles in parallel
      final activityAuthorIds = uniqueModels.take(100).map((m) => m.authorId).toSet();
      final activityAuthorFutures = activityAuthorIds.map((authorId) async {
        if (_userProfileCache.containsKey(authorId)) {
          return MapEntry(authorId, _userProfileCache[authorId]);
        }
        final profile = await userRepo.getUserProfile(authorId);
        if (profile != null) {
          _userProfileCache[authorId] = profile;
        }
        return MapEntry(authorId, profile);
      });
      final activityAuthors = Map.fromEntries(await Future.wait(activityAuthorFutures));
      
      if (!mounted) return;
      
      // ⚡ OPTIMIZATION: Batch check like/bookmark status for all posts in parallel
      final activityStatusFutures = uniqueModels.take(100).map((model) async {
        final liked = _myUserId != null
            ? await postRepo.hasUserLikedPost(postId: model.id, uid: _myUserId!)
            : false;
        final bookmarked = _myUserId != null
            ? await postRepo.hasUserBookmarkedPost(postId: model.id, uid: _myUserId!)
            : false;
        return MapEntry(model.id, {'liked': liked, 'bookmarked': bookmarked});
      });
      final activityStatusMap = Map.fromEntries(await Future.wait(activityStatusFutures));
      
      if (!mounted) return;
      
      for (final model in uniqueModels.take(100)) {
        // Get cached author profile
        final author = activityAuthors[model.authorId];
        final repostId = model.repostOf;
        final isRepost = repostId != null && repostId.isNotEmpty;
        
        // Get cached like/bookmark status
        final status = activityStatusMap[model.id] ?? {'liked': false, 'bookmarked': false};
        final isLiked = status['liked'] as bool;
        final isBookmarked = status['bookmarked'] as bool;
        
        // Build full name from firstName and lastName
        final activityFirstName = author?.firstName?.trim() ?? '';
        final activityLastName = author?.lastName?.trim() ?? '';
        final activityFullName = (activityFirstName.isNotEmpty || activityLastName.isNotEmpty)
            ? '$activityFirstName $activityLastName'.trim()
            : (author?.displayName ?? author?.username ?? 'User');
        
        final mp = {
          'id': model.id,
          'user_id': model.authorId,
          'user': {
            'name': activityFullName,
            'profile_photo_url': author?.avatarUrl ?? '',
          },
          'text': model.text,
          'media': model.mediaUrls,
          'created_at': model.createdAt.toIso8601String(),
          'is_repost': isRepost,
          'repost_of': repostId,
          'counts': {
            'likes': model.summary.likes.clamp(0, 999999),
            'comments': model.summary.comments.clamp(0, 999999),
            'shares': model.summary.shares.clamp(0, 999999),
            'reposts': model.summary.reposts.clamp(0, 999999),
            'bookmarks': model.summary.bookmarks.clamp(0, 999999),
          },
          'me': {
            'liked': isLiked,
            'bookmarked': isBookmarked,
          },
        };
        
        // Add repost_author for reposts to show "You reposted this"
        if (isRepost) {
          final repostFirstName = author?.firstName?.trim() ?? '';
          final repostLastName = author?.lastName?.trim() ?? '';
          final repostFullName = (repostFirstName.isNotEmpty || repostLastName.isNotEmpty)
              ? '$repostFirstName $repostLastName'.trim()
              : (author?.displayName ?? author?.username ?? 'User');
          
          mp['repost_author'] = {
            'name': repostFullName,
            'username': author?.username ?? '',
            'avatarUrl': author?.avatarUrl ?? '',
            'avatar_url': author?.avatarUrl ?? '',
          };
        }
        
        filtered.add(mp);
        
        // Fetch original post if it's a repost
        if (repostId != null && repostId.isNotEmpty) {
          final original = await postRepo.getPost(repostId);
          if (original != null) {
            final origAuthor = await userRepo.getUserProfile(original.authorId);
            // Build full name for original author in activity
            final actOrigFirstName = origAuthor?.firstName?.trim() ?? '';
            final actOrigLastName = origAuthor?.lastName?.trim() ?? '';
            final actOrigFullName = (actOrigFirstName.isNotEmpty || actOrigLastName.isNotEmpty)
                ? '$actOrigFirstName $actOrigLastName'.trim()
                : (origAuthor?.displayName ?? origAuthor?.username ?? 'User');
            
            originals[repostId] = {
              'id': original.id,
              'user_id': original.authorId,
              'user': {
                'name': actOrigFullName,
                'profile_photo_url': origAuthor?.avatarUrl ?? '',
              },
              'text': original.text,
              'media': original.mediaUrls,
              'created_at': original.createdAt.toIso8601String(),
            };
          }
        }
      }

      for (final p in filtered) {
        final ro = p['repost_of'];
        if (ro != null) {
          final op = originals[ro.toString()];
          if (op != null) p['original_post'] = op;
        }
      }

      final results = filtered.map(_mapRawPostToModel).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      
      setState(() {
        _activityPosts = results;
        _loadingActivity = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Error in _loadActivity: $e');
      debugPrint('Stack trace: $stack');
      
      if (!mounted) return;
      
      setState(() {
        _errorActivity = 'Failed to load activity: $e';
        _loadingActivity = false;
      });
    }
  }

  Future<void> _loadMyPodcasts() async {
    if (_myUserId == null || _myUserId!.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingPodcasts = false;
          _errorPodcasts = 'No user ID available';
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _loadingPodcasts = true;
        _errorPodcasts = null;
      });
    }

    try {
      final repo = context.read<PodcastRepository>();
      // Use mine=true to get user's own podcasts
      final models = await repo.listPodcasts(limit: 50, mine: true);
      
      if (!mounted) return;
      
      setState(() {
        _myPodcasts = models.map((p) => {
          'id': p.id,
          'title': p.title,
          'description': p.description,
          'coverUrl': p.coverUrl,
        }).toList();
        _loadingPodcasts = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Error in _loadMyPodcasts: $e');
      debugPrint('Stack trace: $stack');
      
      if (!mounted) return;
      
      setState(() {
        _errorPodcasts = 'Failed to load podcasts: $e';
        _loadingPodcasts = false;
      });
    }
  }

  bool _isWideLayout(BuildContext context) {
    return kIsWeb && (context.isDesktop || context.isLargeDesktop);
  }

  void _openPremium(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desktop = _isWideLayout(context);

    if (!desktop) {
      Navigator.push(
        context,
        MaterialPageRoute(settings: const RouteSettings(name: 'premium_subscription'), builder: (_) => const PremiumSubscriptionPage()),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 80,
            vertical: 60,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF000000) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Text(
                            Provider.of<LanguageProvider>(context).t('premium.title'),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: Provider.of<LanguageProvider>(context, listen: false).t('common.close'),
                            icon: Icon(
                              Icons.close,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Body
                    const Expanded(child: PremiumSubscriptionView()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.isDarkMode;
          final p = _profile ?? {};
          final String fullName = (() {
            final fn = (p['full_name'] ?? '').toString().trim();
            if (fn.isNotEmpty) return fn;
            final f = (p['first_name'] ?? '').toString().trim();
            final l = (p['last_name'] ?? '').toString().trim();
            if (f.isNotEmpty || l.isNotEmpty) return ('$f $l').trim();
            // Avoid showing email as the main display name; fall back to generic label
            return 'User';
          })();
          final String username = (p['username'] ?? '').toString().trim();
          final String atUsername = username.isNotEmpty ? '@$username' : '';
          final String? bioText = p['bio'] as String?;
          final String? coverUrl = (p['cover_photo_url'] as String?);
          final String? profileUrl = p['profile_photo_url'] as String?;
          final List<Map<String, dynamic>> experiences = _parseListOfMap(
            p['professional_experiences'],
          );
          final List<Map<String, dynamic>> trainings = _parseListOfMap(
            p['trainings'],
          );
          final List<String> interests = _parseStringList(
            p['interest_domains'],
          );
          if (_isWideLayout(context)) {
            return _buildDesktopProfile(context, isDark);
          }
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: isDark
                ? const Color(0xFF0C0C0C)
                : const Color(0xFFF1F4F8),
            endDrawer: _buildDrawer(),
            body: _loadingProfile
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Header with Cover Image
                        GestureDetector(
                          onTap: (coverUrl != null && coverUrl.isNotEmpty)
                              ? () => showExpandablePhoto(
                                    context: context,
                                    imageUrl: coverUrl,
                                    isProfilePhoto: false,
                                    heroTag: 'profile_cover_$_myUserId',
                                  )
                              : null,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.grey[200],
                              image: (coverUrl != null && coverUrl.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(coverUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Stack(
                            children: [
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () => scaffoldKey.currentState
                                            ?.openEndDrawer(),
                                        child: Icon(
                                          Icons.more_horiz,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (coverUrl == null || coverUrl.isEmpty)
                                Center(
                                  child: Text(
                                    Provider.of<LanguageProvider>(context, listen: false).t('profile.add_cover_image'),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF666666),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                            ),
                          ),
                        ), // Main Profile Card
                        Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF000000)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0)
                                    : Colors.black.withValues(alpha: 10),
                                blurRadius: 25,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Profile Avatar and Stats
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    // Avatar positioned to overlap cover
                                    Transform.translate(
                                      offset: const Offset(0, -50),
                                      child: GestureDetector(
                                        onTap: (profileUrl != null && profileUrl.isNotEmpty)
                                            ? () => showExpandablePhoto(
                                                  context: context,
                                                  imageUrl: profileUrl,
                                                  isProfilePhoto: true,
                                                  heroTag: 'profile_avatar_$_myUserId',
                                                  fallbackInitial: fullName.isNotEmpty ? fullName.substring(0, 1) : '?',
                                                )
                                            : null,
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF1F1F1F)
                                                  : Colors.white,
                                              width: 4,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 58,
                                            backgroundImage:
                                                (profileUrl != null &&
                                                    profileUrl.isNotEmpty)
                                                ? NetworkImage(profileUrl)
                                                : null,
                                            child:
                                                (profileUrl == null ||
                                                    profileUrl.isEmpty)
                                                ? Text(
                                                    (fullName.isNotEmpty
                                                            ? fullName.substring(
                                                                0,
                                                                1,
                                                              )
                                                            : '?')
                                                        .toUpperCase(),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 40,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Stats Row - Tap to navigate to My Connections
                                    Transform.translate(
                                      offset: const Offset(0, -30),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const MyConnectionsPage(),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildStatColumn(
                                              _formatCount(
                                                p['connections_inbound_count'],
                                              ),
                                              Provider.of<LanguageProvider>(context, listen: false).t('profile.connections_label'),
                                            ),
                                            const SizedBox(width: 40),
                                            _buildStatColumn(
                                              _formatCount(
                                                p['connections_outbound_count'],
                                              ),
                                              Provider.of<LanguageProvider>(context, listen: false).t('profile.connected_label'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Name and Bio
                                    Transform.translate(
                                      offset: const Offset(0, -20),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                fullName,
                                                style: GoogleFonts.inter(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.verified,
                                                color: Color(0xFFBFAE01),
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          if (atUsername.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                atUsername,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            bioText ?? '',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Action Buttons
                                    Transform.translate(
                                      offset: const Offset(0, -10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                final messenger = ScaffoldMessenger.of(context);
                                                final expItems = experiences
                                                    .map(
                                                      (e) => ExperienceItem(
                                                        title:
                                                            (e['title'] ?? '')
                                                                .toString(),
                                                        subtitle:
                                                            (e['subtitle']
                                                                    as String?)
                                                                ?.toString(),
                                                      ),
                                                    )
                                                    .toList();
                                                final trainItems = trainings
                                                    .map(
                                                      (t) => TrainingItem(
                                                        title:
                                                            (t['title'] ?? '')
                                                                .toString(),
                                                        subtitle:
                                                            (t['subtitle']
                                                                    as String?)
                                                                ?.toString(),
                                                      ),
                                                    )
                                                    .toList();

                                                bool canEditFullName = true;
                                                try {
                                                  final kyc = await FirebaseKycRepository().getMyKyc();
                                                  if (kyc == null) {
                                                    canEditFullName = true;
                                                  } else {
                                                    final status = (kyc.status).toLowerCase();
                                                    final isApproved = kyc.isApproved;
                                                    final isRejected = kyc.isRejected;
                                                    if (status == 'pending' || isApproved) {
                                                      canEditFullName = false;
                                                    } else if (isRejected) {
                                                      canEditFullName = true;
                                                    } else {
                                                      canEditFullName = false;
                                                    }
                                                  }
                                                } catch (_) {
                                                  canEditFullName = true;
                                                }

                                                final page = EditProfilPage(
                                                  fullName: fullName,
                                                  canEditFullName:
                                                      canEditFullName,
                                                  username:
                                                      (p['username'] ?? '')
                                                          .toString(),
                                                  bio: bioText ?? '',
                                                  profilePhotoUrl: profileUrl,
                                                  coverPhotoUrl: coverUrl,
                                                  experiences: expItems,
                                                  trainings: trainItems,
                                                  interests: interests,
                                                );

                                                final dialogContext = context;
                                                if (!dialogContext.mounted) return;
                                                final isWide = _isWideLayout(dialogContext);
                                                ProfileEditResult? result;
                                                if (isWide) {
                                                  result = await showDialog<ProfileEditResult>(
                                                    context: dialogContext,
                                                    barrierDismissible: true,
                                                    builder: (_) {
                                                      return Dialog(
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        insetPadding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 80,
                                                              vertical: 60,
                                                            ),
                                                        child: Center(
                                                          child: ConstrainedBox(
                                                            constraints:
                                                                const BoxConstraints(
                                                                  maxWidth: 980,
                                                                  maxHeight:
                                                                      760,
                                                                ),
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                              child: Material(
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF000000,
                                                                      )
                                                                    : Colors
                                                                          .white,
                                                                child: page,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  result =
                                                      await Navigator.push<
                                                        ProfileEditResult
                                                      >(
                                                        dialogContext,
                                                        MaterialPageRoute(
                                                          settings: const RouteSettings(name: 'edit_profile'),
                                                          builder: (_) => page,
                                                        ),
                                                      );
                                                }

                                                if (!mounted) return;
                                                final r = result;
                                                if (r == null) return;
                                                
                                                final api = ProfileApi();

                                                try {
                                                  if (r.profileImagePath !=
                                                          null &&
                                                      r.profileImagePath!
                                                          .isNotEmpty) {
                                                    await api
                                                        .uploadAndAttachProfilePhoto(
                                                      File(r.profileImagePath!),
                                                    );
                                                  } else if ((r.profileImageUrl ==
                                                          null ||
                                                      r.profileImageUrl!
                                                          .isEmpty) &&
                                                      (p['profile_photo_url'] !=
                                                          null)) {
                                                    await api.update({
                                                      'profile_photo_url': null,
                                                    });
                                                  }

                                                  if (r.coverImagePath !=
                                                          null &&
                                                      r.coverImagePath!
                                                          .isNotEmpty) {
                                                    await api
                                                        .uploadAndAttachCoverPhoto(
                                                      File(r.coverImagePath!),
                                                    );
                                                  } else if ((r.coverImageUrl ==
                                                          null ||
                                                      r.coverImageUrl!
                                                          .isEmpty) &&
                                                      (p['cover_photo_url'] !=
                                                          null)) {
                                                    await api.update({
                                                      'cover_photo_url': null,
                                                    });
                                                  }
                                                } catch (_) {}

                                                final updates =
                                                    <String, dynamic>{};

                                                final newFullName = r.fullName
                                                    .trim();
                                                if (newFullName.isNotEmpty &&
                                                    newFullName !=
                                                        fullName.trim()) {
                                                  final parts = newFullName
                                                      .split(RegExp(r'\s+'));
                                                  final firstName =
                                                      parts.isNotEmpty
                                                      ? parts.first
                                                      : '';
                                                  final lastName =
                                                      parts.length > 1
                                                      ? parts
                                                              .sublist(1)
                                                              .join(' ')
                                                      : '';
                                                  if (firstName.isNotEmpty) {
                                                    updates['first_name'] =
                                                        firstName;
                                                  }
                                                  updates['last_name'] =
                                                      lastName;
                                                }

                                                final newUsername = r.username
                                                    .trim();
                                                if (newUsername.isNotEmpty &&
                                                    newUsername !=
                                                        (p['username'] ?? '')) {
                                                  updates['username'] =
                                                      newUsername;
                                                }
                                                updates['bio'] = r.bio;

                                                updates['professional_experiences'] =
                                                    r.experiences.map((e) {
                                                  final m = <String, dynamic>{
                                                    'title': e.title,
                                                  };
                                                  if ((e.subtitle ?? '')
                                                      .trim()
                                                      .isNotEmpty) {
                                                    m['subtitle'] = e.subtitle;
                                                  }
                                                  return m;
                                                }).toList();

                                                updates['trainings'] = r
                                                    .trainings
                                                    .map((t) {
                                                  final m = <String, dynamic>{
                                                    'title': t.title,
                                                  };
                                                  if ((t.subtitle ?? '')
                                                      .trim()
                                                      .isNotEmpty) {
                                                    m['subtitle'] = t.subtitle;
                                                  }
                                                  return m;
                                                }).toList();

                                                updates['interest_domains'] =
                                                    r.interests;

                                                // INSTANT: Update UI immediately with new data (optimistic update)
                                                if (mounted) {
                                                  setState(() {
                                                    // Apply updates to local profile map instantly
                                                    final updated = Map<String, dynamic>.from(_profile ?? {});
                                                    if (updates['first_name'] != null) {
                                                      updated['first_name'] = updates['first_name'];
                                                    }
                                                    if (updates['last_name'] != null) {
                                                      updated['last_name'] = updates['last_name'];
                                                    }
                                                    if (updates['username'] != null) {
                                                      updated['username'] = updates['username'];
                                                    }
                                                    if (updates['bio'] != null) {
                                                      updated['bio'] = updates['bio'];
                                                    }
                                                    if (updates['interest_domains'] != null) {
                                                      updated['interest_domains'] = updates['interest_domains'];
                                                    }
                                                    if (updates['professional_experiences'] != null) {
                                                      updated['professional_experiences'] = updates['professional_experiences'];
                                                    }
                                                    if (updates['trainings'] != null) {
                                                      updated['trainings'] = updates['trainings'];
                                                    }
                                                    // Update full_name
                                                    final fn = updated['first_name'] ?? '';
                                                    final ln = updated['last_name'] ?? '';
                                                    updated['full_name'] = '$fn $ln'.trim();
                                                    _profile = updated;
                                                  });
                                                  
                                                  // Show success immediately
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(Provider.of<LanguageProvider>(context, listen: false).t('profile.updated')),
                                                      backgroundColor: Colors.green,
                                                      duration: Duration(seconds: 2),
                                                    ),
                                                  );
                                                }
                                                
                                                // BACKGROUND: Save to server without blocking UI
                                                () async {
                                                  try {
                                                    // Sync interests with community memberships
                                                    await CommunityInterestSyncService().syncUserInterests(
                                                      r.interests, 
                                                      oldInterests: interests,
                                                    );
                                                    
                                                    // Save to server
                                                    await api.update(updates);
                                                    
                                                    // Refresh cache for next time
                                                    final user = fb.FirebaseAuth.instance.currentUser;
                                                    if (user != null) {
                                                      ProfileCacheService().preloadCurrentUserData(user.uid);
                                                    }
                                                  } catch (e) {
                                                    debugPrint('⚠️ Background profile save error: $e');
                                                  }
                                                }();
                                                                                            },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFBFAE01,
                                                ),
                                                foregroundColor: isDark
                                                    ? Colors.black
                                                    : Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                              ),
                                              child: Text(
                                                Provider.of<LanguageProvider>(context, listen: false).t('profile.edit_profile'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.black
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                if (_isWideLayout(context)) {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: true,
                                                    builder: (_) {
                                                      return Dialog(
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        insetPadding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 80,
                                                              vertical: 60,
                                                            ),
                                                        child: Center(
                                                          child: ConstrainedBox(
                                                            constraints:
                                                                const BoxConstraints(
                                                                  maxWidth: 980,
                                                                  maxHeight:
                                                                      760,
                                                                ),
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                              child: Material(
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF000000,
                                                                      )
                                                                    : Colors
                                                                          .white,
                                                                child:
                                                                    const MyConnectionsPage(),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      settings: const RouteSettings(name: 'my_connections'),
                                                      builder: (_) =>
                                                          const MyConnectionsPage(),
                                                    ),
                                                  );
                                                }
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                                side: BorderSide(
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Text(
                                                Provider.of<LanguageProvider>(context, listen: false).t('profile.my_connections'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.grey[300]!,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(40),
                                            ),
                                            child: Icon(
                                              Icons.person_add_outlined,
                                              size: 20,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Professional Experiences Section (hidden for admin)
                              if (!AdminConfig.isAdmin(_myUserId))
                                Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.work,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Provider.of<LanguageProvider>(context, listen: false).t('profile.professional_experiences'),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (experiences.isEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          Provider.of<LanguageProvider>(context).t('profile.no_experiences'),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),

                                    if (experiences.isNotEmpty)
                                      ...experiences.map(
                                        (exp) => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                (exp['title'] ?? '').toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if ((exp['subtitle'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  (exp['subtitle'] ?? '')
                                                      .toString(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                              // Trainings Section (hidden for admin)
                              if (!AdminConfig.isAdmin(_myUserId))
                                Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.school,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Provider.of<LanguageProvider>(context, listen: false).t('profile.trainings'),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (trainings.isEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          Provider.of<LanguageProvider>(context).t('profile.no_trainings'),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    if (trainings.isNotEmpty)
                                      ...trainings.map(
                                        (tr) => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                (tr['title'] ?? '').toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if ((tr['subtitle'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  (tr['subtitle'] ?? '')
                                                      .toString(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                              // Interest Section (hidden for admin)
                              if (!AdminConfig.isAdmin(_myUserId))
                                Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Provider.of<LanguageProvider>(context, listen: false).t('profile.interest'),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: interests.isNotEmpty
                                          ? interests
                                                .map(
                                                  (i) => _buildInterestChip(i),
                                                )
                                                .toList()
                                          : [
                                              Text(
                                                Provider.of<LanguageProvider>(context).t('profile.no_interests'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tab Section
                        _buildTabSection(),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopTopNav(BuildContext context, bool isDark) {
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
              // Row: burger | title | notifications
              Row(
                children: [
                  const Icon(Icons.menu, color: Color(0xFF666666)),
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
                    badgeCount: _unreadNotifications,
                    iconColor: const Color(0xFF666666),
                    onTap: () async {
                      if (_isWideLayout(context)) {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.black26,
                          builder: (_) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final size = MediaQuery.of(context).size;
                            final double width = 420;
                            final double height = size.height * 0.8;

                            return SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 16,
                                    right: 16,
                                  ),
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
                            builder: (_) => const NotificationPage(),
                          ),
                        );
                      }
                      if (!mounted) return;
                      await _loadUnreadNotifications();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Top nav row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _navButton(
                    isDark,
                    icon: Icons.home_outlined,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.home'),
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  _navButton(
                    isDark,
                    icon: Icons.people_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.connections'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'connections'),
                          builder: (_) => const ConnectionsPage(),
                        ),
                      );
                    },
                  ),
                  _navButton(
                    isDark,
                    icon: Icons.chat_bubble_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.conversations'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'conversations'),
                          builder: (_) => ConversationsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            initialTabIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  _navButton(
                    isDark,
                    icon: Icons.person_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.profile'),
                    selected: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(
    bool isDark, {
    required IconData icon,
    required String label,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final color = selected ? const Color(0xFFBFAE01) : const Color(0xFF666666);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }

  Widget _buildDesktopProfile(BuildContext context, bool isDark) {
    if (_loadingProfile) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: isDark
            ? const Color(0xFF0C0C0C)
            : const Color(0xFFF1F4F8),
        endDrawer: _buildDrawer(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = _profile ?? {};
    final String fullName = (() {
      final fn = (p['full_name'] ?? '').toString().trim();
      if (fn.isNotEmpty) return fn;
      final f = (p['first_name'] ?? '').toString().trim();
      final l = (p['last_name'] ?? '').toString().trim();
      if (f.isNotEmpty || l.isNotEmpty) return ('$f $l').trim();
      return 'User';
    })();
    final String username = (p['username'] ?? '').toString().trim();
    final String atUsername = username.isNotEmpty ? '@$username' : '';
    final String? bioText = p['bio'] as String?;
    final String? coverUrl = (p['cover_photo_url'] as String?);
    final String? profileUrl = p['profile_photo_url'] as String?;
    final List<Map<String, dynamic>> experiences = _parseListOfMap(
      p['professional_experiences'],
    );
    final List<Map<String, dynamic>> trainings = _parseListOfMap(
      p['trainings'],
    );
    final List<String> interests = _parseStringList(p['interest_domains']);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: isDark
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          if (!widget.hideDesktopTopNav) _buildDesktopTopNav(context, isDark),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: Profile card + Pro experience + Trainings + Interest
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Cover
                              GestureDetector(
                                onTap: (coverUrl != null && coverUrl.isNotEmpty)
                                    ? () => showExpandablePhoto(
                                          context: context,
                                          imageUrl: coverUrl,
                                          isProfilePhoto: false,
                                          heroTag: 'profile_cover_desktop_$_myUserId',
                                        )
                                    : null,
                                child: Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A1A1A)
                                        : Colors.grey[200],
                                    image:
                                        (coverUrl != null && coverUrl.isNotEmpty)
                                        ? DecorationImage(
                                            image: NetworkImage(coverUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      SafeArea(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              InkWell(
                                                onTap: () => scaffoldKey
                                                    .currentState
                                                    ?.openEndDrawer(),
                                                child: Icon(
                                                  Icons.more_horiz,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (coverUrl == null || coverUrl.isEmpty)
                                        Center(
                                          child: Text(
                                            Provider.of<LanguageProvider>(context, listen: false).t('profile.add_cover_image'),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF666666),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // Main Profile Card
                              Container(
                                margin: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF000000)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0)
                                          : Colors.black.withValues(alpha: 10),
                                      blurRadius: 25,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Profile Avatar and Stats
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          // Avatar positioned to overlap cover
                                          Transform.translate(
                                            offset: const Offset(0, -50),
                                            child: GestureDetector(
                                              onTap: (profileUrl != null && profileUrl.isNotEmpty)
                                                  ? () => showExpandablePhoto(
                                                        context: context,
                                                        imageUrl: profileUrl,
                                                        isProfilePhoto: true,
                                                        heroTag: 'profile_avatar_desktop_$_myUserId',
                                                        fallbackInitial: fullName.isNotEmpty ? fullName.substring(0, 1) : '?',
                                                      )
                                                  : null,
                                              child: Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(0xFF1F1F1F)
                                                        : Colors.white,
                                                    width: 4,
                                                  ),
                                                ),
                                                child: CircleAvatar(
                                                  radius: 58,
                                                  backgroundImage:
                                                      (profileUrl != null &&
                                                          profileUrl.isNotEmpty)
                                                      ? NetworkImage(profileUrl)
                                                      : null,
                                                  child:
                                                      (profileUrl == null ||
                                                          profileUrl.isEmpty)
                                                      ? Text(
                                                          (fullName.isNotEmpty
                                                                  ? fullName
                                                                        .substring(
                                                                          0,
                                                                          1,
                                                                        )
                                                                  : '?')
                                                              .toUpperCase(),
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize: 40,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: isDark
                                                                    ? Colors.white
                                                                    : Colors
                                                                          .black,
                                                              ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Stats Row - Tap to navigate to My Connections
                                          Transform.translate(
                                            offset: const Offset(0, -30),
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => const MyConnectionsPage(),
                                                  ),
                                                );
                                              },
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  _buildStatColumn(
                                                    _formatCount(
                                                      p['connections_inbound_count'],
                                                    ),
                                                    Provider.of<LanguageProvider>(context, listen: false).t('profile.connections_label'),
                                                  ),
                                                  const SizedBox(width: 40),
                                                  _buildStatColumn(
                                                    _formatCount(
                                                      p['connections_outbound_count'],
                                                    ),
                                                    Provider.of<LanguageProvider>(context, listen: false).t('profile.connected_label'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Name and Bio
                                          Transform.translate(
                                            offset: const Offset(0, -20),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      fullName,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(
                                                      Icons.verified,
                                                      color: Color(0xFFBFAE01),
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                                if (atUsername.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      atUsername,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  bioText ?? '',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.grey[600],
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Action Buttons
                                          Transform.translate(
                                            offset: const Offset(0, -10),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      final messenger = ScaffoldMessenger.of(context);
                                                      final expItems = experiences
                                                          .map(
                                                            (
                                                              e,
                                                            ) => ExperienceItem(
                                                              title:
                                                                  (e['title'] ??
                                                                          '')
                                                                      .toString(),
                                                              subtitle:
                                                                  (e['subtitle']
                                                                          as String?)
                                                                      ?.toString(),
                                                            ),
                                                          )
                                                          .toList();
                                                      final trainItems = trainings
                                                          .map(
                                                            (t) => TrainingItem(
                                                              title:
                                                                  (t['title'] ??
                                                                          '')
                                                                      .toString(),
                                                              subtitle:
                                                                  (t['subtitle']
                                                                          as String?)
                                                                      ?.toString(),
                                                            ),
                                                          )
                                                          .toList();

                                                      bool canEditFullName = true;
                                                      try {
                                                        final kyc = await FirebaseKycRepository().getMyKyc();
                                                        if (kyc == null) {
                                                          canEditFullName = true;
                                                        } else {
                                                          final status = (kyc.status).toLowerCase();
                                                          final isApproved = kyc.isApproved;
                                                          final isRejected = kyc.isRejected;
                                                          if (status == 'pending' || isApproved) {
                                                            canEditFullName = false;
                                                          } else if (isRejected) {
                                                            canEditFullName = true;
                                                          } else {
                                                            canEditFullName = false;
                                                          }
                                                        }
                                                      } catch (_) {
                                                        canEditFullName = true;
                                                      }

                                                      final page =
                                                          EditProfilPage(
                                                            fullName: fullName,
                                                            canEditFullName:
                                                                canEditFullName,
                                                            username:
                                                                (p['username'] ??
                                                                        '')
                                                                    .toString(),
                                                            bio: bioText ?? '',
                                                            profilePhotoUrl:
                                                                profileUrl,
                                                            coverPhotoUrl:
                                                                coverUrl,
                                                            experiences:
                                                                expItems,
                                                            trainings:
                                                                trainItems,
                                                            interests:
                                                                interests,
                                                          );

                                                      final dialogContext = context;
                                                      if (!dialogContext.mounted) return;
                                                      final isWide = _isWideLayout(dialogContext);
                                                      ProfileEditResult? result;
                                                      if (isWide) {
                                                        result = await showDialog<ProfileEditResult>(
                                                          context: dialogContext,
                                                          barrierDismissible:
                                                              true,
                                                          builder: (_) {
                                                            return Dialog(
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              insetPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        80,
                                                                    vertical:
                                                                        60,
                                                                  ),
                                                              child: Center(
                                                                child: ConstrainedBox(
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxWidth:
                                                                            980,
                                                                        maxHeight:
                                                                            760,
                                                                      ),
                                                                  child: ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                    child: Material(
                                                                      color:
                                                                          isDark
                                                                          ? const Color(
                                                                              0xFF000000,
                                                                            )
                                                                          : Colors.white,
                                                                      child:
                                                                          page,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      } else {
                                                        result =
                                                            await Navigator.push<
                                                              ProfileEditResult
                                                            >(
                                                              dialogContext,
                                                              MaterialPageRoute(
                                                                settings: const RouteSettings(name: 'edit_profile'),
                                                                builder: (_) =>
                                                                    page,
                                                              ),
                                                            );
                                                      }

                                                      if (!mounted) return;
                                                      final r = result;
                                                      if (r == null) return;
                                                      
                                                      final api = ProfileApi();

                                                      try {
                                                        if (r.profileImagePath !=
                                                                null &&
                                                            r.profileImagePath!
                                                                .isNotEmpty) {
                                                          await api
                                                              .uploadAndAttachProfilePhoto(
                                                            File(r.profileImagePath!),
                                                          );
                                                        } else if ((r.profileImageUrl ==
                                                                null ||
                                                            r.profileImageUrl!
                                                                .isEmpty) &&
                                                            (p['profile_photo_url'] !=
                                                                null)) {
                                                          await api.update({
                                                            'profile_photo_url':
                                                                null,
                                                          });
                                                        }

                                                        if (r.coverImagePath !=
                                                                null &&
                                                            r.coverImagePath!
                                                                .isNotEmpty) {
                                                          await api
                                                              .uploadAndAttachCoverPhoto(
                                                            File(r.coverImagePath!),
                                                          );
                                                        } else if ((r.coverImageUrl ==
                                                                null ||
                                                            r.coverImageUrl!
                                                                .isEmpty) &&
                                                            (p['cover_photo_url'] !=
                                                                null)) {
                                                          await api.update({
                                                            'cover_photo_url':
                                                                null,
                                                          });
                                                        }
                                                      } catch (_) {}

                                                      final updates =
                                                          <String, dynamic>{};

                                                      final newFullName = r.fullName
                                                          .trim();
                                                      if (newFullName.isNotEmpty &&
                                                          newFullName !=
                                                              fullName.trim()) {
                                                        final parts = newFullName
                                                            .split(RegExp(r'\s+'));
                                                        final firstName =
                                                            parts.isNotEmpty
                                                            ? parts.first
                                                            : '';
                                                        final lastName =
                                                            parts.length > 1
                                                            ? parts
                                                                    .sublist(1)
                                                                    .join(' ')
                                                            : '';
                                                        if (firstName.isNotEmpty) {
                                                          updates['first_name'] =
                                                              firstName;
                                                        }
                                                        updates['last_name'] =
                                                            lastName;
                                                      }

                                                      final newUsername = r.username
                                                          .trim();
                                                      if (newUsername.isNotEmpty &&
                                                          newUsername !=
                                                              (p['username'] ??
                                                                  '')) {
                                                        updates['username'] =
                                                            newUsername;
                                                      }
                                                      updates['bio'] = r.bio;

                                                      updates['professional_experiences'] =
                                                          r.experiences.map((e) {
                                                        final m = <String, dynamic>{
                                                          'title': e.title,
                                                        };
                                                        if ((e.subtitle ?? '')
                                                            .trim()
                                                            .isNotEmpty) {
                                                          m['subtitle'] = e.subtitle;
                                                        }
                                                        return m;
                                                      }).toList();

                                                      updates['trainings'] = r.trainings.map((t) {
                                                        final m = <String, dynamic>{'title': t.title};
                                                        if ((t.subtitle ?? '').trim().isNotEmpty) {
                                                          m['subtitle'] = t.subtitle;
                                                        }
                                                        return m;
                                                      }).toList();

                                                      updates['interest_domains'] = r.interests;

                                                      // INSTANT: Update UI immediately with new data (optimistic update)
                                                      if (mounted) {
                                                        setState(() {
                                                          final updated = Map<String, dynamic>.from(_profile ?? {});
                                                          if (updates['first_name'] != null) {
                                                            updated['first_name'] = updates['first_name'];
                                                          }
                                                          if (updates['last_name'] != null) {
                                                            updated['last_name'] = updates['last_name'];
                                                          }
                                                          if (updates['username'] != null) {
                                                            updated['username'] = updates['username'];
                                                          }
                                                          if (updates['bio'] != null) {
                                                            updated['bio'] = updates['bio'];
                                                          }
                                                          if (updates['interest_domains'] != null) {
                                                            updated['interest_domains'] = updates['interest_domains'];
                                                          }
                                                          if (updates['professional_experiences'] != null) {
                                                            updated['professional_experiences'] = updates['professional_experiences'];
                                                          }
                                                          if (updates['trainings'] != null) {
                                                            updated['trainings'] = updates['trainings'];
                                                          }
                                                          final fn = updated['first_name'] ?? '';
                                                          final ln = updated['last_name'] ?? '';
                                                          updated['full_name'] = '$fn $ln'.trim();
                                                          _profile = updated;
                                                        });
                                                        
                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('profile.updated')),
                                                            backgroundColor: Colors.green,
                                                            duration: Duration(seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                      
                                                      // BACKGROUND: Save to server without blocking UI
                                                      () async {
                                                        try {
                                                          await CommunityInterestSyncService().syncUserInterests(
                                                            r.interests, 
                                                            oldInterests: interests,
                                                          );
                                                          await api.update(updates);
                                                          final user = fb.FirebaseAuth.instance.currentUser;
                                                          if (user != null) {
                                                            ProfileCacheService().preloadCurrentUserData(user.uid);
                                                          }
                                                        } catch (e) {
                                                          debugPrint('⚠️ Background profile save error: $e');
                                                        }
                                                      }();
                                                                                                        },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                            0xFFBFAE01,
                                                          ),
                                                      foregroundColor: isDark
                                                          ? Colors.black
                                                          : Colors.black,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              25,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      Provider.of<LanguageProvider>(context, listen: false).t('profile.edit_profile'),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isDark
                                                            ? Colors.black
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      if (_isWideLayout(
                                                        context,
                                                      )) {
                                                        showDialog(
                                                          context: context,
                                                          barrierDismissible:
                                                              true,
                                                          builder: (_) {
                                                            return Dialog(
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              insetPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        80,
                                                                    vertical:
                                                                        60,
                                                                  ),
                                                              child: Center(
                                                                child: ConstrainedBox(
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxWidth:
                                                                            980,
                                                                        maxHeight:
                                                                            760,
                                                                      ),
                                                                  child: ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                    child: Material(
                                                                      color:
                                                                          isDark
                                                                          ? const Color(
                                                                              0xFF000000,
                                                                            )
                                                                          : Colors.white,
                                                                      child:
                                                                          const MyConnectionsPage(),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      } else {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            settings: const RouteSettings(name: 'my_connections'),
                                                            builder: (_) =>
                                                                const MyConnectionsPage(),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    style: OutlinedButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              25,
                                                            ),
                                                      ),
                                                      side: BorderSide(
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.grey[300]!,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      Provider.of<LanguageProvider>(context, listen: false).t('profile.my_connections'),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.grey[300]!,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          40,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.person_add_outlined,
                                                    size: 20,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Professional Experiences Section (hidden for admin)
                                    if (!AdminConfig.isAdmin(_myUserId))
                                      Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.work,
                                                size: 20,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                Provider.of<LanguageProvider>(context, listen: false).t('profile.professional_experiences'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (experiences.isEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                Provider.of<LanguageProvider>(context).t('profile.no_experiences'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          if (experiences.isNotEmpty)
                                            ...experiences.map(
                                              (exp) => Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      (exp['title'] ?? '')
                                                          .toString(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if ((exp['subtitle'] ?? '')
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                                    Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        (exp['subtitle'] ?? '')
                                                            .toString(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors
                                                                    .grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    ),

                                    // Trainings Section (hidden for admin)
                                    if (!AdminConfig.isAdmin(_myUserId))
                                      Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.school,
                                                size: 20,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                Provider.of<LanguageProvider>(context, listen: false).t('profile.trainings'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (trainings.isEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                Provider.of<LanguageProvider>(context).t('profile.no_trainings'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          if (trainings.isNotEmpty)
                                            ...trainings.map(
                                              (tr) => Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      (tr['title'] ?? '')
                                                          .toString(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if ((tr['subtitle'] ?? '')
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                                    Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        (tr['subtitle'] ?? '')
                                                            .toString(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors
                                                                    .grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    ),

                                    // Interest Section (hidden for admin)
                                    if (!AdminConfig.isAdmin(_myUserId))
                                      Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.favorite,
                                                size: 20,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                Provider.of<LanguageProvider>(context, listen: false).t('profile.interest'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: interests.isNotEmpty
                                                ? interests
                                                      .map(
                                                        (i) =>
                                                            _buildInterestChip(
                                                              i,
                                                            ),
                                                      )
                                                      .toList()
                                                : [
                                                    Text(
                                                      Provider.of<LanguageProvider>(context).t('profile.no_interests'),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Right column: Tabs (Activity, Posts, Podcasts, Media)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(children: [_buildTabSection()]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Drawer menu
  Widget _buildDrawer() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Drawer(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Ionicons.document_text_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context).t('profile.menu.drafts'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'drafts'),
                        builder: (context) => const DraftsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Ionicons.bookmark_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context).t('profile.menu.bookmarks'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'bookmarks'),
                        builder: (context) => const BookmarksPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Ionicons.settings_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context).t('profile.menu.settings'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'settings'),
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Ionicons.cash_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('profile.monetization'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'monetization'),
                        builder: (_) => const MonetizationPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Ionicons.diamond_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context).t('premium.title'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openPremium(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Ionicons.bar_chart_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('profile.insights'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'insights'),
                        builder: (context) => const InsightsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Ionicons.musical_notes_outline,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('story_music.title'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'story_music'),
                        builder: (context) => const StoryMusicListPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Ionicons.moon_outline,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('profile.dark_mode'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                        activeThumbColor: const Color(0xFFBFAE01),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(name: 'help_center'),
                              builder: (context) => const HelpCenterPage(),
                            ),
                          );
                        },
                        child: Text(
                          Provider.of<LanguageProvider>(context).t('profile.menu.help_center'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(name: 'support'),
                              builder: (context) => const SupportPage(),
                            ),
                          );
                        },
                        child: Text(
                          Provider.of<LanguageProvider>(context).t('profile.menu.support'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                Provider.of<LanguageProvider>(context, listen: false).t('profile.menu.terms'),
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          Provider.of<LanguageProvider>(context).t('profile.menu.terms'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 22,
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context).t('common.logout'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () async {
                    final navContext = context;
                    Navigator.pop(navContext);
                    // Sign out with Firebase Auth
                    await fb.FirebaseAuth.instance.signOut();
                    if (!navContext.mounted) return;
                    Navigator.of(
                      navContext,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(settings: const RouteSettings(name: 'sign_in'), builder: (_) => const SignInPage()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper: Stats column
  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Helper: Interest chip
  Widget _buildInterestChip(String label) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white70 : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }

  // Helper: Tab section
  Widget _buildTabSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F1F1F)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF000000) : Colors.black,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white70 : Colors.white,
                  unselectedLabelColor: isDark
                      ? Colors.white70
                      : const Color(0xFF666666),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: [
                    Tab(text: Provider.of<LanguageProvider>(context).t('profile.tabs.activity')),
                    Tab(text: Provider.of<LanguageProvider>(context).t('profile.tabs.posts')),
                    Tab(text: Provider.of<LanguageProvider>(context).t('profile.tabs.podcasts')),
                    Tab(text: Provider.of<LanguageProvider>(context).t('profile.tabs.media')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 650,
                child: TabBarView(
                  children: [
                    _buildActivityTab(),
                    _buildPostsTab(),
                    _buildPodcastsTab(),
                    _buildMediaTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCommentsSheet(String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    
    CommentBottomSheet.show(
      context,
      postId: postId,
      comments: const [], // Empty - will load inside the sheet
      currentUserId: currentUserId,
      isDarkMode: isDark,
    );
  }

  Widget _buildActivityTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadingActivity) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorActivity != null) {
      return Center(
        child: Text(
          _errorActivity!,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
      );
    }

    if (_activityPosts.isEmpty) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        children: [
          Center(
            child: Text(
              Provider.of<LanguageProvider>(context).t('profile.no_activity'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF666666),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _activityScrollController,
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _activityPosts.length + (_isLoadingMoreActivity ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index == _activityPosts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final post = _activityPosts[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/post',
              arguments: {'postId': post.id},
            );
          },
          child: PostCard(
            post: post,
            isDarkMode: isDark,
            onReactionChanged: (postId, reaction) {},
            onBookmarkToggle: (postId) {},
            onShare: (postId) {},
            onComment: (postId) => _openCommentsSheet(postId),
            onRepost: (postId) {},
          ),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadingMyPosts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMyPosts != null) {
      return Center(
        child: Text(
          _errorMyPosts!,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
      );
    }

    if (_myPosts.isEmpty) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        children: [
          Center(
            child: Text(
              Provider.of<LanguageProvider>(context).t('profile.no_posts'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF666666),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _postsScrollController,
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _myPosts.length + (_isLoadingMorePosts ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index == _myPosts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final post = _myPosts[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/post',
              arguments: {'postId': post.id},
            );
          },
          child: HomePostCard(
            post: post,
            isDarkMode: isDark,
            onReactionChanged: (postId, reaction) {},
            onBookmarkToggle: (postId) {},
            onShare: (postId) {},
            onComment: (postId) => _openCommentsSheet(postId),
            onRepost: (postId) {},
          ),
        );
      },
    );
  }

  Widget _buildPodcastsTab() {
    if (_loadingPodcasts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPodcasts != null) {
      return Center(child: Text(_errorPodcasts!));
    }
    if (_myPodcasts.isEmpty) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.all(16),
        children: [Center(child: Text(Provider.of<LanguageProvider>(context).t('profile.no_podcasts')))],
      );
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: _myPodcasts.length,
      itemBuilder: (context, i) {
        final p = _myPodcasts[i];
        final podcastId = (p['id'] ?? '').toString();
        final title = (p['title'] ?? '').toString();
        final episode = (p['description'] ?? '').toString();
        final durationSec = (p['durationSec'] is num)
            ? (p['durationSec'] as num).toInt()
            : null;
        final duration = durationSec != null ? '${durationSec ~/ 60} min' : '';
        final imageUrl = ((p['coverUrl'] ?? '') as String).isNotEmpty
            ? (p['coverUrl'] as String)
            : 'https://via.placeholder.com/300x300.png?text=Podcast';
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/podcast',
              arguments: {'podcastId': podcastId},
            );
          },
          child: _buildPodcastItem(title, episode, duration, imageUrl),
        );
      },
    );
  }

  Widget _buildPodcastItem(
    String title,
    String episode,
    String duration,
    String imageUrl,
  ) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1F1F1F)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, size: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_loadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_mediaItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No media posts yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: isDark ? Colors.white70 : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }
    return GridView.count(
      primary: false,
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: _mediaItems.map((item) {
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/post',
              arguments: {'postId': item['postId']},
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: item['imageUrl']!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                child: Icon(
                  Icons.broken_image_outlined,
                  color: isDark ? Colors.white30 : Colors.black26,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
