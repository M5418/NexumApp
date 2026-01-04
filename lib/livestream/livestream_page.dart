import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/interfaces/livestream_repository.dart';
import '../repositories/models/livestream_model.dart';
import '../other_user_profile_page.dart';
import '../services/agora_service.dart';
import '../services/agora_token_service.dart';
import '../widgets/agora_web_video.dart';

class LiveStreamPage extends StatefulWidget {
  final String streamId;

  const LiveStreamPage({super.key, required this.streamId});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage>
    with TickerProviderStateMixin {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _chatFocusNode = FocusNode();

  LiveStreamModel? _stream;
  List<LiveStreamChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isChatVisible = true;
  bool _isFullscreen = false;
  // Controls always visible - removed auto-hide feature
  // bool _showControls = true;

  AgoraService? _agoraService;
  bool _agoraInitialized = false;
  int? _remoteUid;
  int? _localUid;

  StreamSubscription<LiveStreamModel?>? _streamSub;
  StreamSubscription<List<LiveStreamChatMessage>>? _chatSub;
  StreamSubscription<LiveStreamReaction>? _reactionSub;

  final List<_FloatingReaction> _floatingReactions = [];
  Timer? _controlsTimer;

  static const List<String> _reactionEmojis = ['❤️', '🔥', '👏', '😂', '😮', '🎉'];

  @override
  void initState() {
    super.initState();
    _initAgora();
    _loadStream();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatFocusNode.dispose();
    _streamSub?.cancel();
    _chatSub?.cancel();
    _reactionSub?.cancel();
    _controlsTimer?.cancel();
    _agoraService?.dispose();
    _leaveStream();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      _agoraService = AgoraService();
      
      final agoraSvc = _agoraService;
      if (agoraSvc == null) {
        debugPrint('Failed to create AgoraService');
        return;
      }
      
      // Initialize as viewer (audience)
      final initResult = await agoraSvc.initialize(isBroadcaster: false);
      if (!initResult.success) {
        debugPrint('Agora init failed: ${initResult.errorMessage}');
        return;
      }
      
      // Generate a unique UID for the viewer
      _localUid = DateTime.now().millisecondsSinceEpoch % 100000;
      
      // Listen for remote user joining (the host)
      agoraSvc.onUserJoined.listen((uid) {
        debugPrint('Viewer: Remote user joined with uid: $uid');
        if (mounted) {
          setState(() => _remoteUid = uid);
          // On web, play the remote video after a short delay
          if (kIsWeb) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _remoteUid != null) {
                final containerId = 'agora-remote-video-${widget.streamId}';
                _agoraService?.playRemoteVideoWeb(_remoteUid!, containerId);
                debugPrint('Viewer: Playing remote video in container: $containerId');
              }
            });
          }
        }
      });
      
      agoraSvc.onUserOffline.listen((uid) {
        if (mounted && _remoteUid == uid) {
          setState(() => _remoteUid = null);
        }
      });
      
      if (mounted) {
        setState(() => _agoraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing Agora viewer: $e');
    }
  }

  Future<void> _joinAgoraChannel() async {
    final agoraSvc = _agoraService;
    final uid = _localUid;
    if (agoraSvc != null && uid != null && _agoraInitialized) {
      // Try to get a token from Cloud Functions
      String? token;
      try {
        final tokenResult = await AgoraTokenService().generateToken(
          channelName: widget.streamId,
          uid: uid,
          isPublisher: false,
        );
        token = tokenResult?.token;
      } catch (e) {
        debugPrint('Token generation failed, continuing without token: $e');
      }
      
      final joinResult = await agoraSvc.joinChannelAsViewer(
        channelName: widget.streamId,
        uid: uid,
        token: token,
      );
      if (!joinResult.success) {
        debugPrint('Failed to join as viewer: ${joinResult.errorMessage}');
      }
    }
  }

  // Removed auto-hide controls - everything always visible
  void _startControlsTimer() {
    // No-op: controls always visible
  }

  void _showControlsTemporarily() {
    // No-op: controls always visible
  }

  Future<void> _loadStream() async {
    try {
      final repo = context.read<LiveStreamRepository>();

      // Join the stream
      await repo.joinLiveStream(widget.streamId);

      // Subscribe to stream updates
      _streamSub = repo.liveStreamStream(widget.streamId).listen((stream) {
        if (!mounted) return;
        
        // Join Agora channel when stream goes live
        if (stream?.isLive == true && _stream?.isLive != true) {
          _joinAgoraChannel();
        }
        
        setState(() {
          _stream = stream;
          _isLoading = false;
        });
      });

      // Subscribe to chat messages
      _chatSub = repo.chatMessagesStream(streamId: widget.streamId).listen((msgs) {
        if (!mounted) return;
        setState(() => _messages = msgs);
        _scrollToBottom();
      });

      // Subscribe to reactions
      _reactionSub = repo.reactionsStream(widget.streamId).listen((reaction) {
        if (!mounted) return;
        _addFloatingReaction(reaction.emoji);
      });
    } catch (e) {
      debugPrint('Error loading stream: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveStream() async {
    try {
      await _agoraService?.leaveChannel();
      final repo = context.read<LiveStreamRepository>();
      await repo.leaveLiveStream(widget.streamId);
    } catch (e) {
      debugPrint('Error leaving stream: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    _chatFocusNode.unfocus();

    try {
      final repo = context.read<LiveStreamRepository>();
      await repo.sendChatMessage(streamId: widget.streamId, message: text);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> _sendReaction(String emoji) async {
    _addFloatingReaction(emoji);
    try {
      final repo = context.read<LiveStreamRepository>();
      await repo.sendReaction(streamId: widget.streamId, emoji: emoji);
    } catch (e) {
      debugPrint('Error sending reaction: $e');
    }
  }

  void _addFloatingReaction(String emoji) {
    final random = Random();
    final reaction = _FloatingReaction(
      emoji: emoji,
      startX: MediaQuery.of(context).size.width - 80 + random.nextDouble() * 40,
      controller: AnimationController(
        duration: const Duration(milliseconds: 2500),
        vsync: this,
      ),
    );

    setState(() => _floatingReactions.add(reaction));
    reaction.controller.forward().then((_) {
      if (mounted) {
        setState(() => _floatingReactions.remove(reaction));
        reaction.controller.dispose();
      }
    });
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_stream == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Ionicons.videocam_off_outline, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                lang.t('livestream.stream_not_found'),
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kIsWeb ? Colors.transparent : Colors.black,
      body: GestureDetector(
        onTap: _showControlsTemporarily,
        child: Stack(
          children: [
            // Video/Stream area
            Positioned.fill(
              child: _buildVideoArea(),
            ),

            // Floating reactions
            ..._floatingReactions.map((r) => _buildFloatingReaction(r)),

            // Top bar - always visible (wrapped for web z-index)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PointerInterceptor(child: _buildTopBar(lang, isDark)),
            ),

            // Bottom controls - always visible
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PointerInterceptor(child: _buildBottomControls(lang, isDark)),
            ),

            // Chat panel (right side on landscape, bottom on portrait)
            if (_isChatVisible && !_isFullscreen)
              Positioned(
                bottom: 100,
                left: 16,
                right: 80,
                height: 250,
                child: PointerInterceptor(child: _buildChatPanel(lang, isDark)),
              ),

            // Reaction buttons
            Positioned(
              right: 16,
              bottom: 180,
              child: PointerInterceptor(child: _buildReactionButtons()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    // Show Agora remote video if available and stream is live
    if (_stream?.isLive == true && _remoteUid != null) {
      // Web platform - use HtmlElementView
      if (kIsWeb && _agoraService?.isWeb == true) {
        final containerId = 'agora-remote-video-${widget.streamId}';
        final remoteId = _remoteUid;
        if (remoteId != null) {
          return AgoraWebVideoView(
            containerId: containerId,
            isLocalVideo: false,
            remoteUid: remoteId,
            onReady: () {
              // Play remote video after view is ready
              _agoraService?.playRemoteVideoWeb(remoteId, containerId);
            },
          );
        }
      }
      
      // Native platform - use AgoraVideoView
      final agoraSvc = _agoraService;
      final eng = agoraSvc?.engine;
      final remoteId = _remoteUid;
      if (eng != null && remoteId != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: eng,
            canvas: VideoCanvas(uid: remoteId),
            connection: RtcConnection(channelId: widget.streamId),
          ),
        );
      }
    }
    
    // Show loading or waiting state
    final streamData = _stream;
    final thumbUrl = streamData?.thumbnailUrl;
    return Container(
      color: Colors.black,
      child: thumbUrl != null && streamData?.isLive != true
          ? CachedNetworkImage(
              imageUrl: thumbUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_stream?.isLive == true && _remoteUid == null) ...[
                    const CircularProgressIndicator(color: Color(0xFFBFAE01)),
                    const SizedBox(height: 16),
                    Text(
                      'Connecting to stream...',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ] else ...[
                    Icon(
                      _stream?.isLive == true
                          ? Ionicons.radio
                          : Ionicons.play_circle_outline,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    if (_stream?.isLive == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTopBar(LanguageProvider lang, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Ionicons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          // Host info
          GestureDetector(
            onTap: () {
              if (_stream?.hostId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'other_user_profile'),
                    builder: (_) => OtherUserProfilePage(
                      userId: _stream!.hostId,
                      userName: _stream!.hostName,
                      userAvatarUrl: _stream!.hostAvatarUrl,
                      userBio: '',
                    ),
                  ),
                );
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: _stream?.hostAvatarUrl.isNotEmpty == true
                      ? CachedNetworkImageProvider(_stream!.hostAvatarUrl)
                      : null,
                  backgroundColor: Colors.grey[700],
                  child: _stream?.hostAvatarUrl.isEmpty == true
                      ? Text(
                          _stream?.hostName.isNotEmpty == true
                              ? _stream!.hostName[0].toUpperCase()
                              : 'H',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _stream?.hostName ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _stream?.title ?? '',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Live badge
          if (_stream?.isLive == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          // Viewer count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Ionicons.eye, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _formatCount(_stream?.viewerCount ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(LanguageProvider lang, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Chat input
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: lang.t('livestream.say_something'),
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Ionicons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Toggle chat
          IconButton(
            icon: Icon(
              _isChatVisible ? Ionicons.chatbubble : Ionicons.chatbubble_outline,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isChatVisible = !_isChatVisible),
          ),
          // Fullscreen
          IconButton(
            icon: Icon(
              _isFullscreen ? Ionicons.contract : Ionicons.expand,
              color: Colors.white,
            ),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(LanguageProvider lang, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return _buildChatMessage(msg);
        },
      ),
    );
  }

  Widget _buildChatMessage(LiveStreamChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: msg.senderAvatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(msg.senderAvatarUrl)
                : null,
            backgroundColor: Colors.grey[700],
            child: msg.senderAvatarUrl.isEmpty
                ? Text(
                    msg.senderName.isNotEmpty
                        ? msg.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      msg.senderName,
                      style: TextStyle(
                        color: msg.isHost
                            ? const Color(0xFFBFAE01)
                            : Colors.grey[300],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (msg.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  msg.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _reactionEmojis.map((emoji) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _sendReaction(emoji),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFloatingReaction(_FloatingReaction reaction) {
    return AnimatedBuilder(
      animation: reaction.controller,
      builder: (context, child) {
        final progress = reaction.controller.value;
        final screenHeight = MediaQuery.of(context).size.height;
        final yOffset = screenHeight * 0.4 * progress;
        final opacity = 1.0 - progress;
        final scale = 1.0 + (progress * 0.5);

        return Positioned(
          right: reaction.startX - (MediaQuery.of(context).size.width - 100),
          bottom: 200 + yOffset,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _FloatingReaction {
  final String emoji;
  final double startX;
  final AnimationController controller;

  _FloatingReaction({
    required this.emoji,
    required this.startX,
    required this.controller,
  });
}
