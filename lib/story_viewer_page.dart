import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'core/i18n/language_provider.dart';
import 'utils/profile_navigation.dart';
import 'repositories/interfaces/story_repository.dart';
import 'local/local_store.dart';
import 'local/repositories/local_story_repository.dart';

import 'widgets/share_bottom_sheet.dart';
import 'widgets/report_bottom_sheet.dart';

/// Transparent page route for story viewer to show feed behind during drag
class TransparentRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  
  TransparentRoute({required this.builder}) : super();
  
  @override
  bool get opaque => false;
  
  @override
  Color? get barrierColor => null;
  
  @override
  String? get barrierLabel => null;
  
  @override
  bool get maintainState => true;
  
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  
  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }
  
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

enum StoryMediaType { image, video, text }

// Popup wrapper to show a centered story viewer dialog
class StoryViewerPopup {
  static Future<T?> show<T>(
    BuildContext context, {
    required List<Map<String, dynamic>> rings,
    required int initialRingIndex,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'View Story',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 860),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: StoryViewerPage(
                  rings: rings,
                  initialRingIndex: initialRingIndex,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class StoryItem {
  final StoryMediaType type;
  final String? imageUrl;
  final String? videoUrl;
  final String? text;
  final Color? backgroundColor;
  final String? audioUrl;
  final String? audioTitle;

  // New (UI-state mirrors backend)
  final bool liked;
  final int likesCount;
  final int commentsCount;
  final bool viewed; // Whether this story has been viewed by current user

  const StoryItem.image({
    required this.imageUrl,
    this.audioUrl,
    this.audioTitle,
    this.liked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewed = false,
  })  : type = StoryMediaType.image,
        videoUrl = null,
        text = null,
        backgroundColor = null;

  const StoryItem.video({
    required this.videoUrl,
    this.audioUrl,
    this.audioTitle,
    this.liked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewed = false,
  })  : type = StoryMediaType.video,
        imageUrl = null,
        text = null,
        backgroundColor = null;

  const StoryItem.text({
    required this.text,
    this.backgroundColor,
    this.liked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewed = false,
  })  : type = StoryMediaType.text,
        imageUrl = null,
        videoUrl = null,
        audioUrl = null,
        audioTitle = null;
}

class StoryUser {
  final String userId;
  final String name;     // Full name
  final String handle;   // @username (for other uses)
  final String? avatarUrl; // Nullable; only show when provided
  final List<StoryItem> items;
  final List<String?> itemIds;

  const StoryUser({
    required this.userId,
    required this.name,
    required this.handle,
    this.avatarUrl,
    required this.items,
    required this.itemIds,
  });
}

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> rings; // From Home rings
  final int initialRingIndex;

  const StoryViewerPage({
    super.key,
    required this.rings,
    required this.initialRingIndex,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryFrame {
  final StoryUser user;
  final int userIndex;
  final int itemIndex;
  final StoryItem item;
  final String? storyId;
  const _StoryFrame({
    required this.user,
    required this.userIndex,
    required this.itemIndex,
    required this.item,
    required this.storyId,
  });
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  List<StoryUser> _users = [];
  List<_StoryFrame> _frames = [];
  int _currentIndex = 0;
  bool _loading = true;

  // Stories API removed - will be handled elsewhere
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isMuted = false;
  bool _liked = false;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  AnimationController? _progressController;
  
  // Drag-to-dismiss state
  double _dragOffset = 0.0;
  double _dragScale = 1.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadFromCacheInstantly();
    _initFromBackend();
    
    // Pause story when typing, resume when done
    _commentFocusNode.addListener(() {
      if (_commentFocusNode.hasFocus) {
        _pauseStory();
      } else {
        _resumeStory();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _disposePlayers();
    _progressController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// ISAR-FIRST: Load stories from local cache instantly for fast UI
  void _loadFromCacheInstantly() {
    if (!isIsarSupported) return;
    
    try {
      final users = <StoryUser>[];
      for (final ring in widget.rings) {
        final userId = (ring['userId'] ?? '').toString();
        if (userId.isEmpty) continue;
        
        // Get cached stories for this user
        final cachedStories = LocalStoryRepository().getByAuthorSync(userId, limit: 20);
        if (cachedStories.isEmpty) continue;
        
        final items = <StoryItem>[];
        final ids = <String?>[];
        
        for (final s in cachedStories) {
          switch (s.type) {
            case 'image':
              items.add(StoryItem.image(
                imageUrl: s.mediaUrl,
                viewed: s.viewed,
              ));
              ids.add(s.id);
              break;
            case 'video':
              items.add(StoryItem.video(
                videoUrl: s.mediaUrl,
                viewed: s.viewed,
              ));
              ids.add(s.id);
              break;
            case 'text':
              Color? bg;
              final hex = s.backgroundColor;
              if (hex != null && hex.isNotEmpty) bg = _parseHexColor(hex);
              items.add(StoryItem.text(
                text: s.text,
                backgroundColor: bg,
                viewed: s.viewed,
              ));
              ids.add(s.id);
              break;
            default:
              items.add(StoryItem.image(imageUrl: s.mediaUrl, viewed: s.viewed));
              ids.add(s.id);
          }
        }
        
        if (items.isNotEmpty) {
          users.add(StoryUser(
            userId: userId,
            name: (ring['label'] ?? '').toString(),
            handle: '@',
            avatarUrl: (ring['imageUrl'] ?? '').toString(),
            items: items,
            itemIds: ids,
          ));
        }
      }
      
      if (users.isNotEmpty && mounted) {
        _users = users;
        _frames = _flattenFrames(_users);
        _currentIndex = _initialFrameIndexFromRingIndex(
          widget.initialRingIndex,
          widget.rings,
          _users,
          _frames,
        );
        
        setState(() {
          _loading = false;
          if (_frames.isNotEmpty) {
            _liked = _frames[_currentIndex].item.liked;
          }
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _frames.isEmpty) return;
          _pageController.jumpToPage(_currentIndex);
          _startPlaybackForFrame(_frames[_currentIndex]);
        });
        
        debugPrint('📱 [FastStory] Loaded ${_frames.length} stories from Isar cache');
      }
    } catch (e) {
      debugPrint('⚠️ [FastStory] Cache load failed: $e');
    }
  }

  Future<void> _initFromBackend() async {
    try {
      final repo = context.read<StoryRepository>();
      final users = <StoryUser>[];
      for (final ring in widget.rings) {
        final userId = (ring['userId'] ?? '').toString();
        if (userId.isEmpty) continue;
        final models = await repo.getUserStories(userId);
        if (models.isEmpty) continue;
        final items = <StoryItem>[];
        final ids = <String?>[];
        for (final s in models) {
          switch (s.mediaType) {
            case 'image':
              items.add(StoryItem.image(
                imageUrl: s.mediaUrl,
                audioUrl: s.audioUrl,
                audioTitle: s.audioTitle,
                liked: s.liked,
                likesCount: s.likesCount,
                commentsCount: s.commentsCount,
                viewed: s.viewed,
              ));
              ids.add(s.id);
              break;
            case 'video':
              items.add(StoryItem.video(
                videoUrl: s.mediaUrl,
                audioUrl: s.audioUrl,
                audioTitle: s.audioTitle,
                liked: s.liked,
                likesCount: s.likesCount,
                commentsCount: s.commentsCount,
                viewed: s.viewed,
              ));
              ids.add(s.id);
              break;
            case 'text':
              Color? bg;
              final hex = s.backgroundColor?.toString();
              if (hex != null && hex.isNotEmpty) bg = _parseHexColor(hex);
              items.add(StoryItem.text(
                text: s.textContent,
                backgroundColor: bg,
                liked: s.liked,
                likesCount: s.likesCount,
                commentsCount: s.commentsCount,
                viewed: s.viewed,
              ));
              ids.add(s.id);
              break;
            default:
              // Fallback treat as image
              items.add(StoryItem.image(imageUrl: s.mediaUrl, viewed: s.viewed));
              ids.add(s.id);
          }
        }
        users.add(StoryUser(
          userId: userId,
          name: (ring['label'] ?? '').toString(),
          handle: '@',
          avatarUrl: (ring['imageUrl'] ?? '').toString(),
          items: items,
          itemIds: ids,
        ));
      }

      _users = users;
      _frames = _flattenFrames(_users);
      _currentIndex = _initialFrameIndexFromRingIndex(
        widget.initialRingIndex,
        widget.rings,
        _users,
        _frames,
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_frames.isNotEmpty) {
          _liked = _frames[_currentIndex].item.liked;
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _frames.isEmpty) return;
        _pageController.jumpToPage(_currentIndex);
        _startPlaybackForFrame(_frames[_currentIndex]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _users = [];
        _frames = [];
        _loading = false;
      });
    }
  }

  void _disposePlayers() {
    final v = _videoController;
    _videoController = null;
    if (v != null) {
      v.pause();
      v.dispose();
    }
    final a = _audioPlayer;
    _audioPlayer = null;
    if (a != null) {
      a.stop();
      a.dispose();
    }
  }

  List<_StoryFrame> _flattenFrames(List<StoryUser> users) {
    final res = <_StoryFrame>[];
    for (var i = 0; i < users.length; i++) {
      final u = users[i];
      for (var j = 0; j < u.items.length; j++) {
        final sid = (u.itemIds.length > j) ? u.itemIds[j] : null;
        res.add(
          _StoryFrame(
            user: u,
            userIndex: i,
            itemIndex: j,
            item: u.items[j],
            storyId: sid,
          ),
        );
      }
    }
    return res;
  }

  int _initialFrameIndexFromRingIndex(
    int tappedRingIndex,
    List<Map<String, dynamic>> rings,
    List<StoryUser> users,
    List<_StoryFrame> frames,
  ) {
    if (tappedRingIndex < 0 || tappedRingIndex >= rings.length || frames.isEmpty) {
      return 0;
    }
    
    // Get the userId of the tapped ring
    final tappedRing = rings[tappedRingIndex];
    final tappedUserId = (tappedRing['userId'] ?? '').toString();
    
    if (tappedUserId.isEmpty) return 0;
    
    // Find the first UNSEEN frame for this user (resume from where they left off)
    for (int k = 0; k < frames.length; k++) {
      if (frames[k].user.userId == tappedUserId && !frames[k].item.viewed) {
        return k;
      }
    }
    
    // If all stories are viewed, start from the first story of this user
    for (int k = 0; k < frames.length; k++) {
      if (frames[k].user.userId == tappedUserId && frames[k].itemIndex == 0) {
        return k;
      }
    }
    
    // Fallback: find any frame for this user
    for (int k = 0; k < frames.length; k++) {
      if (frames[k].user.userId == tappedUserId) {
        return k;
      }
    }
    
    return 0;
  }

  Future<void> _startPlaybackForFrame(_StoryFrame frame) async {
    // Capture repository before async gap
    final storyRepo = context.read<StoryRepository>();
    
    _disposePlayers();
    
    // Preload next story media for smooth transitions
    _preloadNextStory();
    
    if (frame.item.type == StoryMediaType.video) {
      final url = frame.item.videoUrl;
      if (url == null) return;
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _videoController = c;
      await c.initialize();
      await c.setLooping(true);
      
      // If story has custom audio, mute video and play the audio track instead
      final audioUrl = frame.item.audioUrl;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await c.setVolume(0.0); // Mute video's native audio
        try {
          final p = AudioPlayer();
          _audioPlayer = p;
          await p.setReleaseMode(ReleaseMode.loop);
          await p.setVolume(_isMuted ? 0.0 : 1.0);
          await p.play(UrlSource(audioUrl));
        } catch (e) {
          debugPrint('🎵 [Story] Could not play audio: $e');
          _audioPlayer = null;
        }
      } else {
        await c.setVolume(_isMuted ? 0.0 : 1.0);
      }
      
      if (mounted) setState(() {});
      unawaited(c.play());
    } else if (frame.item.type == StoryMediaType.image) {
      final audioUrl = frame.item.audioUrl;
      if (audioUrl != null) {
        try {
          final p = AudioPlayer();
          _audioPlayer = p;
          await p.setReleaseMode(ReleaseMode.loop);
          await p.setVolume(_isMuted ? 0.0 : 1.0);
          await p.play(UrlSource(audioUrl));
        } catch (e) {
          // Silently fail on CORS errors (common on web with external audio)
          debugPrint('🎵 [Story] Could not play audio: $e');
          _audioPlayer = null;
        }
      }
    }
    
    // Mark as viewed asynchronously without blocking
    final sid = frame.storyId;
    if (sid != null) {
      unawaited(storyRepo.viewStory(sid).catchError((_) {}));
    }
    
    _startProgressForFrame(frame);
  }
  
  // Preload next story for smooth transitions
  void _preloadNextStory() {
    if (_currentIndex + 1 < _frames.length) {
      final nextFrame = _frames[_currentIndex + 1];
      // Preload images using cached_network_image precache
      if (nextFrame.item.type == StoryMediaType.image) {
        final imageUrl = nextFrame.item.imageUrl;
        if (imageUrl != null) {
          unawaited(
            precacheImage(
              CachedNetworkImageProvider(imageUrl),
              context,
            ).catchError((_) {}),
          );
        }
      }
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    final v = _videoController;
    final a = _audioPlayer;
    // If we have custom audio playing, only toggle audio player (keep video muted)
    if (a != null) {
      unawaited(a.setVolume(_isMuted ? 0.0 : 1.0));
    } else if (v != null) {
      // No custom audio - toggle video's native audio
      unawaited(v.setVolume(_isMuted ? 0.0 : 1.0));
    }
  }

  Duration _durationForItem(StoryItem item, {Duration? videoDuration}) {
    // Photos/Text: 5 seconds, Videos: actual duration capped at 30s
    switch (item.type) {
      case StoryMediaType.video:
        if (videoDuration != null) {
          // Cap at 30 seconds max
          final maxDuration = const Duration(seconds: 30);
          return videoDuration > maxDuration ? maxDuration : videoDuration;
        }
        return const Duration(seconds: 30); // Fallback
      case StoryMediaType.image:
      case StoryMediaType.text:
        return const Duration(seconds: 5);
    }
  }

  void _startProgressForFrame(_StoryFrame frame) {
    // Safely dispose old controller if it exists and hasn't been disposed
    final oldController = _progressController;
    _progressController = null;
    if (oldController != null) {
      try {
        oldController.stop();
        oldController.dispose();
      } catch (_) {
        // Already disposed, ignore
      }
    }
    
    if (!mounted) return;
    
    // Get video duration if this is a video story
    Duration? videoDuration;
    if (frame.item.type == StoryMediaType.video && _videoController != null) {
      videoDuration = _videoController!.value.duration;
    }
    
    final controller = AnimationController(
      vsync: this,
      duration: _durationForItem(frame.item, videoDuration: videoDuration),
      animationBehavior: AnimationBehavior.preserve,
    );
    _progressController = controller;
    
    // Add listener to trigger rebuild for progress bar animation
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });
    controller.forward();
  }

  void _goToNextStory() {
    if (_currentIndex < _frames.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _share() {
    ShareBottomSheet.show(
      context,
      onStories: () => _snack('Shared to Stories', const Color(0xFF4CAF50)),
      onCopyLink: () =>
          _snack('Link copied to clipboard', const Color(0xFF9E9E9E)),
      onTelegram: () => _snack('Shared to Telegram', const Color(0xFF0088CC)),
      onFacebook: () => _snack('Shared to Facebook', const Color(0xFF1877F2)),
      onMore: () => _snack('More share options', const Color(0xFF666666)),
      onSendToUsers: (users, msg) => _snack(
        'Sent to ${users.map((u) => u.name).join(', ')}${msg.isNotEmpty ? ' with message: "$msg"' : ''}',
        const Color(0xFFBFAE01),
      ),
    );
  }

  void _snack(String text, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.inter()),
        backgroundColor: bg,
      ),
    );
  }

  void _pauseStory() {
    try {
      _progressController?.stop();
    } catch (_) {
      // Controller may be disposed, ignore
    }
    final v = _videoController;
    if (v != null && v.value.isInitialized && v.value.isPlaying) {
      v.pause();
    }
    final a = _audioPlayer;
    if (a != null) {
      unawaited(a.pause());
    }
  }

  void _resumeStory() {
    try {
      final pc = _progressController;
      if (pc != null && !pc.isAnimating && pc.value < 1.0) {
        pc.forward();
      }
    } catch (_) {
      // Controller may be disposed, ignore
    }
    final v = _videoController;
    if (v != null && v.value.isInitialized && !v.value.isPlaying) {
      unawaited(v.play());
    }
    final a = _audioPlayer;
    if (a != null) {
      unawaited(a.resume());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate background opacity based on drag (fades as you drag down)
    final bgOpacity = (1.0 - (_dragOffset / 300)).clamp(0.0, 1.0);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: Colors.black.withValues(alpha: bgOpacity),
        child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
              ),
            )
          : _frames.isEmpty
              ? Center(
                  child: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('story.no_stories'),
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                )
              : SafeArea(
                  bottom: false,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (_) {
                      _isDragging = true;
                      _pauseStory();
                    },
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy > 0) {
                        setState(() {
                          _dragOffset += details.delta.dy;
                          _dragScale = (1 - (_dragOffset / 800)).clamp(0.8, 1.0);
                        });
                      }
                    },
                    onVerticalDragEnd: (details) {
                      _isDragging = false;
                      if (_dragOffset > 150 || details.velocity.pixelsPerSecond.dy > 500) {
                        // Dismiss with animation
                        Navigator.of(context).pop();
                      } else {
                        // Snap back
                        setState(() {
                          _dragOffset = 0;
                          _dragScale = 1.0;
                        });
                        _resumeStory();
                      }
                    },
                    child: AnimatedContainer(
                      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      transformAlignment: Alignment.center,
                      transform: Matrix4.translationValues(0.0, _dragOffset, 0.0)
                        ..multiply(Matrix4.diagonal3Values(_dragScale, _dragScale, 1.0)),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: _dragOffset > 0 
                            ? BorderRadius.circular(25) 
                            : BorderRadius.zero,
                      ),
                      clipBehavior: _dragOffset > 0 ? Clip.antiAlias : Clip.none,
                      child: NotificationListener<OverscrollNotification>(
                        onNotification: (n) {
                          if (_currentIndex == _frames.length - 1 &&
                              n.overscroll > 0) {
                            Navigator.of(context).maybePop();
                          }
                          return false;
                        },
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: _frames.length,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              onPageChanged: (i) async {
                                setState(() {
                                  _currentIndex = i;
                                  _liked = _frames[i].item.liked;
                                  _commentController.clear();
                                });
                                await _startPlaybackForFrame(_frames[i]);
                              },
                              itemBuilder: (context, index) =>
                                  _buildFrame(_frames[index]),
                            ),

                            // Top gradient
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 153),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Progress bars
                            Positioned(
                              top: 8,
                              left: 8,
                              right: 8,
                              child: _buildProgressBars(),
                            ),

                            // Header
                            Positioned(top: 40, left: 12, right: 12, child: _header()),

                            // Tap zones
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 80,
                              bottom: 120,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPressStart: (_) => _pauseStory(),
                                onLongPressEnd: (_) => _resumeStory(),
                                onLongPressCancel: _resumeStory,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _goToPreviousStory,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _goToNextStory,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Bottom gradient
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 153),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Comment + actions bar
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 24,
                              child: _commentBar(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildFrame(_StoryFrame f) {
    switch (f.item.type) {
      case StoryMediaType.image:
        return CachedNetworkImage(
          imageUrl: f.item.imageUrl ?? '',
          fit: BoxFit.cover,
          placeholder: (c, u) =>
              Container(color: const Color(0xFF666666).withValues(alpha: 51)),
          errorWidget: (c, u, e) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white),
          ),
        );
      case StoryMediaType.video:
        final vc = _videoController;
        if (vc == null || !vc.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
            ),
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: vc.value.aspectRatio == 0 ? 9 / 16 : vc.value.aspectRatio,
            child: VideoPlayer(vc),
          ),
        );
      case StoryMediaType.text:
        return Container(
          color: f.item.backgroundColor ?? const Color(0xFFE74C3C),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            f.item.text ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              height: 1.4,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  Widget _header() {
    final f = _frames[_currentIndex];
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 204),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: Colors.black),
          ),
        ),
        const SizedBox(width: 8),
        // Avatar
        GestureDetector(
          onTap: () {
            navigateToUserProfile(
              context: context,
              userId: f.user.userId,
              userName: f.user.name,
              userAvatarUrl: f.user.avatarUrl ?? '',
              userBio: '',
            );
          },
          child: Container(
            width: 36,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: (f.user.avatarUrl != null && f.user.avatarUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: f.user.avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (c, u) =>
                        Container(color: const Color(0xFF666666).withValues(alpha: 51)),
                    errorWidget: (c, u, e) =>
                        const Icon(Icons.person, color: Colors.white, size: 18),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Full name and subline
        Expanded(
          child: GestureDetector(
            onTap: () {
              navigateToUserProfile(
                context: context,
                userId: f.user.userId,
                userName: f.user.name,
                userAvatarUrl: f.user.avatarUrl ?? '',
                userBio: '',
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.user.name, // Full name
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('story.connect'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 179),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Music chip when image story has audio
        if (f.item.type == StoryMediaType.image && f.item.audioUrl != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 128),
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: const BoxConstraints(maxWidth: 160),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note, size: 16, color: Colors.black),
                const SizedBox(width: 6),
                Text(
                  f.item.audioTitle ?? Provider.of<LanguageProvider>(context, listen: false).t('story.music'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Mute button
        GestureDetector(
          onTap: _toggleMute,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 204),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Report button (only for other users' stories)
        if (!_isMyStory(f))
          GestureDetector(
            onTap: () {
              final sid = f.storyId;
              if (sid == null) return;
              ReportBottomSheet.show(
                context,
                targetType: 'story',
                targetId: sid,
                authorName: f.user.name,
                authorUsername: f.user.handle,
              );
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 204),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_outlined, size: 18, color: Colors.red),
            ),
          ),
        // Ellipsis menu (only for own stories)
        if (_isMyStory(f))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showStoryDetailsSheet(f),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 204),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz, size: 18, color: Colors.black),
            ),
          ),
      ],
    );
  }
  
  bool _isMyStory(_StoryFrame f) {
    // Check if this story belongs to the current user
    final ring = widget.rings.firstWhere(
      (r) => r['userId'] == f.user.userId,
      orElse: () => {},
    );
    return ring['isMine'] == true;
  }
  
  void _showStoryDetailsSheet(_StoryFrame f) {
    _pauseStory();
    final sid = f.storyId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final lang = Provider.of<LanguageProvider>(ctx, listen: false);
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    lang.t('story.story_details'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Likes
                      _statItem(
                        icon: Icons.favorite,
                        count: f.item.likesCount,
                        label: lang.t('story.likes'),
                        color: Colors.red,
                        isDark: isDark,
                      ),
                      // Comments
                      _statItem(
                        icon: Icons.chat_bubble,
                        count: f.item.commentsCount,
                        label: lang.t('story.comments'),
                        color: const Color(0xFFBFAE01),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Delete button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _confirmDeleteStory(sid);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: Text(
                        lang.t('story.delete_story'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _resumeStory();
    });
  }
  
  Widget _statItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
  
  Future<void> _confirmDeleteStory(String? storyId) async {
    if (storyId == null) return;
    
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('story.delete_story_title'), style: GoogleFonts.inter()),
        content: Text(
          lang.t('story.delete_story_message'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('story.cancel'), style: GoogleFonts.inter(color: const Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lang.t('story.delete'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      try {
        final storyRepo = context.read<StoryRepository>();
        await storyRepo.deleteStory(storyId);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.t('story.story_deleted'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFBFAE01),
          ),
        );
        
        // Go to next story or close viewer if no more stories
        if (_currentIndex < _frames.length - 1) {
          _goToNextStory();
        } else if (_currentIndex > 0) {
          _goToPreviousStory();
        } else {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.t('story.delete_failed'), style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }  

    Widget _buildProgressBars() {
    final frame = _frames[_currentIndex];
    final total = frame.user.items.length;
    final active = frame.itemIndex;
    final value = _progressController?.value ?? 0.0;

    Widget bars() {
      return Row(
        children: List.generate(total, (i) {
          final double fill;
          if (i < active) {
            fill = 1.0;
          } else if (i == active) {
            fill = value.clamp(0.0, 1.0);
          } else {
            fill = 0.0;
          }
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 77),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }

    final controller = _progressController;
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => bars(),
      );
    }
    return bars();
  }

  Widget _commentBar() {
    final f = _frames.isNotEmpty ? _frames[_currentIndex] : null;
    final isMyStory = f != null && _isMyStory(f);
    
    // For own stories, only show share button
    if (isMyStory) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Share button only for own stories
          GestureDetector(
            onTap: _share,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 64),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.ios_share, color: Colors.black),
            ),
          ),
        ],
      );
    }
    
    Future<void> sendComment() async {
      final text = _commentController.text.trim();
      if (text.isEmpty || _frames.isEmpty) return;
      final sid = _frames[_currentIndex].storyId;
      if (sid == null) return;
      
      // Immediately clear text and unfocus for instant feedback
      _commentController.clear();
      _commentFocusNode.unfocus();
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final storyRepo = context.read<StoryRepository>();
      _snack(lang.t('story.sending'), const Color(0xFFBFAE01));
      
      // Send in background without blocking UI
      try {
        await storyRepo.replyToStory(storyId: sid, message: text);
        _snack(lang.t('story.reply_sent'), const Color(0xFFBFAE01));
      } catch (e) {
        _snack(lang.t('story.reply_failed'), Colors.red);
      }
    }

    return Row(
      children: [
        // Comment field
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Center(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                style: GoogleFonts.inter(color: Colors.black),
                cursorColor: const Color(0xFFBFAE01),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: Provider.of<LanguageProvider>(context, listen: false).t('story.comment_hint'),
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                    fontSize: 14,
                  ),
                ),
                onSubmitted: (_) => sendComment(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Send comment button (sends a chat message to the user)
        GestureDetector(
          onTap: sendComment,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 64),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Colors.black),
          ),
        ),
        const SizedBox(width: 10),
        // Share button (explicit share icon)
        GestureDetector(
          onTap: _share,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 64),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.ios_share, color: Colors.black),
          ),
        ),
        const SizedBox(width: 10),
        // Like button - FASTFEED: Optimistic update
        GestureDetector(
          onTap: () {
            final sid = _frames.isNotEmpty ? _frames[_currentIndex].storyId : null;
            if (sid == null) return;
            
            // Optimistic update - instant UI feedback
            final wasLiked = _liked;
            setState(() {
              _liked = !wasLiked;
            });
            
            // Background API call
            final repo = context.read<StoryRepository>();
            if (wasLiked) {
              repo.unlikeStory(sid).catchError((_) {
                // Revert on failure
                if (mounted) setState(() => _liked = wasLiked);
              });
            } else {
              repo.likeStory(sid).catchError((_) {
                // Revert on failure
                if (mounted) setState(() => _liked = wasLiked);
              });
            }
          },
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 64),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              color: _liked ? const Color(0xFFE91E63) : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Color _parseHexColor(String input) {
    var hex = input.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final value = int.tryParse(hex, radix: 16) ?? 0xFFFF0000;
    return Color(value);
  }
}