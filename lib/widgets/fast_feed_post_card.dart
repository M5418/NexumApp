import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ionicons/ionicons.dart';
import '../models/post.dart';
import '../core/time_utils.dart';

/// Optimized post card for fast feed rendering
/// - Uses cached_network_image for thumbnails
/// - No async calls during build
/// - Shows video thumbnail with play icon (no autoplay)
/// - All data comes from denormalized post document
class FastFeedPostCard extends StatelessWidget {
  final Post post;
  final bool isDarkMode;
  final String? currentUserId;
  final Function(String postId, ReactionType reaction)? onReactionChanged;
  final Function(String postId)? onBookmarkToggle;
  final Function(String postId)? onShare;
  final Function(String postId)? onComment;
  final Function(String postId)? onRepost;
  final Function(String postId)? onTap;

  const FastFeedPostCard({
    super.key,
    required this.post,
    this.isDarkMode = false,
    this.currentUserId,
    this.onReactionChanged,
    this.onBookmarkToggle,
    this.onShare,
    this.onComment,
    this.onRepost,
    this.onTap,
  });

  String _effectivePostId() {
    if (post.isRepost && post.originalPostId != null && post.originalPostId!.isNotEmpty) {
      return post.originalPostId!;
    }
    return post.id;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = const Color(0xFF666666);
    final accentColor = const Color(0xFFBFAE01);

    return GestureDetector(
      onTap: () => onTap?.call(_effectivePostId()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost badge
            if (post.isRepost && post.repostedBy != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(Ionicons.repeat_outline, size: 14, color: subtextColor),
                    const SizedBox(width: 6),
                    Text(
                      '${post.repostedBy!.userName} reposted',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Header: Avatar + Name + Time
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar with cached image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: post.userAvatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: post.userAvatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                child: Icon(Icons.person, color: subtextColor, size: 24),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                child: Icon(Icons.person, color: subtextColor, size: 24),
                              ),
                            )
                          : Container(
                              color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                              child: Icon(Icons.person, color: subtextColor, size: 24),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TimeUtils.relativeLabel(post.createdAt, locale: 'en_short'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: subtextColor),
                    onPressed: () {
                      // Options menu
                    },
                  ),
                ],
              ),
            ),

            // Text content
            if (post.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  post.text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textColor,
                    height: 1.4,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Media (thumbnails only, no HD)
            if (post.imageUrls.isNotEmpty || post.videoUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildMedia(),
              ),

            const SizedBox(height: 12),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Like
                  _ActionButton(
                    icon: post.userReaction != null ? Ionicons.heart : Ionicons.heart_outline,
                    label: _formatCount(post.counts.likes),
                    color: post.userReaction != null ? accentColor : subtextColor,
                    onTap: () => onReactionChanged?.call(_effectivePostId(), ReactionType.heart),
                  ),
                  // Comment
                  _ActionButton(
                    icon: Ionicons.chatbubble_outline,
                    label: _formatCount(post.counts.comments),
                    color: subtextColor,
                    onTap: () => onComment?.call(_effectivePostId()),
                  ),
                  // Repost
                  _ActionButton(
                    icon: Ionicons.repeat_outline,
                    label: _formatCount(post.counts.reposts),
                    color: subtextColor,
                    onTap: () => onRepost?.call(_effectivePostId()),
                  ),
                  // Share
                  _ActionButton(
                    icon: Ionicons.share_outline,
                    label: _formatCount(post.counts.shares),
                    color: subtextColor,
                    onTap: () => onShare?.call(_effectivePostId()),
                  ),
                  // Bookmark
                  _ActionButton(
                    icon: post.isBookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
                    label: '',
                    color: post.isBookmarked ? accentColor : subtextColor,
                    onTap: () => onBookmarkToggle?.call(_effectivePostId()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    // Video: show thumbnail with play icon
    if (post.videoUrl != null) {
      return _buildVideoThumbnail(post.videoUrl!);
    }

    // Single image
    if (post.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: post.imageUrls.first,
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
          placeholder: (context, url) => Container(
            height: 200,
            color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        ),
      );
    }

    // Multiple images: grid
    if (post.imageUrls.length > 1) {
      return _buildImageGrid();
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    // For video, show a placeholder with play icon
    // In production, you'd use a generated thumbnail URL
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        width: double.infinity,
        color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video icon background
            Icon(
              Ionicons.videocam,
              size: 48,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            // Play button overlay
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Ionicons.play,
                size: 32,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final images = post.imageUrls.take(4).toList();
    final hasMore = post.imageUrls.length > 4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            // First image (larger)
            Expanded(
              flex: 2,
              child: CachedNetworkImage(
                imageUrl: images[0],
                fit: BoxFit.cover,
                height: 200,
                placeholder: (context, url) => Container(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 2),
            // Right column
            if (images.length > 1)
              Expanded(
                child: Column(
                  children: [
                    for (int i = 1; i < images.length; i++) ...[
                      if (i > 1) const SizedBox(height: 2),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: images[i],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                              ),
                            ),
                            // Show +N overlay on last image if more
                            if (hasMore && i == images.length - 1)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Text(
                                    '+${post.imageUrls.length - 4}',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
