import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'widgets/post_card.dart';
import 'widgets/message_invite_card.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'core/post_events.dart';
import 'my_connections_page.dart';
import 'models/post.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'repositories/interfaces/user_repository.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/firebase/firebase_podcast_repository.dart';
import 'repositories/models/post_model.dart';
import 'providers/follow_state.dart';
import 'models/message.dart' hide MediaType;
import 'widgets/report_bottom_sheet.dart';
import 'chat_page.dart';
import 'shared_media_page.dart';
import 'post_page.dart';
import 'widgets/expandable_photo_viewer.dart';
import 'core/admin_config.dart';


class OtherUserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String userBio;
  final String userCoverUrl;
  final bool isConnected;
  final bool theyConnectToYou;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.userBio,
    this.userCoverUrl = '',
    this.isConnected = false,
    this.theyConnectToYou = false,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late ConversationRepository _convRepo;

  // Backend profile data for OTHER user
  // FASTFEED: Initialize with widget data so it displays instantly
  late Map<String, dynamic>? _userProfile = {
    'id': widget.userId,
    'displayName': widget.userName,
    'avatarUrl': widget.userAvatarUrl,
    'bio': widget.userBio,
    'coverUrl': widget.userCoverUrl,
  };
  late String? _profilePhotoUrl = widget.userAvatarUrl;
  late String _coverPhotoUrl = widget.userCoverUrl;

  int _followersCount = 0;
  int _followingCount = 0;

  final List<Map<String, dynamic>> _experiences = [];
  final List<Map<String, dynamic>> _trainings = [];
  final List<String> _interests = [];


  // Data: Activity (their engagements), Posts (created by other user), Media (images from posts), Podcasts
  // FASTFEED: Start with false - cache loads instantly before first paint feels slow
  List<Post> _activityPosts = [];
  bool _loadingActivity = false;
  String? _errorActivity;
  bool _isLoadingMoreActivity = false;
  final ScrollController _activityScrollController = ScrollController();

  List<Post> _userPosts = [];
  bool _loadingPosts = false;
  String? _errorPosts;
  bool _isLoadingMorePosts = false;
  final ScrollController _postsScrollController = ScrollController();

  List<Map<String, dynamic>> _mediaItems = []; // {imageUrl, postId, imageCount, isVideo}
  bool _loadingMedia = false;
  
  // Author profile cache for hydration (same pattern as home feed)
  final Map<String, Map<String, String>> _authorProfilesCache = {};
  final Map<String, PostModel> _hydratedOriginalPosts = {};
  final FirebasePostRepository _postRepo = FirebasePostRepository();

  List<Map<String, dynamic>> _podcasts = [];
  bool _loadingPodcasts = false;
  String? _errorPodcasts;
  
  // Cache for user profiles to avoid redundant fetches
  final Map<String, dynamic> _userProfileCache = {};

  // Shared media counts
  int _sharedMediaCount = 0;
  int _sharedLinksCount = 0;
  int _sharedDocsCount = 0;

  @override
  void initState() {
    super.initState();
    _convRepo = context.read<ConversationRepository>();
    // Ensure FollowState is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FollowState>().initialize();
      }
    });
    
    // FASTFEED: Load cached data instantly, then refresh from server
    _loadFromCacheInstantly();
    
    // Load profile first so header and stats use real backend
    _loadUserProfile();
    // Kick off tabs
    _loadUserPosts();     // posts authored by this user (with repost hydration)
    _loadActivity();      // "their activity": likes/bookmarks/reposts they did
    _loadPodcasts();      // podcasts authored by this user
    _loadSharedMediaCounts(); // shared media/links/docs counts
    
    // Setup scroll listeners for pagination
    _postsScrollController.addListener(_onPostsScroll);
    _activityScrollController.addListener(_onActivityScroll);
  }

  /// INSTANT: Load cached profile and posts (no network wait)
  /// Only shows profile if we have valid name data
  Future<void> _loadFromCacheInstantly() async {
    // Load cached profile
    try {
      final userRepo = FirebaseUserRepository();
      final profile = await userRepo.getUserProfileFromCache(widget.userId);
      if (profile != null && mounted) {
        // Check if we have valid name data
        final fn = profile.firstName?.trim() ?? '';
        final ln = profile.lastName?.trim() ?? '';
        final dn = profile.displayName?.trim() ?? '';
        final un = profile.username?.trim() ?? '';
        final hasValidName = fn.isNotEmpty || ln.isNotEmpty || dn.isNotEmpty || un.isNotEmpty;
        
        // Only update UI if we have valid name data
        if (hasValidName) {
          setState(() {
            _userProfile = {
              'id': profile.uid,
              'firstName': profile.firstName,
              'lastName': profile.lastName,
              'displayName': profile.displayName,
              'username': profile.username,
              'bio': profile.bio,
              'avatarUrl': profile.avatarUrl,
              'coverUrl': profile.coverUrl,
              'followersCount': profile.followersCount ?? 0,
              'followingCount': profile.followingCount ?? 0,
              'postsCount': profile.postsCount ?? 0,
            };
            _profilePhotoUrl = profile.avatarUrl;
            // Update cover photo URL from cache if available
            if (profile.coverUrl != null && profile.coverUrl!.isNotEmpty) {
              _coverPhotoUrl = profile.coverUrl!;
            }
            _followersCount = profile.followersCount ?? 0;
            _followingCount = profile.followingCount ?? 0;
          });
        }
      }
    } catch (_) {}
    
    // Load cached posts - hydrate author data before displaying
    try {
      final postRepo = FirebasePostRepository();
      final models = await postRepo.getUserPostsFromCache(uid: widget.userId, limit: 50);
      if (models.isNotEmpty && mounted) {
        // Hydrate author data before displaying
        final hydratedModels = await _hydrateAllAuthorData(models);
        
        if (hydratedModels.isNotEmpty) {
          final posts = _mapPostModelsFast(hydratedModels);
          final mediaItems = _extractMediaItems(posts);
          setState(() {
            _userPosts = posts;
            _mediaItems = mediaItems;
            _loadingPosts = false;
            _loadingMedia = false;
          });
        }
      }
    } catch (_) {}
  }

  /// FAST: Convert PostModels to Posts synchronously using denormalized data
  List<Post> _mapPostModelsFast(List<PostModel> models) {
    final result = <Post>[];
    debugPrint('🔍 [_mapPostModelsFast] Processing ${models.length} models');
    for (final m in models) {
      // Skip reposts - they go to Activity tab
      if (m.repostOf != null && m.repostOf!.isNotEmpty) {
        debugPrint('🔍 [_mapPostModelsFast] Skipping repost: ${m.id}');
        continue;
      }
      
      debugPrint('🔍 [_mapPostModelsFast] Post ${m.id}: mediaUrls=${m.mediaUrls.length}, mediaThumbs=${m.mediaThumbs.length}');
      
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
          // Get video thumbnail from mediaThumbs
          final videoThumb = m.mediaThumbs.firstWhere(
            (t) => t.type == 'video',
            orElse: () => m.mediaThumbs.first,
          );
          imageUrls = [videoThumb.thumbUrl];
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
          // No thumbnail available - use empty (will show placeholder)
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
      
      // Convert taggedUsers from PostModel to TaggedUser
      final taggedUsers = m.taggedUsers.map((t) => TaggedUser(
        id: t.id,
        name: t.name,
        avatarUrl: t.avatarUrl,
      )).toList();
      
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
        taggedUsers: taggedUsers,
      ));
    }
    return result;
  }
  
  /// Extract media items from posts for media grid
  /// Groups multi-image posts into single items with count indicator
  List<Map<String, dynamic>> _extractMediaItems(List<Post> posts) {
    final items = <Map<String, dynamic>>[];
    debugPrint('🔍 [_extractMediaItems] Processing ${posts.length} posts');
    for (final post in posts) {
      if (post.isRepost) continue;
      
      // Include posts with images (single or multiple)
      if ((post.mediaType == MediaType.image || post.mediaType == MediaType.images) && 
          post.imageUrls.isNotEmpty) {
        debugPrint('🔍 [_extractMediaItems] Post ${post.id}: ${post.imageUrls.length} images, mediaType: ${post.mediaType}');
        items.add({
          'imageUrl': post.imageUrls.first,
          'postId': post.id,
          'imageCount': post.imageUrls.length,
          'isVideo': false,
        });
      }
      // Include posts with video
      if (post.mediaType == MediaType.video && post.videoUrl != null && post.videoUrl!.isNotEmpty) {
        // Use first image as thumbnail if available, otherwise use video URL
        final thumbUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : post.videoUrl!;
        debugPrint('🔍 [_extractMediaItems] Post ${post.id}: VIDEO');
        items.add({
          'imageUrl': thumbUrl,
          'postId': post.id,
          'imageCount': 1,
          'isVideo': true,
        });
      }
    }
    debugPrint('🔍 [_extractMediaItems] Extracted ${items.length} media items');
    return items;
  }
  
  @override
  void dispose() {
    _postsScrollController.dispose();
    _activityScrollController.dispose();
    super.dispose();
  }
  
  // Pagination for posts tab
  void _onPostsScroll() {
    if (_isLoadingMorePosts || _loadingPosts) return;
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
    if (_userPosts.isEmpty) return;
    setState(() => _isLoadingMorePosts = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoadingMorePosts = false);
  }
  
  Future<void> _loadMoreActivity() async {
    if (_activityPosts.isEmpty) return;
    setState(() => _isLoadingMoreActivity = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoadingMoreActivity = false);
  }

  // Utilities
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final i = int.tryParse(v);
      if (i != null) return i;
    }
    return 0;
  }

  String _formatCount(dynamic v) {
    final n = _toInt(v);
    if (n >= 1000000) {
      final m = n / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userRepo = Provider.of<UserRepository>(context, listen: false);
      final user = await userRepo.getUserProfile(widget.userId);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _userProfile = null;
          _profilePhotoUrl = null;
          _experiences.clear();
          _trainings.clear();
          _interests.clear();
        });
        return;
      }

      // Build a map compatible with existing UI expectations
      final map = user.toMap();
      final hasDisplay = (user.displayName ?? '').toString().trim().isNotEmpty;
      final first = (user.firstName ?? '').toString().trim();
      final last = (user.lastName ?? '').toString().trim();
      final fullName = hasDisplay
          ? user.displayName!.trim()
          : [first, last].where((s) => s.isNotEmpty).join(' ').trim();

      setState(() {
        _userProfile = {
          ...map,
          'full_name': fullName,
        };
        _profilePhotoUrl = user.avatarUrl;
        // Update cover photo URL from Firebase if available
        if (user.coverUrl != null && user.coverUrl!.isNotEmpty) {
          _coverPhotoUrl = user.coverUrl!;
        }
        _followersCount = user.followersCount ?? 0;
        _followingCount = user.followingCount ?? 0;
        _experiences
          ..clear()
          ..addAll(user.professionalExperiences ?? const []);
        _trainings
          ..clear()
          ..addAll(user.trainings ?? const []);
        _interests
          ..clear()
          ..addAll(user.interestDomains ?? const []);
      });
    } catch (e) {
      if (!mounted) return;
    }
  }

  Future<void> _loadUserPosts() async {
    // Always load fresh posts from server, but show cached data first if available
    if (_userPosts.isNotEmpty) {
      setState(() {
        _loadingPosts = false;
        _loadingMedia = false;
      });
    } else {
      setState(() {
        _loadingPosts = true;
        _errorPosts = null;
        _loadingMedia = true;
      });
    }

    try {
      final postRepo = FirebasePostRepository();
      debugPrint('🔍 [OtherUserProfile] Loading posts for user: ${widget.userId}');
      final models = await postRepo.getUserPosts(uid: widget.userId, limit: 50);
      debugPrint('🔍 [OtherUserProfile] Got ${models.length} post models from Firestore');
      
      if (!mounted) return;
      
      // Hydrate author data BEFORE displaying
      final hydratedModels = await _hydrateAllAuthorData(models);
      debugPrint('🔍 [OtherUserProfile] Hydrated ${hydratedModels.length} models');
      
      final posts = _mapPostModelsFast(hydratedModels);
      debugPrint('🔍 [OtherUserProfile] Mapped to ${posts.length} posts');
      final mediaItems = _extractMediaItems(posts);
      debugPrint('🔍 [OtherUserProfile] Extracted ${mediaItems.length} media items');
      
      setState(() {
        _userPosts = posts;
        _mediaItems = mediaItems;
        _loadingPosts = false;
        _loadingMedia = false;
      });
    } catch (e, stack) {
      debugPrint('❌ [OtherUserProfile] Error loading posts: $e');
      debugPrint('Stack: $stack');
      if (!mounted) return;
      setState(() {
        _errorPosts = Provider.of<LanguageProvider>(context, listen: false).t('other.posts_failed');
        _loadingPosts = false;
        _loadingMedia = false;
      });
    }
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
      debugPrint('💧 [OtherProfile] Hydrating ${authorIds.length} authors before display...');
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

  Future<void> _loadActivity() async {
    setState(() {
      _loadingActivity = true;
      _errorActivity = null;
    });

    try {
      final postRepo = FirebasePostRepository();
      final userRepo = FirebaseUserRepository();
      // Fetch this user's reposts
      final reposts = await postRepo.getUserReposts(uid: widget.userId, limit: 50);

      if (reposts.isEmpty) {
        if (!mounted) return;
        setState(() {
          _activityPosts = [];
          _loadingActivity = false;
        });
        return;
      }

      // ⚡ OPTIMIZATION: Batch fetch all original posts in parallel
      final originalPostIds = reposts
          .where((r) => r.repostOf != null && r.repostOf!.isNotEmpty)
          .map((r) => r.repostOf!)
          .toSet();
      
      final originalPostFutures = originalPostIds.map((postId) async {
        final post = await postRepo.getPost(postId);
        return MapEntry(postId, post);
      });
      final originalPosts = Map.fromEntries(await Future.wait(originalPostFutures));
      
      if (!mounted) return;
      
      // ⚡ OPTIMIZATION: Batch fetch all author profiles in parallel
      final authorIds = originalPosts.values
          .whereType<dynamic>()
          .where((p) => p != null)
          .map((p) => p.authorId as String)
          .toSet();
      
      final authorFutures = authorIds.map((authorId) async {
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

      final posts = <Post>[];
      for (final model in reposts) {
        final ogId = model.repostOf;
        if (ogId == null || ogId.isEmpty) continue;
        final original = originalPosts[ogId];
        if (original == null) continue;
        final origAuthor = authors[original.authorId];

        final origFirst = (origAuthor?.firstName ?? '').trim();
        final origLast = (origAuthor?.lastName ?? '').trim();
        final origName = (origFirst.isNotEmpty || origLast.isNotEmpty)
            ? '$origFirst $origLast'.trim()
            : (origAuthor?.displayName ?? origAuthor?.username ?? 'User');

        // Determine media type from original mediaUrls
        MediaType mediaType = MediaType.none;
        List<String> images = const [];
        String? videoUrl;
        if (original.mediaUrls.isNotEmpty) {
          final urls = original.mediaUrls.map((u) => u.toLowerCase()).toList();
          final hasVideo = urls.any((u) => u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.webm'));
          if (hasVideo) {
            mediaType = MediaType.video;
            videoUrl = original.mediaUrls.first;
          } else if (original.mediaUrls.length > 1) {
            mediaType = MediaType.images;
            images = original.mediaUrls;
          } else {
            mediaType = MediaType.image;
            images = original.mediaUrls;
          }
        }

        // Convert taggedUsers from original post
        final taggedUsers = original.taggedUsers.map((t) => TaggedUser(
          id: t.id,
          name: t.name,
          avatarUrl: t.avatarUrl,
        )).toList();

        posts.add(
          Post(
            id: model.id,
            authorId: original.authorId,
            userName: origName,
            userAvatarUrl: origAuthor?.avatarUrl ?? '',
            createdAt: model.createdAt,
            text: original.text,
            mediaType: mediaType,
            imageUrls: images,
            videoUrl: videoUrl,
            counts: PostCounts(
              likes: original.summary.likes,
              comments: original.summary.comments,
              shares: original.summary.shares,
              reposts: original.summary.reposts,
              bookmarks: original.summary.bookmarks,
            ),
            userReaction: null,
            isBookmarked: false,
            isRepost: true,
            repostedBy: RepostedBy(
              userId: widget.userId,
              userName: widget.userName,
              userAvatarUrl: widget.userAvatarUrl,
            ),
            originalPostId: ogId,
            taggedUsers: taggedUsers,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _activityPosts = posts;
        _loadingActivity = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorActivity = 'Failed to load activity';
        _loadingActivity = false;
      });
    }
  }

  Future<void> _loadPodcasts() async {
    setState(() {
      _loadingPodcasts = true;
      _errorPodcasts = null;
    });

    try {
      final podcastRepo = FirebasePodcastRepository();
      final podcasts = await podcastRepo.listPodcasts(
        authorId: widget.userId,
        isPublished: true,
        limit: 50,
      );
      
      if (!mounted) return;
      setState(() {
        _podcasts = podcasts.map((p) => {
          'id': p.id,
          'title': p.title,
          'author': p.author ?? '',
          'authorId': p.authorId ?? '',
          'description': p.description ?? '',
          'coverUrl': p.coverUrl ?? '',
          'audioUrl': p.audioUrl ?? '',
          'durationSec': p.durationSec ?? 0,
          'playCount': p.playCount,
          'likeCount': p.likeCount,
          'isLiked': p.isLiked,
          'isBookmarked': p.isBookmarked,
          'createdAt': p.createdAt,
        }).toList();
        _loadingPodcasts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPodcasts = 'Failed to load podcasts';
        _loadingPodcasts = false;
      });
    }
  }

  Future<void> _handleMessageUser() async {
    final ctx = context;
    try {
      // Check if conversation already exists
      final conversationId = await _convRepo.checkConversationExists(
        widget.userId,
      );

      if (!ctx.mounted) return;

      if (conversationId != null) {
        // Conversation exists - navigate to chat
        final chatUser = ChatUser(
          id: widget.userId,
          name: widget.userName,
          avatarUrl: widget.userAvatarUrl,
        );

        Navigator.push(
          ctx,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'chat'),
            builder: (_) => ChatPage(
              otherUser: chatUser,
              isDarkMode: false,
              conversationId: conversationId,
            ),
          ),
        );
      } else {
        // No conversation - show invite bottom sheet
        if (ctx.mounted) {
          _showMessageBottomSheet(ctx);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling message user: $e');
      // Fallback to invite sheet on error
      if (ctx.mounted) {
        _showMessageBottomSheet(ctx);
      }
    }
  }

  /// Load shared media counts from conversation
  Future<void> _loadSharedMediaCounts() async {
    try {
      final counts = await SharedMediaHelper.getSharedMediaCounts(widget.userId);
      if (!mounted) return;
      setState(() {
        _sharedMediaCount = counts['media'] ?? 0;
        _sharedLinksCount = counts['links'] ?? 0;
        _sharedDocsCount = counts['docs'] ?? 0;
      });
    } catch (e) {
      debugPrint('⚠️ [OtherProfile] Failed to load shared media counts: $e');
    }
  }

  void _showMessageBottomSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: MessageInviteCard(
          receiverId: widget.userId,
          fullName: widget.userName,
          bio: widget.userBio,
          avatarUrl: widget.userAvatarUrl,
          coverUrl: _coverPhotoUrl.isNotEmpty ? _coverPhotoUrl : widget.userCoverUrl,
          onClose: () => Navigator.pop(ctx),
          onInvitationSent: (invitation) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('profile.invitation_sent')} ${widget.userName}')),
            );
          },
        ),
      ),
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

          // Derive display name and @username from backend if available
          final String displayName = (() {
            final p = _userProfile ?? {};
            final fullName = (p['full_name'] ?? '').toString().trim();
            if (fullName.isNotEmpty) return fullName;
            return widget.userName;
          })();
          final String atUsername = (() {
            final p = _userProfile ?? {};
            final u = (p['username'] ?? '').toString().trim();
            return u.isNotEmpty ? '@$u' : '';
          })();

          final String coverUrl = _coverPhotoUrl.isNotEmpty
              ? _coverPhotoUrl
              : widget.userCoverUrl;

          return Scaffold(
            key: scaffoldKey,
            backgroundColor:
                isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
            endDrawer: _buildDrawer(isDark),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header with Cover Image
                  GestureDetector(
                    onTap: coverUrl.isNotEmpty
                        ? () => showExpandablePhoto(
                              context: context,
                              imageUrl: coverUrl,
                              isProfilePhoto: false,
                              heroTag: 'other_user_cover_${widget.userId}',
                            )
                        : null,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: (coverUrl.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(coverUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: coverUrl.isEmpty
                            ? (isDark ? Colors.black : Colors.grey[300])
                            : null,
                      ),
                      child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button with visible background
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(20),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            // More options button with visible background
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: InkWell(
                                onTap: () =>
                                    scaffoldKey.currentState!.openEndDrawer(),
                                borderRadius: BorderRadius.circular(20),
                                child: const Icon(
                                  Icons.more_horiz,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),

                  // Main Profile Card
                  Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF000000) : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0)
                              : Colors.black.withValues(alpha: 13),
                          blurRadius: 1,
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
                                  onTap: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                                      ? () => showExpandablePhoto(
                                            context: context,
                                            imageUrl: _profilePhotoUrl,
                                            isProfilePhoto: true,
                                            heroTag: 'other_user_avatar_${widget.userId}',
                                            fallbackInitial: displayName.isNotEmpty ? displayName[0] : 'U',
                                          )
                                      : null,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF000000)
                                            : Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 58,
                                      backgroundImage: (_profilePhotoUrl != null &&
                                              _profilePhotoUrl!.isNotEmpty)
                                          ? NetworkImage(_profilePhotoUrl!)
                                          : null,
                                      child: (_profilePhotoUrl == null ||
                                              _profilePhotoUrl!.isEmpty)
                                          ? Text(
                                              (displayName.isNotEmpty
                                                      ? displayName[0]
                                                      : 'U')
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

                              // Stats Row (match ProfilePage style) - Tap to navigate to My Connections
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildStatColumn(
                                        _formatCount(_followersCount),
                                        Provider.of<LanguageProvider>(context, listen: false).t('profile.connections_label'),
                                      ),
                                      const SizedBox(width: 40),
                                      _buildStatColumn(
                                        _formatCount(_followingCount),
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
                                          displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
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
                                        padding: const EdgeInsets.only(top: 4),
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
                                      (_userProfile?['bio'] ?? widget.userBio ?? '').toString(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.grey[300]
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
                                          // Capture messenger before async operations
                                          final messenger = ScaffoldMessenger.of(context);
                                          final wasConnected = context.read<FollowState>().isConnected(widget.userId);
                                          try {
                                            await context.read<FollowState>().toggle(widget.userId);
                                            // Emit event to sync across app
                                            ConnectionEvents.emit(ConnectionEvent(
                                              targetUserId: widget.userId,
                                              isConnected: !wasConnected,
                                            ));
                                          } catch (e) {
                                            if (!mounted) return;
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(Provider.of<LanguageProvider>(context, listen: false).t('other_profile.toggle_failed')),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: context.watch<FollowState>().isConnected(widget.userId)
                                              ? Colors.grey[300]
                                              : const Color(0xFFBFAE01),
                                          foregroundColor: context.watch<FollowState>().isConnected(widget.userId)
                                              ? Colors.black87
                                              : Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          context.watch<FollowState>().isConnected(widget.userId)
                                              ? Provider.of<LanguageProvider>(context).t('connections.disconnect')
                                              : ((widget.theyConnectToYou || context.watch<FollowState>().theyConnectToYou(widget.userId))
                                                  ? Provider.of<LanguageProvider>(context).t('connections.connect_back')
                                                  : Provider.of<LanguageProvider>(context).t('connections.connect')),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _handleMessageUser,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF000000)
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          Provider.of<LanguageProvider>(context).t('profile.message'),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
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
                                              ? const Color(0xFF000000)
                                              : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                      child: const Icon(
                                        Icons.person_add_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Professional Experiences Section (hidden for admin)
                        if (!AdminConfig.isAdmin(widget.userId))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.work,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    Provider.of<LanguageProvider>(context, listen: false).t('other_profile.experiences'),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_experiences.isEmpty) ...[
                                Text(
                                  'No professional experiences to display',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ] else ...[
                                for (final exp in _experiences) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      (exp['title'] ?? 'Experience')
                                          .toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (exp['subtitle'] != null &&
                                      exp['subtitle'].toString().isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        exp['subtitle'].toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Trainings Section (hidden for admin)
                        if (!AdminConfig.isAdmin(widget.userId))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Trainings',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_trainings.isEmpty) ...[
                                Text(
                                  'No trainings to display',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ] else ...[
                                for (final t in _trainings) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      (t['title'] ?? 'Training').toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (t['subtitle'] != null &&
                                      t['subtitle'].toString().isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        t['subtitle'].toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Interest Section (hidden for admin)
                        if (!AdminConfig.isAdmin(widget.userId))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Interest',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_interests.isEmpty) ...[
                                Text(
                                  'No interests to display',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ] else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _interests
                                      .map((i) => _buildInterestChip(i))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Shared Media Section (only show if there's a conversation)
                        if (_sharedMediaCount + _sharedLinksCount + _sharedDocsCount > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings: const RouteSettings(name: 'shared_media'),
                                    builder: (context) => SharedMediaPage(
                                      otherUserId: widget.userId,
                                      otherUserName: widget.userName,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.perm_media_outlined,
                                    color: isDark ? Colors.white : Colors.black87,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      Provider.of<LanguageProvider>(context, listen: false).t('other_profile.shared_media'),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_sharedMediaCount + _sharedLinksCount + _sharedDocsCount}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Tab Section
                  _buildTabSection(isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Ionicons.flag_outline,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
              title: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('other_profile.report_user'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                ReportBottomSheet.show(
                  context,
                  targetType: 'user',
                  targetId: widget.userId,
                  authorName: widget.userName,
                );
              },
            ),
            ListTile(
              leading: Icon(
                Ionicons.ban_outline,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
              title: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('other_profile.block_user'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // Add block functionality here
              },
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildInterestChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTabSection(bool isDark) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.black,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.grey[300] : Colors.white,
              unselectedLabelColor:
                  isDark ? const Color(0xFF666666) : const Color(0xFF666666),
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
                _buildActivityTab(isDark),
                _buildPostsTab(isDark),
                _buildPodcastsTab(isDark),
                _buildMediaTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_loadingActivity) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorActivity != null) {
      return Center(child: Text(_errorActivity!));
    }
    if (_activityPosts.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('profile.no_activity')));
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
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
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

  Widget _buildPostsTab(bool isDark) {
    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPosts != null) {
      return Center(child: Text(_errorPosts!));
    }
    if (_userPosts.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('profile.no_posts')));
    }
    return ListView.builder(
      controller: _postsScrollController,
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _userPosts.length + (_isLoadingMorePosts ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index == _userPosts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final post = _userPosts[index];
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
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
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

  Widget _buildPodcastsTab(bool isDark) {
    if (_loadingPodcasts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPodcasts != null) {
      return Center(child: Text(_errorPodcasts!));
    }
    if (_podcasts.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('profile.no_podcasts')));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: _podcasts.length,
      itemBuilder: (context, index) {
        final podcast = _podcasts[index];
        return _buildPodcastItem(
          (podcast['title'] ?? Provider.of<LanguageProvider>(context, listen: false).t('other_profile.untitled')).toString(),
          (podcast['description'] ?? Provider.of<LanguageProvider>(context, listen: false).t('other_profile.no_description')).toString(),
          '${podcast['durationSec'] ?? 0}s',
          (podcast['coverUrl'] ?? '').toString(),
          isDark,
        );
      },
    );
  }

  Widget _buildPodcastItem(
    String title,
    String description,
    String duration,
    String imageUrl,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF000000)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill, size: 32),
        ],
      ),
    );
  }

  Widget _buildMediaTab(bool isDark) {
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
              Provider.of<LanguageProvider>(context).t('profile.no_media'),
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
        final imageUrl = item['imageUrl'] as String? ?? '';
        final postId = item['postId'] as String? ?? '';
        final imageCount = item['imageCount'] as int? ?? 1;
        final isVideo = item['isVideo'] as bool? ?? false;
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'post_detail'),
                builder: (_) => PostPage(postId: postId),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Show image or video placeholder
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                      child: Icon(
                        isVideo ? Icons.videocam : Icons.broken_image_outlined,
                        color: isDark ? Colors.white30 : Colors.black26,
                        size: 32,
                      ),
                    ),
                  )
                else
                  // No thumbnail - show placeholder
                  Container(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                    child: Icon(
                      isVideo ? Icons.videocam : Icons.image,
                      color: isDark ? Colors.white30 : Colors.black26,
                      size: 32,
                    ),
                  ),
                // Multi-image indicator (top-right)
                if (imageCount > 1)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$imageCount',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Video indicator (center)
                if (isVideo)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}