import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/cache_config.dart';
import 'post_options_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:readmore/readmore.dart';
import 'package:ionicons/ionicons.dart';
import '../models/post.dart';
import '../other_user_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../profile_page.dart';
import 'auto_play_video.dart';
import 'reaction_picker.dart';
import '../core/time_utils.dart';
import 'package:provider/provider.dart';
import '../repositories/firebase/firebase_translate_repository.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/interfaces/post_repository.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Function(String postId, ReactionType reaction)? onReactionChanged;
  final Function(String postId)? onBookmarkToggle;
  final Function(String postId)? onShare;
  final Function(String postId)? onComment;
  final Function(String postId)? onRepost;
  final Function(String postId)? onTap;
  final bool? isDarkMode;
  final String? currentUserId;

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
    this.currentUserId,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showTranslation = false;
  String? _translatedText;
  String? _lastUgcCode;
  
  // Local state for likes (like comments do)
  late bool _isLiked;
  late int _likeCount;
  late bool _isBookmarked;

  Future<void> _translateCurrentText(String target) async {
    final text = widget.post.text.trim();
    if (text.isEmpty) return;
    try {
      final repo = FirebaseTranslateRepository();
      final translated = await repo.translateText(text, target);
      if (!mounted) return;
      setState(() {
        _translatedText = translated;
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // Initialize local state from widget props
    _isLiked = widget.post.userReaction != null;
    _likeCount = widget.post.counts.likes.clamp(0, 999999);
    _isBookmarked = widget.post.isBookmarked;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = Provider.of<LanguageProvider>(context).ugcTargetCode;
    if (code != _lastUgcCode) {
      _lastUgcCode = code;
      if (_showTranslation) {
        _translatedText = null;
        _translateCurrentText(code);
      }
    }
  }

  Future<void> _toggleTranslation() async {
    final text = widget.post.text.trim();
    if (!_showTranslation && text.isNotEmpty) {
      if (_translatedText == null) {
        try {
          final target = context.read<LanguageProvider>().ugcTargetCode;
          final repo = FirebaseTranslateRepository();
          final translated = await repo.translateText(text, target);
          if (!mounted) return;
          setState(() {
            _translatedText = translated;
            _lastUgcCode = target;
          });
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _showTranslation = !_showTranslation;
      });
    }
  }

  String _effectivePostId() {
    if (widget.post.isRepost &&
        (widget.post.originalPostId != null &&
            widget.post.originalPostId!.isNotEmpty)) {
      return widget.post.originalPostId!;
    }
    return widget.post.id;
  }

  @override
  void dispose() {
    ReactionPickerManager.hideReactions();
    super.dispose();
  }

  // Helper to check if URL is a placeholder from optimistic posting
  bool _isPlaceholderUrl(String url) {
    return url.startsWith('uploading_');
  }

  // Build media widgets with placeholder filtering
  List<Widget> _buildMediaWidgets(Color secondaryTextColor) {
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
            color: secondaryTextColor.withAlpha(51),
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
                    color: secondaryTextColor,
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
            cacheManager: CacheConfig.customCacheManager,
            maxWidthDiskCache: 1200,
            maxHeightDiskCache: 1200,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: secondaryTextColor.withAlpha(51),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
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
                  cacheManager: CacheConfig.customCacheManager,
                  maxWidthDiskCache: 600,
                  maxHeightDiskCache: 800,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: secondaryTextColor.withAlpha(51),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
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
      isBookmarked: _isBookmarked,
      onBookmark: () {
        setState(() {
          _isBookmarked = !_isBookmarked;
        });
        widget.onBookmarkToggle?.call(_effectivePostId());
      },
      onShare: () {
        widget.onShare?.call(_effectivePostId());
      },
      onCopyLink: () {
        final postId = _effectivePostId();
        // Copy link to clipboard
        Clipboard.setData(ClipboardData(text: 'https://nexum.app/post/$postId'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onEdit: isOwnPost ? () {
        // TODO: Implement edit functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit functionality coming soon')),
        );
      } : null,
      onDelete: isOwnPost ? () async {
        // Show confirmation dialog
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
        // TODO: Implement report functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report functionality coming soon')),
        );
      } : null,
      onMuteUser: !isOwnPost ? () {
        // TODO: Implement mute functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mute functionality coming soon')),
        );
      } : null,
      onBlockUser: !isOwnPost ? () {
        // TODO: Implement block functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block functionality coming soon')),
        );
      } : null,
      onHidePost: !isOwnPost ? () {
        // TODO: Implement hide functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hide functionality coming soon')),
        );
      } : null,
    );
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

    String repostHeaderText() {
      final rb = widget.post.repostedBy;
      if (rb == null) return 'Reposted';

      // Get current user ID from parameter or Firebase Auth
      final currentUserId = widget.currentUserId ?? fb.FirebaseAuth.instance.currentUser?.uid;
      
      // Check if current user is the one who reposted
      if (currentUserId != null && rb.userId != null && currentUserId == rb.userId) {
        return 'You reposted this';
      }
      
      // Otherwise show reposter's username
      if (rb.userName.trim().isNotEmpty) return '${rb.userName} reposted this';
      return 'Reposted';
    }

    Widget repostHeaderAvatar() {
      final rb = widget.post.repostedBy;
      if (rb != null) {
        return _AvatarCircle(
          url: rb.userAvatarUrl,
          name: rb.userName,
          size: 20,
          isDark: isDarkMode,
        );
      }
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
      onTap: () => widget.onTap?.call(_effectivePostId()),
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
            if (widget.post.isRepost)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    repostHeaderAvatar(),
                    const SizedBox(width: 8),
                    Text(
                      repostHeaderText(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
                    if (currentUserId == widget.post.authorId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'other_user_profile'), builder: (context) => const ProfilePage()),
                      );
                    } else {
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
                    }
                  },
                  child: _AvatarCircle(
                    url: widget.post.userAvatarUrl,
                    name: widget.post.userName,
                    size: 40,
                    isDark: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
                      if (currentUserId == widget.post.authorId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(settings: const RouteSettings(name: 'other_user_profile'), builder: (context) => const ProfilePage()),
                        );
                      } else {
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
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.userName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          TimeUtils.relativeLabel(widget.post.createdAt, locale: 'en_short'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showPostOptions(context),
                  icon: Icon(Icons.more_horiz, color: secondaryTextColor),
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (widget.post.text.isNotEmpty) ...[
              ReadMoreText(
                _showTranslation
                    ? (_translatedText ?? widget.post.text)
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
              // Only show translate button if translation is enabled in settings
              if (context.watch<LanguageProvider>().postTranslationEnabled)
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

            // Build media widgets with placeholder filtering
            ..._buildMediaWidgets(secondaryTextColor),

            const SizedBox(height: 8),

            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: secondaryTextColor.withAlpha(76),
            ),

            Row(
              children: [
                Builder(
                  builder: (likeButtonContext) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLiked = !_isLiked;
                        if (_isLiked) {
                          _likeCount++;
                        } else {
                          _likeCount = (_likeCount - 1).clamp(0, 999999);
                        }
                      });
                      
                      widget.onReactionChanged?.call(
                        _effectivePostId(),
                        _isLiked ? ReactionType.like : ReactionType.like, // Toggle
                      );
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
                          setState(() {
                            if (!_isLiked) {
                              _isLiked = true;
                              _likeCount++;
                            }
                          });
                          widget.onReactionChanged?.call(
                            _effectivePostId(),
                            reaction,
                          );
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
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                GestureDetector(
                  onTap: () => widget.onComment?.call(_effectivePostId()),
                  child: Row(
                    children: [
                      Icon(
                        Ionicons.chatbubble_outline,
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

                GestureDetector(
                  onTap: () => widget.onShare?.call(_effectivePostId()),
                  child: Row(
                    children: [
                      Icon(
                        Ionicons.arrow_redo_outline,
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

                GestureDetector(
                  onTap: () => widget.onRepost?.call(_effectivePostId()),
                  child: Row(
                    children: [
                      Icon(Ionicons.repeat_outline, size: 20, color: secondaryTextColor),
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
  static GlobalKey<_AnimatedReactionOverlayState>? _overlayKey;

  static void hideReactions() {
    if (_overlayKey?.currentState != null) {
      _overlayKey!.currentState!.hide();
      return;
    }
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

    _overlayKey = GlobalKey<_AnimatedReactionOverlayState>();
    _globalOverlayEntry = OverlayEntry(
      builder: (context) => _AnimatedReactionOverlay(
        key: _overlayKey,
        position: position,
        post: post,
        onSelected: (reaction) {
          // Use _effectivePostId to ensure we target the original post for reposts
          final effectiveId = (post.isRepost && 
              post.originalPostId != null && 
              post.originalPostId!.isNotEmpty) 
              ? post.originalPostId! 
              : post.id;
          onReactionChanged(effectiveId, reaction);
        },
        onDismissed: () {
          _globalOverlayEntry?.remove();
          _globalOverlayEntry = null;
          _overlayKey = null;
        },
      ),
    );

    Overlay.of(context).insert(_globalOverlayEntry!);
  }
}

class _AnimatedReactionOverlay extends StatefulWidget {
  final Offset position;
  final Post post;
  final ValueChanged<ReactionType> onSelected;
  final VoidCallback onDismissed;

  const _AnimatedReactionOverlay({
    super.key,
    required this.position,
    required this.post,
    required this.onSelected,
    required this.onDismissed,
  });

  @override
  State<_AnimatedReactionOverlay> createState() => _AnimatedReactionOverlayState();
}

class _AnimatedReactionOverlayState extends State<_AnimatedReactionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _controller.forward();
  }

  void hide() {
    if (!_controller.isAnimating) {
      _controller.reverse().whenComplete(() {
        if (mounted) widget.onDismissed();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hide,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.transparent)),
          Positioned(
            left: widget.position.dx,
            top: widget.position.dy - 70,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: ReactionPicker(
                  currentReaction: widget.post.userReaction,
                  onReactionSelected: (reaction) {
                    widget.onSelected(reaction);
                    hide();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}