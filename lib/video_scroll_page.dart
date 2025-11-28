import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';

import 'models/post.dart';
import 'models/comment.dart';
import 'repositories/models/post_model.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_comment_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'core/i18n/language_provider.dart';
import 'widgets/custom_video_player.dart';
import 'widgets/reaction_picker.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'widgets/share_bottom_sheet.dart';
import 'other_user_profile_page.dart';
import 'profile_page.dart';
import 'services/content_analytics_service.dart';
import 'core/post_events.dart';
import 'providers/follow_state.dart';
import 'repositories/interfaces/follow_repository.dart';
import 'dart:async';

class VideoScrollPage extends StatefulWidget {
  const VideoScrollPage({super.key});

  @override
  State<VideoScrollPage> createState() => _VideoScrollPageState();
}

class _VideoScrollPageState extends State<VideoScrollPage> with TickerProviderStateMixin {
  late PageController _pageController;
  bool _showReactionPicker = false;
  String? _reactionPickerPostId;

  final Map<String, bool> _expandedTexts = {};
  final Map<String, CustomVideoPlayer> _videoPlayers = {};
  final Map<String, GlobalKey<CustomVideoPlayerState>> _videoPlayerKeys = {};
  
  // Like animation state
  bool _showLikeAnimation = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  List<Post> _videoPosts = [];
  String? _currentUserId;

  // Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;
  PostModel? _lastVideoPost;
  static const int _videosPerPage = 5; // Load 5 videos at a time
  int _currentVideoIndex = 0;

  // Cache for loaded posts to avoid reloading
  final Map<String, Post> _postCache = {};

