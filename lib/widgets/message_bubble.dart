import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/message.dart';
import '../image_swipe_page.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool showTimestamp;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final List<Message> allMessages;

  const MessageBubble({
    super.key,
    required this.message,
    required this.allMessages,
    this.showTimestamp = false,
    this.onReply,
    this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  static String? _currentlyPlayingMessageId;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.voice) {
      _initAudioPlayer();
    }
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.playing) {
            _currentlyPlayingMessageId = widget.message.id;
          } else if (state == PlayerState.stopped ||
              state == PlayerState.completed) {
            if (_currentlyPlayingMessageId == widget.message.id) {
              _currentlyPlayingMessageId = null;
            }
          }
        });
      }
    });
    _audioPlayer!.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    _audioPlayer!.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  List<String> _getAllChatMedia() {
    final List<String> allMedia = [];

    for (final msg in widget.allMessages) {
      if (msg.type == MessageType.image || msg.type == MessageType.video) {
        for (final attachment in msg.attachments) {
          if (attachment.type == MediaType.image) {
            allMedia.add(attachment.url);
          } else if (attachment.type == MediaType.video &&
              attachment.thumbnailUrl != null) {
            allMedia.add(attachment.thumbnailUrl!);
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
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMessageContent(context, isDark),
            if (widget.showTimestamp) _buildTimestamp(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDark) {
    switch (widget.message.type) {
      case MessageType.text:
        return _buildTextMessage(isDark);
      case MessageType.image:
        return _buildImageMessage(context, isDark);
      case MessageType.video:
        return _buildVideoMessage(isDark);
      case MessageType.voice:
        return _buildVoiceMessage(isDark);
      case MessageType.file:
        return _buildFileMessage(isDark);
    }
  }

  Widget _buildTextMessage(bool isDark) {
    return Container(
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
    );
  }

  Widget _buildImageMessage(BuildContext context, bool isDark) {
    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);

    return GestureDetector(
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

        // Handle reply action from ImageSwipePage
        if (result != null &&
            result['action'] == 'reply' &&
            widget.onReply != null) {
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
              _buildSingleImage(widget.message.attachments.first)
            else if (widget.message.attachments.length == 2)
              _buildTwoImages()
            else if (widget.message.attachments.length == 3)
              _buildTripleMosaic(widget.message.attachments)
            else
              _buildGridMosaic(widget.message.attachments),

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

  Widget _buildVideoMessage(bool isDark) {
    final bubbleColor = widget.message.isFromCurrentUser
        ? const Color(0xFF007AFF)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);

    return Container(
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
              width: 270,
              height: 140,
              radius: 16,
              isVideo: true,
            )
          else if (widget.message.attachments.length == 2)
            _buildTwoImages()
          else if (widget.message.attachments.length == 3)
            _buildTripleMosaic(widget.message.attachments)
          else
            _buildVideosGridMosaic(widget.message.attachments),

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
    );
  }

  Widget _buildVoiceMessage(bool isDark) {
    final attachment = widget.message.attachments.isNotEmpty
        ? widget.message.attachments.first
        : null;

    if (attachment == null) return const SizedBox.shrink();

    final duration = attachment.duration ?? _totalDuration;
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.message.isFromCurrentUser
                        ? Colors.white.withValues(alpha: 51)
                        : const Color(0xFF007AFF).withValues(alpha: 26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: widget.message.isFromCurrentUser
                        ? Colors.white
                        : const Color(0xFF007AFF),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        color:
                            (widget.message.isFromCurrentUser
                                    ? Colors.white
                                    : Colors.grey)
                                .withValues(alpha: 77),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.message.isFromCurrentUser
                              ? Colors.white
                              : const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(
                        _totalDuration.inMilliseconds > 0
                            ? _totalDuration
                            : duration,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.message.isFromCurrentUser
                            ? Colors.white.withValues(alpha: 204)
                            : Colors.grey[600],
                      ),
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

  Future<void> _togglePlayback() async {
    if (_audioPlayer == null) return;

    final attachment = widget.message.attachments.isNotEmpty
        ? widget.message.attachments.first
        : null;

    if (attachment == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        // Stop any other currently playing voice message
        if (_currentlyPlayingMessageId != null &&
            _currentlyPlayingMessageId != widget.message.id) {
          // This would ideally stop other players, but for now we'll just play this one
        }
        await _audioPlayer!.play(UrlSource(attachment.url));
      }
    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to play audio: $e')));
    }
  }

  Widget _buildFileMessage(bool isDark) {
    final attachment = widget.message.attachments.first;

    return Container(
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
                child: Icon(
                  Icons.description,
                  color: widget.message.isFromCurrentUser
                      ? Colors.white
                      : const Color(0xFF007AFF),
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
            widget.message.isFromCurrentUser
                ? 'You'
                : widget.message.senderName,
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

  Widget _buildSingleImage(MediaAttachment attachment) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: attachment.url,
        width: 270,
        height: 140,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 270,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF666666).withValues(alpha: 51),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: 270,
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

  Widget _buildTwoImages() {
    const double spacing = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaTile(
          widget.message.attachments[0],
          width: 270,
          height: 140,
          radius: 16,
          isVideo: widget.message.attachments[0].type == MediaType.video,
        ),
        const SizedBox(height: spacing),
        _buildMediaTile(
          widget.message.attachments[1],
          width: 270,
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
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: attachment.thumbnailUrl ?? attachment.url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: width,
              height: height,
              color: const Color(0xFF666666).withValues(alpha: 51),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        if (isVideo) ...[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 77),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: const Center(
                child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
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

  Widget _buildTripleMosaic(List<MediaAttachment> attachments) {
    // One large tile on the left and two stacked on the right, all inside one 270x140 mosaic
    const double contentWidth = 270;
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
          SizedBox(
            width: rightWidth,
            child: Column(
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
          ),
        ],
      ),
    );
  }

  Widget _buildGridMosaic(List<MediaAttachment> attachments) {
    // Two rows of two large tiles (133x140) inside one bubble. Show +N on the last tile if more remain.
    const double contentWidth = 270;
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
            if (row > 0) const SizedBox(height: spacing),
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
                      overlayText:
                          (row * 2 + col == displayCount - 1 &&
                              total > displayCount)
                          ? '+${total - displayCount}'
                          : null,
                    ),
                  if (col == 0) const SizedBox(width: spacing),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideosGridMosaic(List<MediaAttachment> attachments) {
    // Same grid mosaic as images but always shows video overlay icons
    const double contentWidth = 270;
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
            if (row > 0) const SizedBox(height: spacing),
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
                      overlayText:
                          (row * 2 + col == displayCount - 1 &&
                              total > displayCount)
                          ? '+${total - displayCount}'
                          : null,
                    ),
                  if (col == 0) const SizedBox(width: spacing),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimestamp(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}',
        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class WaveformPainter extends CustomPainter {
  final Color color;

  WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / 20;
    final heights = [
      0.3,
      0.7,
      0.4,
      0.8,
      0.6,
      0.9,
      0.5,
      0.7,
      0.3,
      0.6,
      0.8,
      0.4,
      0.9,
      0.5,
      0.7,
      0.6,
      0.4,
      0.8,
      0.3,
      0.5,
    ];

    for (int i = 0; i < heights.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final barHeight = size.height * heights[i];
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
