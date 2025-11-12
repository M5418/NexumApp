import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'report_bottom_sheet.dart';

class PostOptionsMenu extends StatelessWidget {
  final String authorName;
  final String postId;
  final String? authorId;
  final VoidCallback? onReport;
  final VoidCallback? onMute;
  final VoidCallback? onBlock;
  final VoidCallback? onDelete;
  final bool isOwnPost;

  const PostOptionsMenu({
    super.key,
    required this.authorName,
    required this.postId,
    this.authorId,
    this.onReport,
    this.onMute,
    this.onBlock,
    this.onDelete,
    this.isOwnPost = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Colors.black : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete option (only for own posts)
            if (isOwnPost) ...[
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        'Delete Post',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: const Color(0xFFE0E0E0),
              ),
            ],
            // Report option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                ReportBottomSheet.show(
                  context,
                  targetType: 'post',
                  targetId: postId,
                  authorName: authorName,
                  onReport: (targetId, cause, comment) {
                    onReport?.call();
                  },
                );
              },
              borderRadius: BorderRadius.vertical(
                top: isOwnPost ? Radius.zero : const Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Report this Post',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFE0E0E0),
            ),

            // Mute option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                onMute?.call();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.volume_off_outlined,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Mute $authorName',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFE0E0E0),
            ),

            // Block option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                onBlock?.call();
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.block,
                      size: 20,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Block $authorName',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String authorName,
    required String postId,
    String? authorId,
    VoidCallback? onReport,
    VoidCallback? onMute,
    VoidCallback? onBlock,
    VoidCallback? onDelete,
    bool isOwnPost = false,
    Offset? position,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Invisible barrier to close menu
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // Menu positioned near the more button
          Positioned(
            top: position?.dy ?? 120,
            right: position?.dx ?? 16,
            child: PostOptionsMenu(
              authorName: authorName,
              postId: postId,
              authorId: authorId,
              onReport: onReport,
              onMute: onMute,
              onBlock: onBlock,
              onDelete: onDelete,
              isOwnPost: isOwnPost,
            ),
          ),
        ],
      ),
    );
  }
}
