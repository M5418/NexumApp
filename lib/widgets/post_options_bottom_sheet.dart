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
    final surfaceColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Options list
          if (isOwnPost) ...[
            // Own post options
            _OptionTile(
              icon: Ionicons.create_outline,
              title: 'Edit Post',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            _OptionTile(
              icon: isBookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
              title: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onBookmark?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.share_social_outline,
              title: 'Share Post',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onShare?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.link_outline,
              title: 'Copy Link',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onCopyLink?.call();
              },
            ),
            const Divider(height: 1),
            _OptionTile(
              icon: Ionicons.trash_outline,
              title: 'Delete Post',
              textColor: Colors.red,
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
              onTap: () {
                Navigator.pop(context);
                onBookmark?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.share_social_outline,
              title: 'Share Post',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onShare?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.link_outline,
              title: 'Copy Link',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onCopyLink?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.eye_off_outline,
              title: 'Hide Post',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onHidePost?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.volume_mute_outline,
              title: 'Mute User',
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                onMuteUser?.call();
              },
            ),
            const Divider(height: 1),
            _OptionTile(
              icon: Ionicons.flag_outline,
              title: 'Report Post',
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onReport?.call();
              },
            ),
            _OptionTile(
              icon: Ionicons.ban_outline,
              title: 'Block User',
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onBlockUser?.call();
              },
            ),
          ],

          const SizedBox(height: 10),
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
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: textColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
