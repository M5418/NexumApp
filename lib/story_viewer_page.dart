import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'widgets/share_bottom_sheet.dart';

enum StoryMediaType { image, video, text }

class StoryItem {
  final StoryMediaType type;
  final String? imageUrl;
  final String? videoUrl;
  final String? text;
  final Color? backgroundColor;
  final String? audioUrl;
  final String? audioTitle;

  const StoryItem.image({
    required this.imageUrl,
    this.audioUrl,
    this.audioTitle,
  }) : type = StoryMediaType.image,
       videoUrl = null,
       text = null,
       backgroundColor = null;

  const StoryItem.video({required this.videoUrl})
    : type = StoryMediaType.video,
      imageUrl = null,
      text = null,
      backgroundColor = null,
      audioUrl = null,
      audioTitle = null;

  const StoryItem.text({required this.text, this.backgroundColor})
    : type = StoryMediaType.text,
      imageUrl = null,
      videoUrl = null,
      audioUrl = null,
      audioTitle = null;
}

class StoryUser {
  final String name;
  final String handle;
  final String avatarUrl;
  final List<StoryItem> items;

  const StoryUser({
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.items,
  });
}

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> rings; // From SampleData.getSampleStories()
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
  const _StoryFrame({
    required this.user,
    required this.userIndex,
    required this.itemIndex,
    required this.item,
  });
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  late final List<StoryUser> _users;
  late final List<_StoryFrame> _frames;
  int _currentIndex = 0;

  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isMuted = false;
  bool _liked = false;

  final TextEditingController _commentController = TextEditingController();

  AnimationController? _progressController;

  @override
  void initState() {
    super.initState();
    _users = _buildUsersFromRings(widget.rings);
    _frames = _flattenFrames(_users);
    _currentIndex = _initialFrameIndexFromRingIndex(
      widget.initialRingIndex,
      widget.rings,
      _users,
      _frames,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.jumpToPage(_currentIndex);
      _startPlaybackForFrame(_frames[_currentIndex]);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _disposePlayers();
    _progressController?.dispose();
    _pageController.dispose();
    super.dispose();
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

  List<StoryUser> _buildUsersFromRings(List<Map<String, dynamic>> rings) {
    final filtered = rings
        .where((r) => (r['isMine'] as bool?) != true)
        .toList();
    return List<StoryUser>.generate(filtered.length, (i) {
      final r = filtered[i];
      final name = (r['label'] as String?) ?? 'User';
      final avatar =
          (r['imageUrl'] as String?) ??
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face';
      final handle = '@${name.toLowerCase().replaceAll(' ', '')}';

      final items = <StoryItem>[
        StoryItem.image(
          imageUrl:
              'https://images.unsplash.com/photo-1542736667-069246bdbc74?w=1080&fit=crop',
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          audioTitle: 'SoundHelix Song 1',
        ),
        const StoryItem.text(
          text:
              "Energy's rising ✨🕺\nPartyPlanet Crew is taking over the night 🎶\nLet's vibe, dance, and shine together ✨",
          backgroundColor: Color(0xFFE74C3C),
        ),
        const StoryItem.video(
          videoUrl:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        ),
      ];

      return StoryUser(
        name: name,
        handle: handle,
        avatarUrl: avatar,
        items: items,
      );
    });
  }

  List<_StoryFrame> _flattenFrames(List<StoryUser> users) {
    final res = <_StoryFrame>[];
    for (var i = 0; i < users.length; i++) {
      final u = users[i];
      for (var j = 0; j < u.items.length; j++) {
        res.add(
          _StoryFrame(user: u, userIndex: i, itemIndex: j, item: u.items[j]),
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
        final p = AudioPlayer();
        _audioPlayer = p;
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(_isMuted ? 0.0 : 1.0);
        await p.play(UrlSource(audioUrl));
      }
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
      body: SafeArea(
        bottom: false,
        child: NotificationListener<OverscrollNotification>(
          onNotification: (n) {
            if (_currentIndex == _frames.length - 1 && n.overscroll > 0) {
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
                    _liked = false;
                  });
                  await _startPlaybackForFrame(_frames[i]);
                },
                itemBuilder: (context, index) => _buildFrame(_frames[index]),
              ),

              // Top gradient for readability
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
                        Colors.black.withValues(alpha: 153), // ~0.6
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Progress bars (per current user's story count)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: _buildProgressBars(),
              ),

              // Header
              Positioned(top: 40, left: 12, right: 12, child: _header()),

              // Tap zones to navigate left/right like Instagram stories
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
              Positioned(left: 12, right: 12, bottom: 24, child: _commentBar()),
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
            aspectRatio: vc.value.aspectRatio == 0
                ? 9 / 16
                : vc.value.aspectRatio,
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
        Container(
          width: 36,
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: CachedNetworkImage(
            imageUrl: f.user.avatarUrl,
            fit: BoxFit.cover,
            placeholder: (c, u) =>
                Container(color: const Color(0xFF666666).withValues(alpha: 51)),
            errorWidget: (c, u, e) =>
                const Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Handle + Connect
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.user.handle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'Connect',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 179),
                ),
              ),
            ],
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
                Expanded(
                  child: Text(
                    f.item.audioTitle ?? 'Music',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
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
                style: GoogleFonts.inter(color: Colors.black),
                cursorColor: const Color(0xFFBFAE01),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your comment...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                    fontSize: 14,
                  ),
                ),
                onSubmitted: (_) =>
                    _snack('Comment sent (UI only)', const Color(0xFFBFAE01)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Share button (paper plane)
        GestureDetector(
          onTap: _share,
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
        // Like button
        GestureDetector(
          onTap: () => setState(() => _liked = !_liked),
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
}
