import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';

class MessageActionsSheet extends StatelessWidget {
  final Message message;
  final bool isDark;
  final bool isStarred;
  final ValueChanged<String> onCopy;
  final VoidCallback onReply;
  final VoidCallback onToggleStar;
  final VoidCallback onShareToStory;
  final VoidCallback onDelete;
  final ValueChanged<String> onReact;

  const MessageActionsSheet({
    super.key,
    required this.message,
    required this.isDark,
    required this.isStarred,
    required this.onCopy,
    required this.onReply,
    required this.onToggleStar,
    required this.onShareToStory,
    required this.onDelete,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final onBase = isDark ? Colors.white : Colors.black;
    final divider = isDark ? Colors.white10 : Colors.black12;
    final label = _messageLabel(message);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildPreviewThumb(message),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message.content.isNotEmpty ? message.content : label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: onBase,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Reactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'React',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final emoji in const [
                            '👍',
                            '❤️',
                            '😂',
                            '😮',
                            '😢',
                            '🥳',
                            '👏',
                            '🔥',
                            '🙏',
                            '😎',
                            '🤯',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  onReact(emoji);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: divider),
            _actionTile(
              context: context,
              icon: Icons.copy_outlined,
              label: 'Copy',
              onTap: () {
                onCopy(message.content.isNotEmpty ? message.content : label);
                Navigator.pop(context);
              },
            ),
            _actionTile(
              context: context,
              icon: Icons.reply_outlined,
              label: 'Reply',
              onTap: () {
                onReply();
                Navigator.pop(context);
              },
            ),
            _actionTile(
              context: context,
              icon: isStarred ? Icons.star : Icons.star_border,
              label: isStarred ? 'Unstar Message' : 'Star Message',
              onTap: () {
                onToggleStar();
                Navigator.pop(context);
              },
            ),
            _actionTile(
              context: context,
              icon: Icons.ios_share,
              label: 'Share to Story',
              onTap: () {
                onShareToStory();
                Navigator.pop(context);
              },
            ),
            Divider(height: 1, color: divider),
            _actionTile(
              context: context,
              icon: Icons.delete_outline,
              label: 'Delete',
              destructive: true,
              onTap: () {
                // Close the bottom sheet first, then show the confirm dialog
                Navigator.pop(context);
                Future.microtask(onDelete);
              },
            ),
          ],
        ),
      ),
    );
  }

  ListTile _actionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    bool destructive = false,
    required VoidCallback onTap,
  }) {
    final onBase = isDark ? Colors.white : Colors.black;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: destructive ? Colors.red : onBase),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: destructive ? Colors.red : onBase,
        ),
      ),
    );
  }

  Widget _buildPreviewThumb(Message message) {
    const double size = 44;
    final radius = BorderRadius.circular(10);
    if (message.type == MessageType.image && message.attachments.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl:
              message.attachments.first.thumbnailUrl ??
              message.attachments.first.url,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (message.type == MessageType.video &&
        message.attachments.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: radius,
            child: CachedNetworkImage(
              imageUrl:
                  message.attachments.first.thumbnailUrl ??
                  'https://picsum.photos/200?blur=2',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: radius,
              ),
              child: const Center(
                child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      );
    } else if (message.type == MessageType.voice) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: radius,
        ),
        child: const Center(
          child: Icon(Icons.mic_none, color: Color(0xFF6B7280)),
        ),
      );
    } else if (message.type == MessageType.file) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: radius,
        ),
        child: const Center(
          child: Icon(Icons.description, color: Color(0xFF6B7280)),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: radius,
      ),
      child: const Center(
        child: Icon(Icons.chat_bubble_outline, color: Color(0xFF6B7280)),
      ),
    );
  }

  String _messageLabel(Message message) {
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        final c = message.attachments.length;
        return c <= 1 ? 'Photo' : '$c photos';
      case MessageType.video:
        final c = message.attachments.length;
        if (c <= 1) {
          final d = message.attachments.first.duration;
          return d != null ? 'Video (${_formatDuration(d)})' : 'Video';
        }
        return '$c videos';
      case MessageType.voice:
        final d = message.attachments.isNotEmpty
            ? message.attachments.first.duration
            : null;
        return d != null
            ? 'Voice message (${_formatDuration(d)})'
            : 'Voice message';
      case MessageType.file:
        final c = message.attachments.length;
        if (c <= 1) {
          return message.attachments.first.fileName ?? 'Document';
        }
        return '$c files';
    }
  }

  String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }
}