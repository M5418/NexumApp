import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readmore/readmore.dart';
import '../models/post.dart';
import '../other_user_profile_page.dart';
import 'auto_play_video.dart';
import 'reaction_picker.dart';
import '../core/time_utils.dart';

class ActivityPostCard extends StatefulWidget {
  final Post post;
  final Function(String postId, ReactionType reaction)? onReactionChanged;
  final Function(String postId)? onBookmarkToggle;
  final Function(String postId)? onShare;
  final Function(String postId)? onComment;
  final Function(String postId)? onRepost;
  final bool? isDarkMode;

  const ActivityPostCard({
    super.key,
    required this.post,
    this.onReactionChanged,
    this.onBookmarkToggle,
    this.onShare,
    this.onComment,
    this.onRepost,
    this.isDarkMode,
  });

  @override
  State<ActivityPostCard> createState() => _ActivityPostCardState();
}

class _ActivityPostCardState extends State<ActivityPostCard> {
  bool _showTranslation = false;

  void _toggleTranslation() {
    setState(() {
      _showTranslation = !_showTranslation;
    });
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
    ActivityReactionPickerManager.hideReactions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ?? false
            ? const Color(0xFF333333)
            : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 1,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity indicator - shows the action type
          if (widget.post.isRepost && widget.post.repostedBy != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(
                          widget.post.repostedBy!.userAvatarUrl,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.post.repostedBy!.userName} ${widget.post.repostedBy!.actionType}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Post header
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherUserProfilePage(
                        userId: widget.post.userName.toLowerCase().replaceAll(
                          ' ',
                          '_',
                        ),
                        userName: widget.post.userName,
                        userAvatarUrl: widget.post.userAvatarUrl,
                        userBio: 'Professional user bio here',
                        isConnected: false,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(
                        widget.post.userAvatarUrl,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherUserProfilePage(
                          userId: widget.post.userName.toLowerCase().replaceAll(
                            ' ',
                            '_',
                          ),
                          userName: widget.post.userName,
                          userAvatarUrl: widget.post.userAvatarUrl,
                          userBio: 'Professional user bio here',
                          isConnected: false,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.userName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode ?? false
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                     Text(
                        TimeUtils.relativeLabel(widget.post.createdAt, locale: 'en_short'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz, color: Color(0xFF666666)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Post text
          if (widget.post.text.isNotEmpty) ...[
            ReadMoreText(
              _showTranslation
                  ? 'Translated: ${widget.post.text}'
                  : widget.post.text,
              trimMode: TrimMode.Length,
              trimLength: 300,
              colorClickableText: const Color(0xFFBFAE01),
              trimCollapsedText: 'Read more',
              trimExpandedText: 'Read less',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: widget.isDarkMode ?? false ? Colors.white : Colors.black,
              ),
              moreStyle: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFFBFAE01),
                fontWeight: FontWeight.w500,
              ),
              lessStyle: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFFBFAE01),
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
                  color: const Color(0xFFBFAE01),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Media content
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
                    color: const Color(0xFF666666).withValues(alpha: 51),
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
                    color: const Color(0xFF666666).withValues(alpha: 51),
                    child: const Icon(
                      Icons.broken_image,
                      color: Color(0xFF666666),
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
                          color: const Color(0xFF666666).withValues(alpha: 51),
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
                          color: const Color(0xFF666666).withValues(alpha: 51),
                          child: const Icon(
                            Icons.broken_image,
                            color: Color(0xFF666666),
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
            color: const Color(0xFF666666).withValues(alpha: 77),
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

                    ActivityReactionPickerManager.showReactions(
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
                          color: const Color(0xFF666666),
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
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.comments.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
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
                    const Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.shares.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
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
                    const Icon(
                      Icons.repeat,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.reposts.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
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
                          ? const Color(0xFFBFAE01)
                          : const Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.bookmarks.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
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
}

class ActivityReactionPickerManager {
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
            Positioned.fill(child: Container(color: Colors.transparent)),
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