  final FirebasePostRepository _postRepo = FirebasePostRepository();
  final FirebaseCommentRepository _commentRepo = FirebaseCommentRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  // PostEvents subscription for syncing across pages
  StreamSubscription<PostUpdateEvent>? _postEventsSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);
    
    // Initialize like animation
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Subscribe to post update events to keep video scroll in sync
    _postEventsSub = PostEvents.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        // Update all posts that match the originalPostId
        for (int i = 0; i < _videoPosts.length; i++) {
          final post = _videoPosts[i];
          final postId = post.originalPostId ?? post.id;
          if (postId == e.originalPostId) {
            _videoPosts[i] = post.copyWith(
              counts: e.counts,
              userReaction: e.userReaction,
              isBookmarked: e.isBookmarked ?? post.isBookmarked,
            );
          }
        }
      });
    });
    () async {
      await _loadCurrentUserId();
      await _loadVideoPosts();
    }();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _likeAnimationController.dispose();
    _postEventsSub?.cancel();
    // Clear video players to free memory
    _videoPlayers.clear();
    _videoPlayerKeys.clear();
    _postCache.clear();
    super.dispose();
  }

  // Pagination listener
  void _onPageScroll() {
    // Load more when approaching the last 2 videos
    if (_currentVideoIndex >= _videoPosts.length - 2 &&
        !_isLoadingMore &&
        _hasMoreVideos) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final id = fb.FirebaseAuth.instance.currentUser?.uid;
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

  Future<void> _loadVideoPosts() async {
    try {
      // Load posts in batches, filtering for videos
      List<Post> videos = [];
      PostModel? lastPost;
      int fetchCount = 0;
      const maxFetches = 5; // Max 5 batches to find initial videos

      // Keep fetching until we have enough videos or hit max
      while (videos.length < _videosPerPage && fetchCount < maxFetches) {
        final models = await _postRepo.getFeed(
          limit: 20, // Fetch 20 posts per batch
          lastPost: lastPost,
        );
        
        if (models.isEmpty) {
          _hasMoreVideos = false;
          break;
        }

        fetchCount++;
        lastPost = models.last;

        // Filter for videos and add to list
        for (final model in models) {
          if (await _isVideoPost(model)) {
            final post = await _toPost(model);
            videos.add(post);
            _postCache[post.id] = post; // Cache the post
            _lastVideoPost = model; // Track for pagination
            
            if (videos.length >= _videosPerPage) break;
          }
        }
      }

      debugPrint('📹 Video Scroll: Loaded ${videos.length} video posts ($fetchCount fetches)');
      
      if (!mounted) return;
      setState(() {
        _videoPosts = videos;
        _hasMoreVideos = videos.length == _videosPerPage;
      });
      
      // Track view of first video
      if (videos.isNotEmpty && mounted) {
        _trackVideoView(videos[0]);
      }
    } catch (e) {
      debugPrint('❌ Video Scroll error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_toError(e), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Load more videos (pagination)
  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos || _lastVideoPost == null) return;

    setState(() => _isLoadingMore = true);
    
    try {
      List<Post> moreVideos = [];
      PostModel? lastPost = _lastVideoPost;
      int fetchCount = 0;
      const maxFetches = 3;

      while (moreVideos.length < _videosPerPage && fetchCount < maxFetches) {
        final models = await _postRepo.getFeed(
          limit: 20,
          lastPost: lastPost,
        );
        
        if (models.isEmpty) {
          _hasMoreVideos = false;
          break;
        }

        fetchCount++;
        lastPost = models.last;

        for (final model in models) {
          if (await _isVideoPost(model)) {
            final post = await _toPost(model);
            moreVideos.add(post);
            _postCache[post.id] = post;
            _lastVideoPost = model;
            
            if (moreVideos.length >= _videosPerPage) break;
          }
        }
      }

      debugPrint('📹 Loaded ${moreVideos.length} more videos');
      
      if (!mounted) return;
      setState(() {
        _videoPosts.addAll(moreVideos);
        _hasMoreVideos = moreVideos.length == _videosPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading more videos: $e');
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  // Check if post has video
  Future<bool> _isVideoPost(PostModel model) async {
    if (model.mediaUrls.isEmpty) return false;
    return model.mediaUrls.any((u) {
      final l = u.toLowerCase();
      // Check if URL contains video extensions (handles URLs with query params)
      return l.contains('.mp4') || 
             l.contains('.mov') || 
             l.contains('.webm') ||
             l.contains('.avi') ||
             l.contains('.mkv') ||
             // Check for Firebase Storage video paths
             l.contains('/videos/') ||
             l.contains('video_') ||
             // Check for video mime types in URL
             l.contains('video%2f') ||
             l.contains('video/');
    });
  }

  // Track video view with analytics
  void _trackVideoView(Post post) {
    if (!mounted) return;
    try {
      final analytics = context.read<ContentAnalyticsService>();
      analytics.trackView(
        contentId: post.id,
        contentType: 'post',
        userId: post.authorId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking video view: $e');
    }
  }

  // Cleanup video players that are far from current video to save memory
  void _cleanupDistantVideos(int currentIndex) {
    const keepRange = 2; // Keep players for current +/- 2 videos
    
    final videosToRemove = <String>[];
    
    for (int i = 0; i < _videoPosts.length; i++) {
      if ((i < currentIndex - keepRange || i > currentIndex + keepRange)) {
        final videoUrl = _videoPosts[i].videoUrl;
        if (videoUrl != null && _videoPlayers.containsKey(videoUrl)) {
          videosToRemove.add(videoUrl);
        }
      }
    }
    
    // Remove distant video players
    for (final url in videosToRemove) {
      _videoPlayers.remove(url);
      _videoPlayerKeys.remove(url);
    }
    
    if (videosToRemove.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${videosToRemove.length} distant video players');
    }
  }

  Future<Post> _toPost(PostModel m) async {
    // Capture fallback user text before async gap
    final fallbackUser = mounted ? Provider.of<LanguageProvider>(context, listen: false).t('video.user') : 'User';
    
    final author = await _userRepo.getUserProfile(m.authorId);
    final uid = _currentUserId;
    bool isBookmarked = false;
    bool isLiked = false;
    if (uid != null && uid.isNotEmpty) {
      isBookmarked = await _postRepo.hasUserBookmarkedPost(postId: m.id, uid: uid);
      isLiked = await _postRepo.hasUserLikedPost(postId: m.id, uid: uid);
    }
    MediaType mediaType;
    String? videoUrl;
    if (m.mediaUrls.isEmpty) {
      mediaType = MediaType.none;
      videoUrl = null;
    } else {
      final hasVideo = m.mediaUrls.any((u) {
        final l = u.toLowerCase();
        return l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') ||
               l.contains('.avi') || l.contains('.mkv') ||
               l.contains('/videos/') || l.contains('video_') ||
               l.contains('video%2f') || l.contains('video/');
      });
      if (hasVideo) {
        mediaType = MediaType.video;
        videoUrl = m.mediaUrls.firstWhere(
          (u) {
            final l = u.toLowerCase();
            return l.contains('.mp4') || l.contains('.mov') || l.contains('.webm') ||
                   l.contains('.avi') || l.contains('.mkv') ||
                   l.contains('/videos/') || l.contains('video_') ||
                   l.contains('video%2f') || l.contains('video/');
          },
          orElse: () => m.mediaUrls.first,
        );
      } else {
        mediaType = (m.mediaUrls.length == 1) ? MediaType.image : MediaType.images;
        videoUrl = null;
      }
    }
    int clamp(int v) => v < 0 ? 0 : v;
    return Post(
      id: m.id,
      authorId: m.authorId,
      userName: author?.displayName ?? author?.username ?? author?.email ?? fallbackUser,
      userAvatarUrl: author?.avatarUrl ?? '',
      createdAt: m.createdAt,
      text: m.text,
      mediaType: mediaType,
      imageUrls: m.mediaUrls,
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
      repostedBy: null,
      originalPostId: m.repostOf,
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

  int _findPostIndex(String postId) =>
      _videoPosts.indexWhere((post) => post.id == postId);

  void _showReactions(String postId) {
    setState(() {
      _showReactionPicker = true;
      _reactionPickerPostId = postId;
    });
  }

  void _hideReactions() {
    setState(() {
      _showReactionPicker = false;
      _reactionPickerPostId = null;
    });
  }

  void _onReactionSelected(ReactionType reaction) async {
    final postIndex = _videoPosts.indexWhere(
      (post) => post.id == _reactionPickerPostId,
    );
    if (postIndex == -1) {
      _hideReactions();
      return;
    }

    final original = _videoPosts[postIndex];
    final hadReaction = original.userReaction != null;
    final isSameReaction = original.userReaction == reaction;

    // Toggle ON when no previous reaction
    if (!hadReaction) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes + 1,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic =
          original.copyWith(userReaction: reaction, counts: updatedCounts);
      setState(() {
        _videoPosts[postIndex] = optimistic;
      });
      try {
        await _postRepo.likePost(original.id);
        // Emit event for other pages to sync
        PostEvents.emit(PostUpdateEvent(
          originalPostId: original.originalPostId ?? original.id,
          counts: updatedCounts,
          userReaction: reaction,
          isBookmarked: original.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[postIndex] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('video.like_failed')}${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      _hideReactions();
      return;
    }

    // Toggle OFF when same reaction
    if (isSameReaction) {
      final newLikes =
          original.counts.likes > 0 ? original.counts.likes - 1 : 0;
      final updatedCounts = PostCounts(
        likes: newLikes,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic = original.copyWith(userReaction: null, counts: updatedCounts);
      setState(() {
        _videoPosts[postIndex] = optimistic;
      });
      try {
        await _postRepo.unlikePost(original.id);
        // Emit event for other pages to sync
        PostEvents.emit(PostUpdateEvent(
          originalPostId: original.originalPostId ?? original.id,
          counts: updatedCounts,
          userReaction: null,
          isBookmarked: original.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[postIndex] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${Provider.of<LanguageProvider>(context, listen: false).t('video.unlike_failed')}${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      _hideReactions();
      return;
    }

    // Change reaction type (still liked): UI-only
    setState(() {
      _videoPosts[postIndex] = original.copyWith(userReaction: reaction);
    });
    _hideReactions();
  }

  Future<void> _handleLikeFromPlayer(Post post) async {
    final idx = _findPostIndex(post.id);
    if (idx == -1) return;
    final original = _videoPosts[idx];

    // If not liked yet: optimistic + API
    if (original.userReaction == null) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes + 1,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic =
          original.copyWith(userReaction: ReactionType.heart, counts: updatedCounts);
      setState(() {
        _videoPosts[idx] = optimistic;
      });
      try {
        await _postRepo.likePost(post.id);
        // Emit event for other pages to sync
        PostEvents.emit(PostUpdateEvent(
          originalPostId: original.originalPostId ?? original.id,
          counts: updatedCounts,
          userReaction: ReactionType.heart,
          isBookmarked: original.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[idx] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('video.like_failed')}${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // If already liked with a different reaction: only switch locally
    if (original.userReaction != ReactionType.heart) {
      setState(() {
        _videoPosts[idx] = original.copyWith(userReaction: ReactionType.heart);
      });
    }
  }

  Future<void> _handleUnlikeFromPlayer(Post post) async {
    final idx = _findPostIndex(post.id);
    if (idx == -1) return;
    final original = _videoPosts[idx];

    // Only handle unlike when current reaction is heart (what the player toggles)
    if (original.userReaction == ReactionType.heart) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes > 0 ? original.counts.likes - 1 : 0,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic = original.copyWith(userReaction: null, counts: updatedCounts);
      setState(() {
        _videoPosts[idx] = optimistic;
      });
      try {
        await _postRepo.unlikePost(post.id);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[idx] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${Provider.of<LanguageProvider>(context, listen: false).t('video.unlike_failed')}${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBookmark(String postId) async {
    final idx = _findPostIndex(postId);
    if (idx == -1) return;

    final original = _videoPosts[idx];
    final willBookmark = !original.isBookmarked;
    final newBookmarks =
        (original.counts.bookmarks + (willBookmark ? 1 : -1)).clamp(0, 1 << 30);

    final updatedCounts = PostCounts(
      likes: original.counts.likes,
      comments: original.counts.comments,
      shares: original.counts.shares,
      reposts: original.counts.reposts,
      bookmarks: newBookmarks,
    );

    final optimistic =
        original.copyWith(isBookmarked: willBookmark, counts: updatedCounts);

    setState(() {
      _videoPosts[idx] = optimistic;
    });

    try {
      if (willBookmark) {
        await _postRepo.bookmarkPost(postId);
      } else {
        await _postRepo.unbookmarkPost(postId);
      }
      // Emit event for other pages to sync
      PostEvents.emit(PostUpdateEvent(
        originalPostId: original.originalPostId ?? original.id,
        counts: updatedCounts,
        userReaction: original.userReaction,
        isBookmarked: willBookmark,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoPosts[idx] = original;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('video.bookmark_failed')}${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  CustomVideoPlayer _getVideoPlayer(String videoUrl, Post post) {
    if (!_videoPlayers.containsKey(videoUrl)) {
      _videoPlayerKeys[videoUrl] ??= GlobalKey<CustomVideoPlayerState>();
      _videoPlayers[videoUrl] = CustomVideoPlayer(
        key: _videoPlayerKeys[videoUrl],
        videoUrl: videoUrl,
        isLiked: post.userReaction == ReactionType.heart,
        onLike: () {
          // Handle double-tap like from player
          _handleLikeFromPlayer(post);
        },
        onUnlike: () {
          // Handle double-tap unlike from player
          _handleUnlikeFromPlayer(post);
        },
        // No onLongPressCallback - uses default speed options
      );
    }
    return _videoPlayers[videoUrl]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back_outline, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('video.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Ionicons.search_outline, color: Colors.white),
            onPressed: () {
              // optional search for videos
            },
          ),
        ],
      ),
      body: _videoPosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Ionicons.videocam_outline,
                    size: 64,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('video.no_videos'),
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a post with video to see it here',
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _videoPosts.length,
                  onPageChanged: (index) {
                    _currentVideoIndex = index;
                    
                    // Track video view
                    if (index < _videoPosts.length) {
                      _trackVideoView(_videoPosts[index]);
                    }
                    
                    // Cleanup distant video players to save memory
                    _cleanupDistantVideos(index);
                  },
                  itemBuilder: (context, index) {
                    final post = _videoPosts[index];
                    return _buildVideoItem(context, post, isDark);
                  },
                ),
                if (_showReactionPicker && _reactionPickerPostId != null)
                  Stack(
                    children: [
                      // Full screen invisible overlay to catch background taps
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _hideReactions,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      // Reaction picker positioned on the right
                      Positioned(
                        right: 80,
                        top: 80,
                        bottom: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ReactionPicker(
                              currentReaction: _videoPosts
                                  .firstWhere(
                                    (p) => p.id == _reactionPickerPostId,
                                    orElse: () => _videoPosts.first,
                                  )
                                  .userReaction,
                              onReactionSelected: _onReactionSelected,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _buildVideoItem(BuildContext context, Post post, bool isDark) {
    final isExpanded = _expandedTexts[post.id] ?? false;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Video player
          if (post.videoUrl != null)
            Positioned.fill(
              child: _getVideoPlayer(post.videoUrl!, post),
            ),

          // Transparent gesture area (covers screen except action buttons)
          // Handles: tap (pause/play), double-tap (like)
          // Long press handled by video player (speed options)
          if (post.videoUrl != null)
            Positioned(
              top: 0,
              left: 0,
              right: 100, // Leave space for action buttons on the right
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // Single tap → Pause/Play
                onTap: () {
                  final playerKey = _videoPlayerKeys[post.videoUrl];
                  if (playerKey != null && playerKey.currentState != null) {
                    playerKey.currentState!.togglePlayPause();
                  }
                },
                // Double tap → Like/Unlike
                onDoubleTap: () {
                  // Show heart animation
                  setState(() {
                    _showLikeAnimation = true;
                  });
                  _likeAnimationController.forward().then((_) {
                    _likeAnimationController.reset();
                    setState(() {
                      _showLikeAnimation = false;
                    });
                  });
                  
                  // Handle like/unlike
                  if (post.userReaction == null) {
                    _handleLikeFromPlayer(post);
                  } else {
                    _handleUnlikeFromPlayer(post);
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          // Subtle gradient overlay only at the bottom for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 102),
                  ],
                ),
              ),
            ),
          ),

          // Like animation (appears on double-tap)
          if (_showLikeAnimation)
            Center(
              child: AnimatedBuilder(
                animation: _likeAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _likeAnimation.value,
                    child: Opacity(
                      opacity: (1.0 - _likeAnimation.value).clamp(0.0, 1.0),
                      child: const Icon(
                        Ionicons.heart,
                        color: Colors.red,
                        size: 120,
                      ),
                    ),
                  );
                },
              ),
            ),

          // User info and actions
          Positioned(
            bottom: 40,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info
                GestureDetector(
                  onTap: () {
                    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
                    if (currentUserId == post.authorId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfilePage()),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherUserProfilePage(
                            userId: post.authorId,
                            userName: post.userName,
                            userAvatarUrl: post.userAvatarUrl,
                            userBio: '',
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFBFAE01),
                        backgroundImage: post.userAvatarUrl.isNotEmpty 
                          ? NetworkImage(post.userAvatarUrl) 
                          : null,
                        child: post.userAvatarUrl.isEmpty
                          ? Text(
                              post.userName.isNotEmpty ? post.userName[0].toUpperCase() : 'U',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.userName,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withValues(alpha: 128),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatTimeAgo(post.createdAt),
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withValues(alpha: 128),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Connection button - only show if not fully connected and not own post
                      Consumer<FollowState>(
                        builder: (context, followState, _) {
                          final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
                          
                          // Hide if viewing own post
                          if (currentUserId == post.authorId) {
                            return const SizedBox.shrink();
                          }
                          
                          final youConnectTo = followState.isConnected(post.authorId);
                          final theyConnectToYou = followState.theyConnectToYou(post.authorId);
                          final fullyConnected = youConnectTo && theyConnectToYou;
                          
                          // Hide button if fully connected (mutual connection)
                          if (fullyConnected) {
                            return const SizedBox.shrink();
                          }
                          
                          return GestureDetector(
                            onTap: () async {
                              final repo = context.read<FollowRepository>();
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                if (youConnectTo) {
                                  // Disconnect
                                  await repo.unfollowUser(post.authorId);
                                } else {
                                  // Connect or Connect Back
                                  await repo.followUser(post.authorId);
                                }
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update connection', style: GoogleFonts.inter()),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: youConnectTo ? Colors.grey[700] : const Color(0xFFBFAE01),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                youConnectTo
                                    ? Provider.of<LanguageProvider>(context, listen: false).t('connections.disconnect')
                                    : (theyConnectToYou
                                        ? Provider.of<LanguageProvider>(context, listen: false).t('connections.connect_back')
                                        : Provider.of<LanguageProvider>(context, listen: false).t('connections.connect')),
                                style: GoogleFonts.inter(
                                  color: youConnectTo ? Colors.white : Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Post text with expand/collapse
                if (post.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedTexts[post.id] = !isExpanded;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpanded
                              ? post.text
                              : (post.text.length > 100
                                  ? '${post.text.substring(0, 100)}...'
                                  : post.text),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 128),
                              ),
                            ],
                          ),
                        ),
                        if (post.text.length > 100)
                          Text(
                            isExpanded ? Provider.of<LanguageProvider>(context, listen: false).t('video.read_less') : Provider.of<LanguageProvider>(context, listen: false).t('video.read_more'),
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withValues(alpha: 128),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Video progress bar
                if (post.videoUrl != null)
                  (_videoPlayerKeys[post.videoUrl!]?.currentState
                          ?.buildProgressBar() ??
                      const SizedBox.shrink()),
              ],
            ),
          ),

          // Action buttons
          Positioned(
            bottom: 50,
            right: 16,
            child: Column(
              children: [
                // Like button - long press to show reactions
                _buildActionButton(
                  icon: post.userReaction == null
                      ? Ionicons.heart_outline
                      : Ionicons.heart,
                  count: post.counts.likes,
                  isActive: post.userReaction != null,
                  onLongPress: () => _showReactions(post.id),
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Comment button
                _buildActionButton(
                  icon: Ionicons.chatbubble_outline,
                  count: post.counts.comments,
                  onTap: () {
                    _showComments(context, post.id);
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Share button
                _buildActionButton(
                  icon: Ionicons.arrow_redo_outline,
                  count: post.counts.shares,
                  onTap: () {
                    ShareBottomSheet.show(
                      context,
                      onStories: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('video.added_stories'),
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                        );
                      },
                      onCopyLink: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('video.link_copied'),
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                        );
                      },
                      onTelegram: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('video.shared_telegram'),
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                        );
                      },
                      onFacebook: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('video.shared_facebook'),
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                        );
                      },
                      onMore: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('video.more_share_soon'),
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                        );
                      },
                      onSendToUsers: (selectedUsers, message) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${Provider.of<LanguageProvider>(context, listen: false).t('video.sent_to')}${selectedUsers.length} ${selectedUsers.length == 1 ? Provider.of<LanguageProvider>(context, listen: false).t('video.person') : Provider.of<LanguageProvider>(context, listen: false).t('video.people')}!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                        );
                      },
                    );
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Bookmark button
                _buildActionButton(
                  icon: post.isBookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
                  count: post.counts.bookmarks,
                  isActive: post.isBookmarked,
                  onTap: () => _toggleBookmark(post.id),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    required bool isDark,
    bool isActive = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 128)
                  : Colors.white.withValues(alpha: 128),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCount(count),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _showComments(BuildContext context, String postId) async {
  final ctx = context;
  final isDark = Theme.of(ctx).brightness == Brightness.dark;

  List<Comment> comments = [];
  try {
    comments = await _loadCommentsForPost(postId);
  } catch (e) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('video.load_comments_failed')}${_toError(e)}', style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ),
    );
  }

  if (!ctx.mounted) return;

  CommentBottomSheet.show(
    ctx,
    postId: postId,
    comments: comments,
    currentUserId: _currentUserId ?? '',
    isDarkMode: isDark,
    onAddComment: (text) async {
      try {
        await _commentRepo.createComment(postId: postId, text: text);

        // Optimistically increment comments count on the post
        final idx = _findPostIndex(postId);
        if (idx != -1) {
          final p = _videoPosts[idx];
          final updatedCounts = PostCounts(
            likes: p.counts.likes,
            comments: p.counts.comments + 1,
            shares: p.counts.shares,
            reposts: p.counts.reposts,
            bookmarks: p.counts.bookmarks,
          );
          setState(() {
            _videoPosts[idx] = p.copyWith(counts: updatedCounts);
          });
          // Emit event for other pages to sync
          PostEvents.emit(PostUpdateEvent(
            originalPostId: p.originalPostId ?? p.id,
            counts: updatedCounts,
            userReaction: p.userReaction,
            isBookmarked: p.isBookmarked,
          ));
        }

        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('video.comment_posted'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } catch (e) {
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('video.post_comment_failed')}${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    },
    onReplyToComment: (commentId, replyText) async {
      try {
        await _commentRepo.createComment(postId: postId, text: replyText, parentCommentId: commentId);
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('video.reply_posted'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } catch (e) {
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('video.reply_failed')}${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      return Comment(
        id: m.id,
        userId: m.authorId,
        userName: (u?.displayName ?? u?.username ?? Provider.of<LanguageProvider>(context, listen: false).t('video.user')),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}