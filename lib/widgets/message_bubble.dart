import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../image_swipe_page.dart';
import '../core/time_utils.dart';

// Platform helper for safe access
String _platformName() {
  if (kIsWeb) return 'Web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.iOS:
      return 'iOS';
    case TargetPlatform.macOS:
      return 'macOS';
    case TargetPlatform.windows:
      return 'Windows';
    case TargetPlatform.linux:
      return 'Linux';
    default:
      return 'Unknown';
  }
}

bool _isIOSPlatform() {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

bool _isAndroidPlatform() {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool showTimestamp;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final List<Message> allMessages;
  final String? reactionEmoji;

  const MessageBubble({
    super.key,
    required this.message,
    required this.allMessages,
    this.showTimestamp = false,
    this.onReply,
    this.onLongPress,
    this.reactionEmoji,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  static String? _currentlyPlayingMessageId;

  AnimationController? _waveController;

  static const List<double> _waveBase = [
    0.35, 0.75, 0.45, 0.9, 0.6, 0.8, 0.5, 0.7, 0.4, 0.62,
    0.82, 0.48, 0.92, 0.55, 0.7, 0.62, 0.45, 0.78, 0.36, 0.58,
    0.72, 0.42, 0.83, 0.53, 0.68, 0.61, 0.43, 0.79, 0.34, 0.56,
  ];

  // Responsive max bubble width
  // Mobile (<600px): 65% of screen width
  // Desktop/Large (>=1024px): 35% of screen width
  double _bubbleContentWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) {
      // Mobile: 65% of screen width
      return w * 0.65;
    } else if (w >= 1024) {
      // Desktop/Large: 35% of screen width
      return w * 0.35;
    } else {
      // Tablet: 50% of screen width
      return w * 0.50;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_hasVoice()) {
      _initAudioPlayer();
      _waveController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..addListener(() {
          if (_isPlaying && mounted) setState(() {});
        });
    }
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasVoice() && _audioPlayer == null) {
      _initAudioPlayer();
    }
  }

  bool _hasVoice() {
    return widget.message.type == MessageType.voice ||
        widget.message.attachments.any((a) => a.type == MediaType.voice);
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (_isPlaying) {
          _currentlyPlayingMessageId = widget.message.id;
          _waveController?.repeat();
        } else {
          if (_currentlyPlayingMessageId == widget.message.id) {
            _currentlyPlayingMessageId = null;
          }
          _waveController?.stop();
        }
      });
    });
    _audioPlayer!.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
    });
    _audioPlayer!.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _totalDuration = duration);
    });
  }

  @override
  void dispose() {
    _waveController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  List<String> _getAllChatMedia() {
    final List<String> allMedia = [];
    for (final msg in widget.allMessages) {
      if (msg.attachments.isEmpty) continue;
      for (final attachment in msg.attachments) {
        if (attachment.type == MediaType.image) {
          allMedia.add(attachment.url);
        } else if (attachment.type == MediaType.video) {
          if (attachment.thumbnailUrl != null && attachment.thumbnailUrl!.isNotEmpty) {
            allMedia.add(attachment.thumbnailUrl!);
          } else {
            // No thumbnail available; include the video URL so viewer can handle it.
            allMedia.add(attachment.url);
          }
        }
      }
    }
    return allMedia;
  }

  int _getInitialMediaIndex(String currentMediaUrl) {
    final allMedia = _getAllChatMedia();
    return allMedia.indexOf(currentMediaUrl).clamp(0, allMedia.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          left: widget.message.isFromCurrentUser ? 60 : 16,
          right: widget.message.isFromCurrentUser ? 16 : 60,
          bottom: widget.reactionEmoji != null ? 16 : 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: widget.message.isFromCurrentUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildMessageContent(context, isDark),
                  if (widget.reactionEmoji != null)
                    Positioned(
                      bottom: -8,
                      right: widget.message.isFromCurrentUser ? 0 : null,
                      left: widget.message.isFromCurrentUser ? null : 0,
                      child: _buildReactionPill(isDark, widget.reactionEmoji!),
                    ),
                ],
              ),
            ),
            if (widget.showTimestamp) _buildTimestamp(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionPill(bool isDark, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 26),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDark) {
    final attachments = widget.message.attachments;
    final hasMedia = attachments.any(
        (a) => a.type == MediaType.image || a.type == MediaType.video);
    final hasFiles = attachments.any((a) => a.type == MediaType.document);
    final hasVoice = _hasVoice();

    if (hasVoice) return _buildVoiceMessage(context, isDark);
    if (hasMedia) return _buildMixedMediaMessage(context, isDark);
    if (hasFiles) return _buildFilesMessage(context, isDark);

    switch (widget.message.type) {
      case MessageType.text:
        return _buildTextMessage(context, isDark);
      case MessageType.image:
        return _buildImageMessage(context, isDark);
      case MessageType.video:
        return _buildVideoMessage(context, isDark);
      case MessageType.voice:
        return _buildVoiceMessage(context, isDark);
      case MessageType.file:
        return _buildFileMessage(context, isDark);
    }
  }

  Widget _buildTextMessage(BuildContext context, bool isDark) {
    final maxW = _bubbleContentWidth(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.message.isFromCurrentUser
              ? const Color(0xFF007AFF)
              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message.replyTo != null) _buildReplyPreview(isDark),
            Text(
              widget.message.content,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: widget.message.isFromCurrentUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mixed images + videos
  Widget _buildMixedMediaMessage(BuildContext context, bool isDark) {
    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);

    final media = widget.message.attachments
        .where((a) => a.type == MediaType.image || a.type == MediaType.video)
        .toList();

    final maxW = _bubbleContentWidth(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: GestureDetector(
        onTap: () async {
          if (media.isEmpty) return;
          final allChatMedia = _getAllChatMedia();
          final firstUrl = media.first.type == MediaType.video &&
                  media.first.thumbnailUrl != null
              ? media.first.thumbnailUrl!
              : media.first.url;
          final initialIndex = _getInitialMediaIndex(firstUrl);

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageSwipePage(
                mediaUrls: allChatMedia,
                initialIndex: initialIndex,
              ),
            ),
          );

          if (result != null && result['action'] == 'reply' && widget.onReply != null) {
            widget.onReply!();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message.replyTo != null) _buildReplyPreview(isDark),
              if (widget.message.replyTo != null) const SizedBox(height: 4),
              if (media.length == 1)
                _buildMediaTile(
                  media.first,
                  width: maxW,
                  height: 140,
                  radius: 16,
                  isVideo: media.first.type == MediaType.video,
                )
              else if (media.length == 2)
                _buildTwoMedia(media, maxW)
              else if (media.length == 3)
                _buildTripleMosaic(context, media)
              else
                _buildGridMosaic(context, media),
              const SizedBox(height: 4),
              // counts row intentionally hidden
              _buildMediaCountsRow(widget.message.attachments, isDark),
              if (widget.message.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.message.content,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: widget.message.isFromCurrentUser
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTwoMedia(List<MediaAttachment> items, double maxW) {
    const double spacing = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaTile(
          items[0],
          width: maxW,
          height: 140,
          radius: 16,
          isVideo: items[0].type == MediaType.video,
        ),
        const SizedBox(height: spacing),
        _buildMediaTile(
          items[1],
          width: maxW,
          height: 140,
          radius: 16,
          isVideo: items[1].type == MediaType.video,
        ),
      ],
    );
  }

    Widget _buildImageMessage(BuildContext context, bool isDark) {
    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final maxW = _bubbleContentWidth(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: GestureDetector(
        onTap: () async {
          final allChatMedia = _getAllChatMedia();
          final initialIndex = _getInitialMediaIndex(
            widget.message.attachments.first.url,
          );

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageSwipePage(
                mediaUrls: allChatMedia,
                initialIndex: initialIndex,
              ),
            ),
          );

          if (result != null && result['action'] == 'reply' && widget.onReply != null) {
            widget.onReply!();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message.replyTo != null) _buildReplyPreview(isDark),
              if (widget.message.replyTo != null) const SizedBox(height: 4),
              if (widget.message.attachments.length == 1)
                _buildSingleImage(widget.message.attachments.first, maxW)
              else if (widget.message.attachments.length == 2)
                _buildTwoImages(maxW)
              else if (widget.message.attachments.length == 3)
                _buildTripleMosaic(context, widget.message.attachments)
              else
                _buildGridMosaic(context, widget.message.attachments),
              const SizedBox(height: 4),
              // counts row intentionally hidden
              _buildMediaCountsRow(widget.message.attachments, isDark),
              if (widget.message.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.message.content,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: widget.message.isFromCurrentUser
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, bool isDark) {
    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final maxW = _bubbleContentWidth(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message.replyTo != null) _buildReplyPreview(isDark),
            if (widget.message.replyTo != null) const SizedBox(height: 4),
            if (widget.message.attachments.length == 1)
              _buildMediaTile(
                widget.message.attachments.first,
                width: maxW,
                height: 140,
                radius: 16,
                isVideo: true,
              )
            else if (widget.message.attachments.length == 2)
              _buildTwoImages(maxW)
            else if (widget.message.attachments.length == 3)
              _buildTripleMosaic(context, widget.message.attachments)
            else
              _buildVideosGridMosaic(context, widget.message.attachments),
            const SizedBox(height: 4),
            // counts row intentionally hidden
            _buildMediaCountsRow(widget.message.attachments, isDark),
            if (widget.message.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.message.content,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: widget.message.isFromCurrentUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilesMessage(BuildContext context, bool isDark) {
    final files = widget.message.attachments
        .where((a) => a.type == MediaType.document)
        .toList();
    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final maxW = _bubbleContentWidth(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message.replyTo != null) _buildReplyPreview(isDark),
            if (widget.message.replyTo != null) const SizedBox(height: 6),
            for (final f in files) ...[
              _buildSingleFileRow(f, isDark),
              if (f != files.last) const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            // counts row intentionally hidden
            _buildMediaCountsRow(widget.message.attachments, isDark),
            if (widget.message.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.message.content,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: widget.message.isFromCurrentUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleFileRow(MediaAttachment attachment, bool isDark) {
    IconData pickIcon(String? name) {
      final n = (name ?? '').toLowerCase();
      if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
      if (n.endsWith('.xls') || n.endsWith('.xlsx')) return Icons.grid_on;
      return Icons.description; // Word/doc: generic document icon
    }

    Color pickBadgeColor(String? name) {
      final n = (name ?? '').toLowerCase();
      if (n.endsWith('.pdf')) return const Color(0xFFE53935); // red
      if (n.endsWith('.xls') || n.endsWith('.xlsx')) return const Color(0xFF2E7D32); // green
      return widget.message.isFromCurrentUser
          ? Colors.white.withValues(alpha: 51)
          : const Color(0xFF007AFF).withValues(alpha: 51);
    }

    Future<void> openExternal(String url) async {
      if (url.isEmpty) return;
      try {
        final uri = Uri.parse(url);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open file')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open file')),
          );
        }
      }
    }

    final bubbleTextColor = widget.message.isFromCurrentUser
        ? Colors.white
        : (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openExternal(attachment.url),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pickBadgeColor(attachment.fileName),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              pickIcon(attachment.fileName),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName ?? 'Document',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: bubbleTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attachment.fileSize != null)
                  Text(
                    _formatFileSize(attachment.fileSize!),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.message.isFromCurrentUser
                          ? Colors.white70
                          : const Color(0xFF666666),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

    MediaAttachment? _getVoiceAttachment() {
    if (widget.message.attachments.isNotEmpty) {
      final voice = widget.message.attachments.firstWhere(
        (a) => a.type == MediaType.voice,
        orElse: () => widget.message.attachments.first,
      );
      return voice.type == MediaType.voice ? voice : null;
    }

    if (widget.message.type == MessageType.voice &&
        widget.message.content.isNotEmpty) {
      final uri = Uri.tryParse(widget.message.content);
      if (uri != null && uri.hasScheme && uri.hasAuthority) {
        return MediaAttachment(
          id: 'temp-${widget.message.id}',
          url: widget.message.content,
          type: MediaType.voice,
          duration: null,
          fileSize: null,
          fileName: 'voice_message.m4a',
        );
      }
    }
    return null;
  }

  Widget _buildVoiceMessage(BuildContext context, bool isDark) {
    final att = _getVoiceAttachment();
    final maxW = _bubbleContentWidth(context);

    if (att == null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.message.isFromCurrentUser
                ? const Color(0xFF007AFF)
                : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_off,
                color: widget.message.isFromCurrentUser
                    ? Colors.white
                    : const Color(0xFF007AFF),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice message unavailable',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: widget.message.isFromCurrentUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final subTextColor = widget.message.isFromCurrentUser
        ? Colors.white.withValues(alpha: 204)
        : Colors.grey[600]!;
    final inactive = widget.message.isFromCurrentUser
        ? Colors.white.withValues(alpha: 77)
        : Colors.grey.withValues(alpha: 77);
    final active = widget.message.isFromCurrentUser
        ? Colors.white
        : const Color(0xFF007AFF);

    final effectiveTotal = _totalDuration.inMilliseconds > 0
        ? _totalDuration
        : (att.duration ?? Duration.zero);
    final effectiveCurrent = _currentPosition.inMilliseconds > 0
        ? _currentPosition
        : Duration.zero;
    final progress = (effectiveTotal.inMilliseconds > 0)
        ? (effectiveCurrent.inMilliseconds / effectiveTotal.inMilliseconds)
        : 0.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message.replyTo != null) _buildReplyPreview(isDark),
            if (widget.message.replyTo != null) const SizedBox(height: 6),
                        Row(
              children: [
                IconButton(
                  onPressed: _togglePlayback,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  color: widget.message.isFromCurrentUser
                      ? Colors.white
                      : const Color(0xFF007AFF),
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final waveWidth = constraints.maxWidth;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          if (effectiveTotal.inMilliseconds <= 0 ||
                              _audioPlayer == null) {
                            return;
                          }
                          final dx =
                              details.localPosition.dx.clamp(0.0, waveWidth);
                          final ratio = waveWidth <= 0 ? 0.0 : dx / waveWidth;
                          final target = Duration(
                            milliseconds:
                                (effectiveTotal.inMilliseconds * ratio)
                                    .clamp(0, effectiveTotal.inMilliseconds)
                                    .toInt(),
                          );
                          _audioPlayer!.seek(target);
                        },
                        child: SizedBox(
                          height: 18,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: VoiceWavePainter(
                              inactiveColor: inactive,
                              activeColor: active,
                              progress: progress,
                              animation: (_waveController?.value ?? 0.0),
                              bars: _waveBase,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  _formatDuration(
                    effectiveTotal.inMilliseconds > 0
                        ? effectiveTotal
                        : (att.duration ?? Duration.zero),
                  ),
                  style: GoogleFonts.inter(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (_audioPlayer == null) return;

    final attachment = _getVoiceAttachment();
    if (attachment == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        if (_currentlyPlayingMessageId != null &&
            _currentlyPlayingMessageId != widget.message.id) {
          // could broadcast a pause to other bubbles if we had a controller
        }
        
        // Check if URL is valid
        final url = attachment.url;
        if (url.isEmpty) {
          throw Exception('Audio URL is empty');
        }
        
        // Validate URL format
        final uri = Uri.tryParse(url);
        if (uri == null) {
          throw Exception('Invalid audio URL format');
        }
        
        // Check if it's a Firebase Storage URL
        final isFirebaseUrl = url.contains('firebasestorage.googleapis.com') || 
                              url.contains('firebase.storage');
        
        // Detect audio format from URL
        final isWebM = url.toLowerCase().contains('.webm');
        final isM4A = url.toLowerCase().contains('.m4a');
        
        debugPrint('🎵 Attempting to play audio:');
        debugPrint('   URL: ${url.length > 100 ? '${url.substring(0, 100)}...' : url}');
        debugPrint('   Format: ${isWebM ? "WebM" : isM4A ? "M4A" : "Unknown"}');
        debugPrint('   Firebase URL: $isFirebaseUrl');
        debugPrint('   Platform: ${_platformName()}');
        
        // Check platform compatibility
        if (isWebM && (_isIOSPlatform() || _isAndroidPlatform())) {
          debugPrint('⚠️ WebM audio format may not be supported on this platform');
          // Try to play anyway, but warn user if it fails
        }
        
        // Attempt to play with better error context
        try {
          await _audioPlayer!.play(UrlSource(url));
        } catch (playError) {
          debugPrint('❌ Audio playback failed:');
          debugPrint('   Error: $playError');
          debugPrint('   URL: $url');
          
          // Provide more specific error message
          String errorMessage = 'Unable to play audio';
          if (playError.toString().contains('403') || 
              playError.toString().contains('401')) {
            errorMessage = 'Audio file access denied. Please try again later.';
          } else if (playError.toString().contains('404')) {
            errorMessage = 'Audio file not found.';
          } else if (isWebM && (_isIOSPlatform() || _isAndroidPlatform())) {
            errorMessage = 'This audio format may not be supported on your device.';
          } else if (playError.toString().contains('source') || 
                     playError.toString().contains('null')) {
            errorMessage = 'Invalid audio source. The file may be corrupted.';
          }
          
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      if (!mounted) return;
      
      // Show user-friendly error message
      String displayMessage = e.toString();
      if (e is Exception) {
        displayMessage = e.toString().replaceAll('Exception: ', '');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Widget _buildFileMessage(BuildContext context, bool isDark) {
    final attachment = widget.message.attachments.first;
    final maxW = _bubbleContentWidth(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.message.isFromCurrentUser
              ? const Color(0xFF007AFF)
              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message.replyTo != null) _buildReplyPreview(isDark),
            if (widget.message.replyTo != null) const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.message.isFromCurrentUser
                        ? Colors.white.withValues(alpha: 51)
                        : const Color(0xFF007AFF).withValues(alpha: 51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName ?? 'Document',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.message.isFromCurrentUser
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (attachment.fileSize != null)
                        Text(
                          _formatFileSize(attachment.fileSize!),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: widget.message.isFromCurrentUser
                                ? Colors.white70
                                : const Color(0xFF666666),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    if (widget.message.replyTo == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFB0B0B0), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.isFromCurrentUser ? 'You' : widget.message.senderName,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyTo!.content,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleImage(MediaAttachment attachment, double maxW) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: attachment.url,
        width: maxW,
        height: 140,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: maxW,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF666666).withValues(alpha: 51),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: maxW,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF666666).withValues(alpha: 51),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.broken_image,
            color: Color(0xFF666666),
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(double maxW) {
    const double spacing = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaTile(
          widget.message.attachments[0],
          width: maxW,
          height: 140,
          radius: 16,
          isVideo: widget.message.attachments[0].type == MediaType.video,
        ),
        const SizedBox(height: spacing),
        _buildMediaTile(
          widget.message.attachments[1],
          width: maxW,
          height: 140,
          radius: 16,
          isVideo: widget.message.attachments[1].type == MediaType.video,
        ),
      ],
    );
  }

  Widget _buildMediaTile(
    MediaAttachment attachment, {
    required double width,
    required double height,
    double radius = 12,
    bool isVideo = false,
    String? overlayText,
  }) {
    final hasThumb = (attachment.thumbnailUrl != null && attachment.thumbnailUrl!.isNotEmpty);
    final displayUrl = attachment.thumbnailUrl ?? attachment.url;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: isVideo && !hasThumb
              ? Container(
                  width: width,
                  height: height,
                  color: const Color(0xFF000000).withValues(alpha: 26),
                  child: const Center(
                    child: Icon(Icons.videocam_outlined, color: Colors.white70, size: 40),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: displayUrl,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: const Color(0xFF666666).withValues(alpha: 51),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000).withValues(alpha: 26),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: Center(
                      child: Icon(
                        isVideo ? Icons.videocam_off_outlined : Icons.broken_image,
                        color: const Color(0xFF666666),
                        size: 40,
                      ),
                    ),
                  ),
                ),
        ),
        if (isVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 51),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
              ),
            ),
          ),
        if (overlayText != null) ...[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 128),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: Text(
                  overlayText,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGridMosaic(BuildContext context, List<MediaAttachment> attachments) {
    final double contentWidth = _bubbleContentWidth(context);
    const double spacing = 4;
    const double tileHeight = 140;
    final double tileWidth = (contentWidth - spacing) / 2;

    final int total = attachments.length;
    final int displayCount = total > 4 ? 4 : total;
    final int rows = (displayCount / 2).ceil();
    final double mosaicHeight = rows * tileHeight + (rows - 1) * spacing;

    return SizedBox(
      width: contentWidth,
      height: mosaicHeight,
      child: Column(
        children: [
          for (int row = 0; row < rows; row++) ...[
            Row(
              children: [
                for (int col = 0; col < 2; col++) ...[
                  if (row * 2 + col < displayCount)
                    _buildMediaTile(
                      attachments[row * 2 + col],
                      width: tileWidth,
                      height: tileHeight,
                      radius: 16,
                      isVideo:
                          attachments[row * 2 + col].type == MediaType.video,
                      overlayText: (row * 2 + col == displayCount - 1 &&
                              total > displayCount)
                          ? '+${total - displayCount}'
                          : null,
                    ),
                  if (col == 0) const SizedBox(width: spacing),
                ],
              ],
            ),
            if (row < rows - 1) const SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }

  Widget _buildVideosGridMosaic(BuildContext context, List<MediaAttachment> attachments) {
    final double contentWidth = _bubbleContentWidth(context);
    const double spacing = 4;
    const double tileHeight = 140;
    final double tileWidth = (contentWidth - spacing) / 2;

    final int total = attachments.length;
    final int displayCount = total > 4 ? 4 : total;
    final int rows = (displayCount / 2).ceil();
    final double mosaicHeight = rows * tileHeight + (rows - 1) * spacing;

    return SizedBox(
      width: contentWidth,
      height: mosaicHeight,
      child: Column(
        children: [
          for (int row = 0; row < rows; row++) ...[
            Row(
              children: [
                for (int col = 0; col < 2; col++) ...[
                  if (row * 2 + col < displayCount)
                    _buildMediaTile(
                      attachments[row * 2 + col],
                      width: tileWidth,
                      height: tileHeight,
                      radius: 16,
                      isVideo: true,
                      overlayText: (row * 2 + col == displayCount - 1 &&
                              total > displayCount)
                          ? '+${total - displayCount}'
                          : null,
                    ),
                  if (col == 0) const SizedBox(width: spacing),
                ],
              ],
            ),
            if (row < rows - 1) const SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }

  Widget _buildTripleMosaic(BuildContext context, List<MediaAttachment> attachments) {
    final double contentWidth = _bubbleContentWidth(context);
    const double mosaicHeight = 140;
    const double spacing = 4;
    final double leftWidth = ((contentWidth - spacing) * 2 / 3).floorToDouble();
    final double rightWidth = contentWidth - spacing - leftWidth;
    final double smallHeight = (mosaicHeight - spacing) / 2;

    return SizedBox(
      width: contentWidth,
      height: mosaicHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaTile(
            attachments[0],
            width: leftWidth,
            height: mosaicHeight,
            radius: 16,
            isVideo: attachments[0].type == MediaType.video,
          ),
          const SizedBox(width: spacing),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMediaTile(
                attachments[1],
                width: rightWidth,
                height: smallHeight,
                radius: 16,
                isVideo: attachments[1].type == MediaType.video,
              ),
              const SizedBox(height: spacing),
              _buildMediaTile(
                attachments[2],
                width: rightWidth,
                height: smallHeight,
                radius: 16,
                isVideo: attachments[2].type == MediaType.video,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(bool isDark) {
    final align = widget.message.isFromCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: align,
        child: Text(
          TimeUtils.relativeLabel(widget.message.timestamp, locale: 'en_short'),
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
        ),
      ),
    );
  }

  // Hide media/file counts row entirely
  Widget _buildMediaCountsRow(List<MediaAttachment> attachments, bool isDark) {
    return const SizedBox.shrink();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }
}

class VoiceWavePainter extends CustomPainter {
  final Color inactiveColor;
  final Color activeColor;
  final double progress; // 0..1
  final double animation; // 0..1
  final List<double> bars;

  VoiceWavePainter({
    required this.inactiveColor,
    required this.activeColor,
    required this.progress,
    required this.animation,
    required this.bars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalBars = bars.length;
    if (totalBars == 0) return;

    final spacing = 3.0;
    final barWidth = 2.0;
    final totalWidth = totalBars * barWidth + (totalBars - 1) * spacing;
    final startX = (size.width - totalWidth) / 2;
    final centerY = size.height / 2;

    final cutoffX = size.width * progress;

    for (int i = 0; i < totalBars; i++) {
      final x = startX + i * (barWidth + spacing);
      final base = bars[i];
      final wobble = 0.1 * math.sin((animation * 2 * math.pi) + i * 0.5);
      final heightFactor = (base + wobble).clamp(0.15, 1.0);
      final barHeight = heightFactor * size.height;

      final y1 = centerY - barHeight / 2;
      final y2 = centerY + barHeight / 2;

      final isActive = x <= cutoffX;
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant VoiceWavePainter old) {
    return old.progress != progress ||
        old.animation != animation ||
        old.activeColor != activeColor ||
        old.inactiveColor != inactiveColor ||
        old.bars != bars;
  }
}