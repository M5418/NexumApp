import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'post_options_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../repositories/interfaces/post_repository.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:ionicons/ionicons.dart';
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
  
  // Local state for likes (like comments do)
  late bool _isLiked;
  late int _likeCount;

  // Returns original post ID for reposts, otherwise current post ID
  String _effectivePostId() {
    if (widget.post.isRepost &&
        (widget.post.originalPostId != null &&
            widget.post.originalPostId!.isNotEmpty)) {
      return widget.post.originalPostId!;
    }
    return widget.post.id;
  }

  // Local state for bookmarks
  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    // Initialize local state from widget props
    _isLiked = widget.post.userReaction != null;
    _likeCount = widget.post.counts.likes.clamp(0, 999999);
    _isBookmarked = widget.post.isBookmarked;
  }

  @override
  void didUpdateWidget(covariant ActivityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync local state when parent rebuilds with new data (e.g., after backend fetch)
    if (oldWidget.post.userReaction != widget.post.userReaction) {
      _isLiked = widget.post.userReaction != null;
    }
    if (oldWidget.post.counts.likes != widget.post.counts.likes) {
      _likeCount = widget.post.counts.likes.clamp(0, 999999);
    }
    if (oldWidget.post.isBookmarked != widget.post.isBookmarked) {
      _isBookmarked = widget.post.isBookmarked;
    }
  }
  
  void _toggleTranslation() {
    setState(() {
      _showTranslation = !_showTranslation;
    });
  }

  @override
  void dispose() {
    ActivityReactionPickerManager.hideReactions();
    super.dispose();
  }

  // Helper to check if URL is a placeholder from optimistic posting
  bool _isPlaceholderUrl(String url) {
    return url.startsWith('uploading_');
  }

  // Build media widgets with placeholder filtering
  List<Widget> _buildMediaWidgets(Color placeholderColor) {
    // Filter out placeholder URLs
    final validImageUrls = widget.post.imageUrls
        .where((url) => !_isPlaceholderUrl(url))
        .toList();
    final validVideoUrl = widget.post.videoUrl != null && !_isPlaceholderUrl(widget.post.videoUrl!)
        ? widget.post.videoUrl
        : null;

    // Show loading indicator if media is still uploading
    final hasPlaceholders = widget.post.imageUrls.any(_isPlaceholderUrl) ||
        (widget.post.videoUrl != null && _isPlaceholderUrl(widget.post.videoUrl!));

    if (hasPlaceholders) {
      return [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: const Color(0xFF666666).withValues(alpha: 0.2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Uploading media...',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (widget.post.mediaType == MediaType.none) {
      return [];
    }

    final widgets = <Widget>[];

    // Single image
    if (widget.post.mediaType == MediaType.image && validImageUrls.isNotEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
          ),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: validImageUrls.first,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: placeholderColor,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: placeholderColor,
              child: const Icon(
                Icons.broken_image,
                color: Color(0xFF666666),
                size: 50,
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images
    if (widget.post.mediaType == MediaType.images && validImageUrls.length > 1) {
      widgets.add(
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: validImageUrls.length,
            itemBuilder: (context, index) {
              return Container(
                width: 120,
                height: 160,
                margin: EdgeInsets.only(
                  right: index < validImageUrls.length - 1 ? 12 : 0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: validImageUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: placeholderColor,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: placeholderColor,
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
      );
    }

    // Video
    if (widget.post.mediaType == MediaType.video && validVideoUrl != null) {
      widgets.add(
        AutoPlayVideo(
          videoUrl: validVideoUrl,
          width: double.infinity,
          height: 200,
          borderRadius: BorderRadius.circular(25),
        ),
      );
    }

    return widgets;
  }

  void _showPostOptions(BuildContext context) {
    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    final isOwnPost = currentUserId == widget.post.authorId;

    PostOptionsBottomSheet.show(
      context,
      isOwnPost: isOwnPost,
      isBookmarked: widget.post.isBookmarked,
      onBookmark: () {
        widget.onBookmarkToggle?.call(_effectivePostId());
      },
      onShare: () {
        widget.onShare?.call(_effectivePostId());
      },
      onCopyLink: () {
        final postId = _effectivePostId();
        Clipboard.setData(ClipboardData(text: 'https://nexum.app/post/$postId'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onEdit: isOwnPost ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit functionality coming soon')),
        );
      } : null,
      onDelete: isOwnPost ? () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          try {
            final postRepo = context.read<PostRepository>();
            await postRepo.deletePost(_effectivePostId());
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete post: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } : null,
      onReport: !isOwnPost ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report functionality coming soon')),
        );
      } : null,
      onMuteUser: !isOwnPost ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mute functionality coming soon')),
        );
      } : null,
      onBlockUser: !isOwnPost ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block functionality coming soon')),
        );
      } : null,
      onHidePost: !isOwnPost ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hide functionality coming soon')),
        );
      } : null,
    );
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
                    () {
                      final rb = widget.post.repostedBy!;
                      final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
                      
                      // Check if current user is the one who reposted
                      if (currentUserId != null && currentUserId == rb.userId) {
                        return 'You reposted this';
                      }
                      
                      // Otherwise show reposter's username
                      final name = rb.userName.trim();
                      if (name.isNotEmpty) return '$name reposted this';
                      return 'Reposted';
                    }(),
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
                      settings: const RouteSettings(name: 'other_user_profile'),
                      builder: (context) => OtherUserProfilePage(
                        userId: widget.post.authorId,
                        userName: widget.post.userName,
                        userAvatarUrl: widget.post.userAvatarUrl,
                        userBio: '',
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
                        settings: const RouteSettings(name: 'other_user_profile'),
                        builder: (context) => OtherUserProfilePage(
                          userId: widget.post.authorId,
                          userName: widget.post.userName,
                          userAvatarUrl: widget.post.userAvatarUrl,
                          userBio: '',
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
                onPressed: () => _showPostOptions(context),
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

          // Media content with placeholder filtering
          ..._buildMediaWidgets(const Color(0xFF666666).withValues(alpha: 0.2)),

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
                    // Optimistic update (like comments do)
                    setState(() {
                      _isLiked = !_isLiked;
                      if (_isLiked) {
                        _likeCount++;
                      } else {
                        _likeCount = (_likeCount - 1).clamp(0, 999999);
                      }
                    });
                    
                    // Call backend
                    widget.onReactionChanged?.call(
                      _effectivePostId(),
                      _isLiked ? ReactionType.like : ReactionType.like, // Toggle
                    );
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
                        _isLiked ? Ionicons.heart : Ionicons.heart_outline,
                        size: 20,
                        color: _isLiked ? const Color(0xFFBFAE01) : const Color(0xFF666666),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _likeCount.toString(),
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
                onTap: () => widget.onComment?.call(_effectivePostId()),
                child: Row(
                  children: [
                    Icon(
                      Ionicons.chatbubble_outline,
                      size: 20,
                      color: const Color(0xFF666666),
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
                onTap: () => widget.onShare?.call(_effectivePostId()),
                child: Row(
                  children: [
                    Icon(
                      Ionicons.arrow_redo_outline,
                      size: 20,
                      color: const Color(0xFF666666),
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
                onTap: () => widget.onRepost?.call(_effectivePostId()),
                child: Row(
                  children: [
                    const Icon(
                      Ionicons.repeat_outline,
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
                onTap: () {
                  // Optimistic update for bookmarks
                  setState(() {
                    _isBookmarked = !_isBookmarked;
                  });
                  widget.onBookmarkToggle?.call(_effectivePostId());
                },
                child: Row(
                  children: [
                    Icon(
                      _isBookmarked
                          ? Ionicons.bookmark
                          : Ionicons.bookmark_outline,
                      size: 20,
                      color: _isBookmarked
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
                    final effectiveId = (post.isRepost &&
                            post.originalPostId != null &&
                            post.originalPostId!.isNotEmpty)
                        ? post.originalPostId!
                        : post.id;
                    onReactionChanged(effectiveId, reaction);
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
