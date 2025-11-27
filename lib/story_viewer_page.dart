import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'core/i18n/language_provider.dart';
import 'other_user_profile_page.dart';
import 'profile_page.dart';
import 'repositories/interfaces/story_repository.dart';

import 'widgets/share_bottom_sheet.dart';
import 'widgets/report_bottom_sheet.dart';

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

  const StoryItem.image({
    required this.imageUrl,
    this.audioUrl,
    this.audioTitle,
    this.liked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
  })  : type = StoryMediaType.image,
        videoUrl = null,
        text = null,
        backgroundColor = null;

  const StoryItem.video({
    required this.videoUrl,
    this.liked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
  })  : type = StoryMediaType.video,
        imageUrl = null,
        text = null,
        backgroundColor = null,
        audioUrl = null,
        audioTitle = null;

  const StoryItem.text({
    required this.text,
    this.backgroundColor,
    this.liked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
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
              ));
              ids.add(s.id);
              break;
            case 'video':
              items.add(StoryItem.video(
                videoUrl: s.mediaUrl,
                liked: s.liked,
                likesCount: s.likesCount,
                commentsCount: s.commentsCount,
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
              ));
              ids.add(s.id);
              break;
            default:
              // Fallback treat as image
              items.add(StoryItem.image(imageUrl: s.mediaUrl));
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
    // If tapping on "Your story" (isMine), start from the first user's first story
    if (tappedRingIndex >= 0 && tappedRingIndex < rings.length) {
      final tapped = rings[tappedRingIndex];
      if ((tapped['isMine'] as bool?) == true) {
        for (int k = 0; k < frames.length; k++) {
          if (frames[k].userIndex == 0 && frames[k].itemIndex == 0) {
            return k;
          }
        }
        return 0;
      }
    }
    int userIdxWithoutMine = 0;
    for (int i = 0; i < rings.length; i++) {
      final r = rings[i];
      if ((r['isMine'] as bool?) == true) continue;
      if (i == tappedRingIndex) break;
      userIdxWithoutMine++;
    }
    userIdxWithoutMine = userIdxWithoutMine.clamp(0, users.length - 1);
    for (int k = 0; k < frames.length; k++) {
      if (frames[k].userIndex == userIdxWithoutMine &&
          frames[k].itemIndex == 0) {
        return k;
      }
    }
    return 0;
  }

  Future<void> _startPlaybackForFrame(_StoryFrame frame) async {
    // Capture repository before async gap
    final storyRepo = context.read<StoryRepository>();
    
    _disposePlayers();
    if (frame.item.type == StoryMediaType.video) {
      final url = frame.item.videoUrl;
      if (url == null) return;
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(_isMuted ? 0.0 : 1.0);
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
    // Mark as viewed
    final sid = frame.storyId;
    if (sid != null) {
      try {
        await storyRepo.viewStory(sid);
      } catch (_) {}
    }
    _startProgressForFrame(frame);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    final v = _videoController;
    if (v != null) unawaited(v.setVolume(_isMuted ? 0.0 : 1.0));
    final a = _audioPlayer;
    if (a != null) unawaited(a.setVolume(_isMuted ? 0.0 : 1.0));
  }

  Duration _durationForItem(StoryItem item) {
    // Videos: 30s, Images/Text: 15s
    switch (item.type) {
      case StoryMediaType.video:
        return const Duration(seconds: 30);
      case StoryMediaType.image:
      case StoryMediaType.text:
        return const Duration(seconds: 15);
    }
  }

  void _startProgressForFrame(_StoryFrame frame) {
    _progressController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: _durationForItem(frame.item),
    );
    _progressController = controller;
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.forward();
  }

  void _goToNextStory() {
    if (_currentIndex < _frames.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
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
    _progressController?.stop();
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
    final pc = _progressController;
    if (pc != null && !pc.isAnimating && pc.value < 1.0) {
      pc.forward();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
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
                          top: 80, // below progress + header
                          bottom: 120, // above comment bar
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (_) => _pauseStory(),
                            onLongPressEnd: (_) => _resumeStory(),
                            onLongPressCancel: _resumeStory,
                            child: Row(
                              children: [
                                // Left 1/3 = previous
                                Expanded(
                                  flex: 1,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _goToPreviousStory,
                                  ),
                                ),
                                // Right 2/3 = next
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
                            left: 12, right: 12, bottom: 24, child: _commentBar()),
                      ],
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
            final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
            if (currentUserId == f.user.userId) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OtherUserProfilePage(
                    userId: f.user.userId,
                    userName: f.user.name,
                    userAvatarUrl: f.user.avatarUrl ?? '',
                    userBio: '',
                  ),
                ),
              );
            }
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
              final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId == f.user.userId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfilePage(
                      userId: f.user.userId,
                      userName: f.user.name,
                      userAvatarUrl: f.user.avatarUrl ?? '',
                      userBio: '',
                    ),
                  ),
                );
              }
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
        // Report button
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
      ],
    );
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
    Future<void> sendComment() async {
      final text = _commentController.text.trim();
      if (text.isEmpty || _frames.isEmpty) return;
      final sid = _frames[_currentIndex].storyId;
      if (sid == null) return;
      
      // Immediately clear text and unfocus for instant feedback
      _commentController.clear();
      _commentFocusNode.unfocus();
      _snack('Sending...', const Color(0xFFBFAE01));
      
      // Send in background without blocking UI
      try {
        await context.read<StoryRepository>().replyToStory(storyId: sid, message: text);
        _snack('Reply sent', const Color(0xFFBFAE01));
      } catch (e) {
        _snack('Failed to reply', Colors.red);
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
        // Like button
        GestureDetector(
          onTap: () async {
            final sid = _frames.isNotEmpty ? _frames[_currentIndex].storyId : null;
            if (sid == null) return;
            try {
              if (_liked) {
                await context.read<StoryRepository>().unlikeStory(sid);
              } else {
                await context.read<StoryRepository>().likeStory(sid);
              }
              if (!mounted) return;
              setState(() {
                _liked = !_liked;
              });
            } catch (e) {
              _snack('Failed to like', Colors.red);
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