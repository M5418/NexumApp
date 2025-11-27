import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readmore/readmore.dart';
import 'package:ionicons/ionicons.dart';
import '../models/post.dart';
import '../other_user_profile_page.dart';
import 'package:provider/provider.dart';
import 'reaction_picker.dart';
import '../repositories/firebase/firebase_translate_repository.dart';
import '../core/i18n/language_provider.dart';
import '../core/time_utils.dart';
import 'auto_play_video.dart';

class HomePostCard extends StatefulWidget {
  final Post post;
  final Function(String postId, ReactionType reaction)? onReactionChanged;
  final Function(String postId)? onBookmarkToggle;
  final Function(String postId)? onShare;
  final Function(String postId)? onComment;
  final Function(String postId)? onRepost;
  final bool? isDarkMode;

  const HomePostCard({
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
  State<HomePostCard> createState() => _HomePostCardState();
}

class _HomePostCardState extends State<HomePostCard> {
  bool _showTranslation = false;
  String? _translatedText;
  String? _lastUgcCode;
  
  // Local state for likes (like comments do)
  late bool _isLiked;
  late int _likeCount;

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
    // Initialize local state from widget props (like comments do)
    _isLiked = widget.post.userReaction != null;
    _likeCount = widget.post.counts.likes.clamp(0, 999999);
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

  // Returns original post ID for reposts, otherwise current post ID
  String _effectivePostId() {
    if (widget.post.isRepost &&
        (widget.post.originalPostId != null &&
            widget.post.originalPostId!.isNotEmpty)) {
      return widget.post.originalPostId!;
    }
    return widget.post.id;
  }

  Color _getTextColor() {
    return widget.isDarkMode ?? false ? Colors.white : Colors.black;
  }

  Color _getBackgroundColor() {
    return widget.isDarkMode ?? false ? const Color(0xFF000000) : Colors.white;
  }

  Color _getBorderColor() {
    return const Color(0xFF666666);
  }

  Color _getShadowColor() {
    return widget.isDarkMode ?? false
        ? const Color(0xFF0C0C0C)
        : Colors.black.withValues(alpha: 0.05);
  }

  @override
  void dispose() {
    HomeReactionPickerManager.hideReactions();
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
            color: placeholderColor,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(),
            blurRadius: 1,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repost indicator - always shows "Username reposted this"
          if (widget.post.isRepost && widget.post.repostedBy != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _AvatarCircle(
                    url: widget.post.repostedBy!.userAvatarUrl,
                    name: widget.post.repostedBy!.userName,
                    size: 20,
                    isDark: widget.isDarkMode ?? false,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.post.repostedBy!.userName} reposted this',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _getTextColor(),
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
                        userBio:
                            'Professional user bio here', // This would come from user data
                        isConnected:
                            false, // This would come from connection status
                      ),
                    ),
                  );
                },
                child: _AvatarCircle(
                  url: widget.post.userAvatarUrl,
                  name: widget.post.userName,
                  size: 40,
                  isDark: widget.isDarkMode ?? false,
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
                          userBio:
                              'Professional user bio here', // This would come from user data
                          isConnected:
                              false, // This would come from connection status
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
                          color: _getTextColor(),
                        ),
                      ),
                      Text(
                        TimeUtils.relativeLabel(widget.post.createdAt, locale: 'en_short'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _getTextColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_horiz, color: _getTextColor()),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Post text
          if (widget.post.text.isNotEmpty) ...[
            ReadMoreText(
              _showTranslation
                  ? (_translatedText ?? widget.post.text)
                  : widget.post.text,
              trimMode: TrimMode.Length,
              trimLength: 300,
              colorClickableText: const Color(0xFFBFAE01),
              trimCollapsedText: 'Read more',
              trimExpandedText: 'Read less',
              style: GoogleFonts.inter(fontSize: 16, color: _getTextColor()),
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
            // Only show translate button if translation is enabled in settings
            if (context.watch<LanguageProvider>().postTranslationEnabled)
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
          ..._buildMediaWidgets(_getBorderColor().withValues(alpha: 0.2)),

          const SizedBox(height: 8),

          // Separator line before engagement buttons
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: _getBorderColor(),
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

                    HomeReactionPickerManager.showReactions(
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
                          color: _getTextColor(),
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
                    const Icon(
                      Ionicons.chatbubble_outline,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.comments.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _getTextColor(),
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
                    const Icon(
                      Ionicons.arrow_redo_outline,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.shares.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _getTextColor(),
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
                        color: _getTextColor(),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bookmark button
              GestureDetector(
                onTap: () => widget.onBookmarkToggle?.call(_effectivePostId()),
                child: Row(
                  children: [
                    Icon(
                      widget.post.isBookmarked
                          ? Ionicons.bookmark
                          : Ionicons.bookmark_outline,
                      size: 20,
                      color: widget.post.isBookmarked
                          ? const Color(0xFFBFAE01)
                          : _getTextColor(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.counts.bookmarks.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _getTextColor(),
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

class HomeReactionPickerManager {
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
                    // Use original post ID for reposts, otherwise current post ID
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