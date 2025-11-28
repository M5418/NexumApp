import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';

class PostOptionsBottomSheet extends StatelessWidget {
  final bool isOwnPost;
  final bool isBookmarked;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final VoidCallback? onMuteUser;
  final VoidCallback? onBlockUser;
  final VoidCallback? onCopyLink;
  final VoidCallback? onHidePost;

  const PostOptionsBottomSheet({
    super.key,
    required this.isOwnPost,
    this.isBookmarked = false,
    this.onEdit,
    this.onDelete,
    this.onBookmark,
    this.onShare,
    this.onReport,
    this.onMuteUser,
    this.onBlockUser,
    this.onCopyLink,
    this.onHidePost,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          const SizedBox(height: 24),

          // Options list
          if (isOwnPost) ...[
            // Own post options
            _OptionTile(
              icon: Ionicons.create_outline,
              title: 'Edit Post',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            _OptionTile(
              icon: isBookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
              title: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onBookmark?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.share_social_outline,
              title: 'Share Post',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onShare?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.link_outline,
              title: 'Copy Link',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onCopyLink?.call();
              },
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
            _OptionTile(
              icon: Ionicons.trash_outline,
              title: 'Delete Post',
              textColor: const Color(0xFFFF3B30),
              iconColor: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ] else ...[
            // Other user's post options
            _OptionTile(
              icon: isBookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
              title: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onBookmark?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.share_social_outline,
              title: 'Share Post',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onShare?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.link_outline,
              title: 'Copy Link',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onCopyLink?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.eye_off_outline,
              title: 'Hide Post',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onHidePost?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.volume_mute_outline,
              title: 'Mute User',
              textColor: textColor,
              iconColor: iconColor,
              onTap: () {
                Navigator.pop(context);
                onMuteUser?.call();
              },
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE5E5EA)),
            _OptionTile(
              icon: Ionicons.flag_outline,
              title: 'Report Post',
              textColor: const Color(0xFFFF3B30),
              iconColor: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                onReport?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.ban_outline,
              title: 'Block User',
              textColor: const Color(0xFFFF3B30),
              iconColor: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                onBlockUser?.call();
              },
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    required bool isOwnPost,
    bool isBookmarked = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onBookmark,
    VoidCallback? onShare,
    VoidCallback? onReport,
    VoidCallback? onMuteUser,
    VoidCallback? onBlockUser,
    VoidCallback? onCopyLink,
    VoidCallback? onHidePost,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PostOptionsBottomSheet(
        isOwnPost: isOwnPost,
        isBookmarked: isBookmarked,
        onEdit: onEdit,
        onDelete: onDelete,
        onBookmark: onBookmark,
        onShare: onShare,
        onReport: onReport,
        onMuteUser: onMuteUser,
        onBlockUser: onBlockUser,
        onCopyLink: onCopyLink,
        onHidePost: onHidePost,
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.black.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
