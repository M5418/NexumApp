import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../conversations_page.dart';
import '../models/message.dart';

class ChatCard extends StatelessWidget {
  final ChatItem chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ChatCard({
    super.key,
    required this.chat,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CachedNetworkImage(
                imageUrl: chat.avatarUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF666666),
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF666666),
                    size: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    chat.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Last message
                  Row(
                    children: [
                      if (chat.lastType != MessageType.text) ...[
                        Icon(
                          _getMessageTypeIcon(chat.lastType),
                          size: 16,
                          color: const Color(0xFF666666),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _getLastMessageText(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF666666),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Time and unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Time
                Text(
                  chat.lastTime,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),

                const SizedBox(height: 8),

                // Unread badge
                if (chat.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        chat.unreadCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.voice:
        return Icons.mic;
      case MessageType.text:
        return Icons.message;
      case MessageType.file:
        return Icons.insert_drive_file;
    }
  }

  String _getLastMessageText() {
    switch (chat.lastType) {
      case MessageType.text:
        return chat.lastText ?? '';
      case MessageType.image:
        return chat.lastText ?? 'Images';
      case MessageType.video:
        return chat.lastText ?? 'Video';
      case MessageType.voice:
        return chat.lastText ?? 'Voice note';
      case MessageType.file:
        return chat.lastText ?? 'Attachment';
    }
  }
}