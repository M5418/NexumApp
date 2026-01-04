import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/interfaces/livestream_repository.dart';
import '../repositories/models/livestream_model.dart';
import '../services/agora_service.dart';
import '../services/agora_token_service.dart';
import '../widgets/agora_debug_panel.dart';
import '../widgets/agora_web_video.dart';

class LiveStreamHostPage extends StatefulWidget {
  final String streamId;

  const LiveStreamHostPage({super.key, required this.streamId});

  @override
  State<LiveStreamHostPage> createState() => _LiveStreamHostPageState();
}

class _LiveStreamHostPageState extends State<LiveStreamHostPage>
    with TickerProviderStateMixin {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  LiveStreamModel? _stream;
  List<LiveStreamChatMessage> _messages = [];
  List<LiveStreamViewer> _viewers = [];
  bool _isLoading = true;
  bool _isLive = false;
  bool _isChatVisible = true;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _showViewers = false;
  bool _showDebugPanel = false;

  AgoraService? _agoraService;
  bool _agoraInitialized = false;
  int? _localUid;
  StreamSubscription<AgoraDiagnostics>? _diagnosticsSub;
  AgoraDiagnostics _currentDiagnostics = const AgoraDiagnostics();

  StreamSubscription<LiveStreamModel?>? _streamSub;
  StreamSubscription<List<LiveStreamChatMessage>>? _chatSub;
  StreamSubscription<LiveStreamReaction>? _reactionSub;

  final List<_FloatingReaction> _floatingReactions = [];
  Timer? _controlsTimer;
  Timer? _durationTimer;
  Duration _liveDuration = Duration.zero;


  @override
  void initState() {
    super.initState();
    _initAgora();
    _loadStream();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _agoraService?.dispose();
    _streamSub?.cancel();
    _chatSub?.cancel();
    _reactionSub?.cancel();
    _diagnosticsSub?.cancel();
    _controlsTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      _agoraService = AgoraService();
      
      final agoraSvc = _agoraService;
      if (agoraSvc == null) {
        debugPrint('Failed to create AgoraService');
        if (mounted) setState(() => _agoraInitialized = true);
        return;
      }
      
      // Subscribe to diagnostics updates (for debug panel)
      _diagnosticsSub = agoraSvc.onDiagnosticsChanged.listen((diag) {
        if (mounted) {
          setState(() => _currentDiagnostics = diag);
        }
      });
      
      // Request permissions
      final permResult = await agoraSvc.requestPermissions();
      if (!permResult.granted) {
        debugPrint('Permissions not granted - camera: ${permResult.cameraState}, mic: ${permResult.microphoneState}');
        if (mounted) {
          setState(() {
            _agoraInitialized = true;
            _currentDiagnostics = agoraSvc.diagnostics;
          });
        }
        return;
      }
      
      // Initialize as broadcaster
      final initResult = await agoraSvc.initialize(isBroadcaster: true);
      if (!initResult.success) {
        debugPrint('Agora init failed: ${initResult.errorMessage}');
        if (mounted) {
          setState(() {
            _agoraInitialized = true;
            _currentDiagnostics = agoraSvc.diagnostics;
          });
        }
        return;
      }
      
      // Generate a unique UID for the host based on streamId
      _localUid = widget.streamId.hashCode.abs() % 100000;
      
      if (mounted) {
        setState(() {
          _agoraInitialized = true;
          _currentDiagnostics = agoraSvc.diagnostics;
        });
      }
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      // Still mark as initialized to show UI, but without video preview
      // This handles web platform where Agora has limited support
      if (mounted) {
        setState(() => _agoraInitialized = true);
      }
    }
  }

  Future<void> _switchCamera() async {
    await _agoraService?.switchCamera();
  }

  Future<void> _loadStream() async {
    try {
      final repo = context.read<LiveStreamRepository>();

      // Subscribe to stream updates
      _streamSub = repo.liveStreamStream(widget.streamId).listen((stream) {
        if (!mounted) return;
        final wasLive = _isLive;
        final nowLive = stream?.isLive ?? false;
        setState(() {
          _stream = stream;
          _isLoading = false;
          _isLive = nowLive;
        });
        
        // Start timer when stream becomes live (or is already live on load)
        if (nowLive && !wasLive && _durationTimer == null) {
          _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) {
              setState(() => _liveDuration += const Duration(seconds: 1));
            }
          });
        }
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

      // Load viewers
      _loadViewers();
    } catch (e) {
      debugPrint('Error loading stream: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadViewers() async {
    try {
      final repo = context.read<LiveStreamRepository>();
      final viewers = await repo.getViewers(streamId: widget.streamId);
      if (mounted) setState(() => _viewers = viewers);
    } catch (e) {
      debugPrint('Error loading viewers: $e');
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

  Future<void> _startStream() async {
    try {
      // Join Agora channel as broadcaster
      final agoraSvc = _agoraService;
      final uid = _localUid;
      if (agoraSvc != null && uid != null) {
        // Try to get a token from Cloud Functions
        String? token;
        try {
          debugPrint('Agora: Requesting token for channel: ${widget.streamId}, uid: $uid');
          final tokenResult = await AgoraTokenService().generateToken(
            channelName: widget.streamId,
            uid: uid,
            isPublisher: true,
          );
          token = tokenResult?.token;
          debugPrint('Agora: Token received: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
        } catch (e) {
          debugPrint('Agora: Token generation failed: $e');
        }
        
        final joinResult = await agoraSvc.joinChannel(
          channelName: widget.streamId,
          uid: uid,
          token: token,
        );
        if (!joinResult.success) {
          debugPrint('Failed to join channel: ${joinResult.errorMessage}');
        }
      }
      
      if (!mounted) return;
      final repo = context.read<LiveStreamRepository>();
      await repo.startLiveStream(widget.streamId);
      
      if (!mounted) return;
      
      // Start timer immediately - don't wait for callback on web
      if (!_isLive) {
        setState(() => _isLive = true);
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _liveDuration += const Duration(seconds: 1));
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting stream: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LanguageProvider>().t('livestream.error_starting')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _endStream() async {
    final lang = context.read<LanguageProvider>();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('livestream.end_stream_title')),
        content: Text(lang.t('livestream.end_stream_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.t('livestream.end')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = context.read<LiveStreamRepository>();
      await repo.endLiveStream(widget.streamId);
      
      _durationTimer?.cancel();
      
      // Leave Agora channel
      await _agoraService?.leaveChannel();
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error ending stream: $e');
    }
  }

  Future<void> _toggleMic() async {
    setState(() => _isMicMuted = !_isMicMuted);
    await _agoraService?.muteLocalAudio(_isMicMuted);
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    await _agoraService?.muteLocalVideo(_isCameraOff);
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    try {
      final repo = context.read<LiveStreamRepository>();
      await repo.sendChatMessage(streamId: widget.streamId, message: text);
    } catch (e) {
      debugPrint('Error sending message: $e');
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

  Future<void> _kickViewer(LiveStreamViewer viewer) async {
    final lang = context.read<LanguageProvider>();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('livestream.kick_viewer')),
        content: Text(lang.t('livestream.kick_confirm').replaceAll('{name}', viewer.userName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(lang.t('livestream.kick')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = context.read<LiveStreamRepository>();
      await repo.kickViewer(streamId: widget.streamId, viewerId: viewer.userId);
      if (!mounted) return;
      _loadViewers();
    } catch (e) {
      debugPrint('Error kicking viewer: $e');
    }
  }

  Future<void> _banViewer(LiveStreamViewer viewer) async {
    final lang = context.read<LanguageProvider>();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('livestream.ban_viewer')),
        content: Text(lang.t('livestream.ban_confirm').replaceAll('{name}', viewer.userName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.t('livestream.ban')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = context.read<LiveStreamRepository>();
      await repo.banViewer(streamId: widget.streamId, viewerId: viewer.userId);
      if (!mounted) return;
      _loadViewers();
    } catch (e) {
      debugPrint('Error banning viewer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: _buildCameraPreview(),
          ),

          // Floating reactions
          ..._floatingReactions.map((r) => _buildFloatingReaction(r)),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(lang),
          ),

          // Chat panel
          if (_isChatVisible)
            Positioned(
              bottom: 100,
              left: 16,
              right: 80,
              height: 200,
              child: _buildChatPanel(lang),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(lang),
          ),

          // Viewers panel
          if (_showViewers)
            Positioned.fill(
              child: _buildViewersPanel(lang),
            ),

          // Debug panel (only in debug builds)
          if (kDebugMode && _showDebugPanel)
            Positioned.fill(
              child: AgoraDebugPanel(
                diagnostics: _currentDiagnostics,
                onClose: () => setState(() => _showDebugPanel = false),
              ),
            ),

          // Debug button (only in debug builds)
          if (kDebugMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showDebugPanel = !_showDebugPanel),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bug_report,
                    color: Color(0xFFBFAE01),
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    // Loading state
    if (!_agoraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
        ),
      );
    }

    // Camera off state
    if (_isCameraOff) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Ionicons.videocam_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                context.read<LanguageProvider>().t('livestream.camera_off'),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Web platform - use HtmlElementView for video
    if (kIsWeb && _agoraService?.isWeb == true) {
      final containerId = 'agora-local-video-${widget.streamId}';
      return AgoraWebVideoView(
        containerId: containerId,
        isLocalVideo: true,
        onReady: () {
          // Play local video after view is ready
          _agoraService?.playLocalVideoWeb(containerId);
        },
      );
    }

    // Native platform - use AgoraVideoView
    final agoraSvc = _agoraService;
    final eng = agoraSvc?.engine;
    if (eng != null) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: eng,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    // Fallback when engine not available
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ionicons.videocam, size: 64, color: Color(0xFFBFAE01)),
            const SizedBox(height: 16),
            Text(
              context.read<LanguageProvider>().t('livestream.ready_to_stream'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(LanguageProvider lang) {
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
          // Close button
          IconButton(
            icon: const Icon(Ionicons.close, color: Colors.white),
            onPressed: () {
              if (_isLive) {
                _endStream();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const Spacer(),
          // Live indicator & duration
          if (_isLive) ...[
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
                    width: 8,
                    height: 8,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(_liveDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Viewer count
          GestureDetector(
            onTap: () => setState(() => _showViewers = true),
            child: Container(
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
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(LanguageProvider lang) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat input
          if (_isLive)
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
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
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mic toggle
              _buildControlButton(
                icon: _isMicMuted ? Ionicons.mic_off : Ionicons.mic,
                label: _isMicMuted ? lang.t('livestream.unmute') : lang.t('livestream.mute'),
                isActive: !_isMicMuted,
                onTap: _toggleMic,
              ),
              // Camera toggle
              _buildControlButton(
                icon: _isCameraOff ? Ionicons.videocam_off : Ionicons.videocam,
                label: _isCameraOff ? lang.t('livestream.camera_on') : lang.t('livestream.camera_off_btn'),
                isActive: !_isCameraOff,
                onTap: _toggleCamera,
              ),
              // Switch camera
              _buildControlButton(
                icon: Ionicons.camera_reverse,
                label: lang.t('livestream.flip'),
                onTap: _switchCamera,
              ),
              // Chat toggle
              _buildControlButton(
                icon: _isChatVisible ? Ionicons.chatbubble : Ionicons.chatbubble_outline,
                label: lang.t('livestream.chat'),
                isActive: _isChatVisible,
                onTap: () => setState(() => _isChatVisible = !_isChatVisible),
              ),
              // Go Live / End button
              if (!_isLive)
                _buildGoLiveButton(lang)
              else
                _buildEndButton(lang),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.2)
                  : Colors.red.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoLiveButton(LanguageProvider lang) {
    return GestureDetector(
      onTap: _startStream,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Ionicons.radio, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              lang.t('livestream.go_live'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndButton(LanguageProvider lang) {
    return GestureDetector(
      onTap: _endStream,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          lang.t('livestream.end'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildChatPanel(LanguageProvider lang) {
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewersPanel(LanguageProvider lang) {
    return GestureDetector(
      onTap: () => setState(() => _showViewers = false),
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping panel
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            lang.t('livestream.viewers'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBFAE01),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_viewers.length}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Ionicons.close, color: Colors.white),
                            onPressed: () => setState(() => _showViewers = false),
                          ),
                        ],
                      ),
                    ),
                    // Viewers list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _viewers.length,
                        itemBuilder: (context, index) {
                          final viewer = _viewers[index];
                          return _buildViewerTile(viewer, lang);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildViewerTile(LiveStreamViewer viewer, LanguageProvider lang) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: viewer.userAvatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(viewer.userAvatarUrl)
            : null,
        backgroundColor: Colors.grey[700],
        child: viewer.userAvatarUrl.isEmpty
            ? Text(
                viewer.userName.isNotEmpty
                    ? viewer.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(
        viewer.userName,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatJoinTime(viewer.joinedAt, lang),
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Ionicons.ellipsis_vertical, color: Colors.grey[400]),
        color: const Color(0xFF2A2A2A),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'kick',
            child: Row(
              children: [
                const Icon(Ionicons.exit_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Text(
                  lang.t('livestream.kick'),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'ban',
            child: Row(
              children: [
                const Icon(Ionicons.ban, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Text(
                  lang.t('livestream.ban'),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'kick') {
            _kickViewer(viewer);
          } else if (value == 'ban') {
            _banViewer(viewer);
          }
        },
      ),
    );
  }

  Widget _buildFloatingReaction(_FloatingReaction reaction) {
    return AnimatedBuilder(
      animation: reaction.controller,
      builder: (context, child) {
        final progress = reaction.controller.value;
        final screenHeight = MediaQuery.of(context).size.height;
        final yOffset = screenHeight * 0.3 * progress;
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatJoinTime(DateTime joinedAt, LanguageProvider lang) {
    final diff = DateTime.now().difference(joinedAt);
    if (diff.inMinutes < 1) {
      return lang.t('livestream.just_joined');
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${lang.t('livestream.min_ago')}';
    } else {
      return '${diff.inHours} ${lang.t('livestream.hours_ago')}';
    }
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
