import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readmore/readmore.dart';
import '../models/post.dart';
import 'auto_play_video.dart';
import 'reaction_picker.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Function(String postId, ReactionType reaction)? onReactionChanged;
  final Function(String postId)? onBookmarkToggle;
  final Function(String postId)? onShare;
  final Function(String postId)? onComment;
  final Function(String postId)? onRepost;
  final Function(String postId)? onTap;
  final bool? isDarkMode;

  const PostCard({
    super.key,
    required this.post,
    this.onReactionChanged,
    this.onBookmarkToggle,
    this.onShare,
    this.onComment,
    this.onRepost,
    this.onTap,
    this.isDarkMode,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showTranslation = false;

  void _toggleTranslation() {
    setState(() {
      _showTranslation = !_showTranslation;
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'now';
  }

  IconData _getReactionIcon(ReactionType? reaction) {
    switch (reaction) {
      case ReactionType.diamond:
        return Icons.workspace_premium;
      case ReactionType.like:
        return Icons.thumb_up_alt;
      case ReactionType.heart:
        return Icons.favorite;
      case ReactionType.wow:
        return Icons.emoji_emotions;
      default:
        return Icons.thumb_up_alt_outlined;
    }
  }

  Color _getReactionColor(ReactionType? reaction) {
    return reaction != null ? const Color(0xFFBFAE01) : const Color(0xFF666666);
  }

  @override
  void dispose() {
    ReactionPickerManager.hideReactions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF000000) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = const Color(0xFF666666);
    final reactionColor = const Color(0xFFBFAE01);
    final bookmarkColor = const Color(0xFFBFAE01);

    // Build repost header text and avatar/icon
    String _repostHeaderText() {
      final rb = widget.post.repostedBy;
      if (rb != null && (rb.actionType ?? '').isNotEmpty) {
        // Auth user reposted
        return 'you reposted this';
      }
      if (rb != null && rb.userName.trim().isNotEmpty) {
        // Another user reposted
        return '${rb.userName} reposted this';
      }
      // Fallback when repost author is not provided by backend
      return 'Reposted';
    }

    Widget _repostHeaderAvatar() {
      final rb = widget.post.repostedBy;
      if (rb != null) {
        return _AvatarCircle(
          url: rb.userAvatarUrl,
          name: rb.userName,
          size: 20,
          isDark: isDarkMode,
        );
      }
      // Fallback: show repeat icon inside a subtle circle
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFEAEAEA),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.repeat, size: 14, color: Color(0xFF666666)),
      );
    }

    return GestureDetector(
      onTap: () => widget.onTap?.call(widget.post.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost header (always show for reposts)
            if (widget.post.isRepost)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _repostHeaderAvatar(),
                    const SizedBox(width: 8),
                    Text(
                      _repostHeaderText(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

            // Post header (original author)
            Row(
              children: [
                _AvatarCircle(
                  url: widget.post.userAvatarUrl,
                  name: widget.post.userName,
                  size: 40,
                  isDark: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title (made bolder)
                      Text(
                        widget.post.userName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Text(
                        _getTimeAgo(widget.post.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.more_horiz, color: secondaryTextColor),
                ),
              ],
            ),

            // Reduced space between header (title) and body
            const SizedBox(height: 6),

            // Post text (from original post if repost)
            if (widget.post.text.isNotEmpty) ...[
              ReadMoreText(
                _showTranslation
                    ? 'Translated: ${widget.post.text}'
                    : widget.post.text,
                trimMode: TrimMode.Length,
                trimLength: 300,
                colorClickableText: reactionColor,
                trimCollapsedText: 'Read more',
                trimExpandedText: 'Read less',
                style: GoogleFonts.inter(fontSize: 16, color: textColor),
                moreStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: reactionColor,
                  fontWeight: FontWeight.w500,
                ),
                lessStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: reactionColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _toggleTranslation,
                child: Text(
                  _showTranslation ? 'Show Original' : 'Translate',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: reactionColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Media content (from original post if repost)
            if (widget.post.mediaType != MediaType.none) ...[
              if (widget.post.mediaType == MediaType.image &&
                  widget.post.imageUrls.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: widget.post.imageUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: secondaryTextColor.withAlpha(51),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFBFAE01),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: secondaryTextColor.withAlpha(51),
                      child: Icon(
                        Icons.broken_image,
                        color: secondaryTextColor,
                        size: 50,
                      ),
                    ),
                  ),
                ),

              if (widget.post.mediaType == MediaType.images &&
                  widget.post.imageUrls.length > 1)
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.post.imageUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 120,
                        height: 160,
                        margin: EdgeInsets.only(
                          right: index < widget.post.imageUrls.length - 1
                              ? 12
                              : 0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: widget.post.imageUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: secondaryTextColor.withAlpha(51),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFBFAE01),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: secondaryTextColor.withAlpha(51),
                            child: Icon(
                              Icons.broken_image,
                              color: secondaryTextColor,
                              size: 30,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (widget.post.mediaType == MediaType.video &&
                  widget.post.videoUrl != null)
                AutoPlayVideo(
                  videoUrl: widget.post.videoUrl!,
                  width: double.infinity,
                  height: 200,
                  borderRadius: BorderRadius.circular(25),
                ),
            ],

            const SizedBox(height: 8),

            // Separator line before engagement buttons
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: secondaryTextColor.withAlpha(76),
            ),

            // Engagement row
            Row(
              children: [
                // Like button with long press
                Builder(
                  builder: (likeButtonContext) => GestureDetector(
                    onTap: () {
                      if (widget.post.userReaction != null) {
                        widget.onReactionChanged?.call(
                          widget.post.id,
                          widget.post.userReaction!,
                        );
                      } else {
                        widget.onReactionChanged?.call(
                          widget.post.id,
                          ReactionType.like,
                        );
                      }
                    },
                    onLongPress: () {
                      final RenderBox renderBox =
                          likeButtonContext.findRenderObject() as RenderBox;
                      final position = renderBox.localToGlobal(Offset.zero);

                      ReactionPickerManager.showReactions(
                        context,
                        position,
                        widget.post,
                        (postId, reaction) {
                          widget.onReactionChanged?.call(postId, reaction);
                        },
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          _getReactionIcon(widget.post.userReaction),
                          size: 20,
                          color: _getReactionColor(widget.post.userReaction),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.post.counts.likes.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Comment button
                GestureDetector(
                  onTap: () => widget.onComment?.call(widget.post.id),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.counts.comments.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Share button
                GestureDetector(
                  onTap: () => widget.onShare?.call(widget.post.id),
                  child: Row(
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.counts.shares.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Repost button
                GestureDetector(
                  onTap: () => widget.onRepost?.call(widget.post.id),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 20, color: secondaryTextColor),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.counts.reposts.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bookmark button
                GestureDetector(
                  onTap: () => widget.onBookmarkToggle?.call(widget.post.id),
                  child: Row(
                    children: [
                      Icon(
                        widget.post.isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: 20,
                        color: widget.post.isBookmarked
                            ? bookmarkColor
                            : secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.counts.bookmarks.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryTextColor,
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
}

class _AvatarCircle extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  final bool isDark;

  const _AvatarCircle({
    required this.url,
    required this.name,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    if (hasUrl) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: CachedNetworkImageProvider(url),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final bg = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEAEAEA);
    final border = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final letter = (name.trim().isNotEmpty ? name.trim()[0] : 'U').toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: size * 0.05),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class ReactionPickerManager {
  static OverlayEntry? _globalOverlayEntry;

  static void hideReactions() {
    _globalOverlayEntry?.remove();
    _globalOverlayEntry = null;
  }

  static void showReactions(
    BuildContext context,
    Offset position,
    Post post,
    Function(String, ReactionType) onReactionChanged,
  ) {
    hideReactions();

    _globalOverlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: hideReactions,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Invisible full-screen tap area
            Positioned.fill(child: Container(color: Colors.transparent)),
            // Reaction picker
            Positioned(
              left: position.dx,
              top: position.dy - 70,
              child: Material(
                color: Colors.transparent,
                child: ReactionPicker(
                  currentReaction: post.userReaction,
                  onReactionSelected: (reaction) {
                    onReactionChanged(post.id, reaction);
                    hideReactions();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_globalOverlayEntry!);
  }
}