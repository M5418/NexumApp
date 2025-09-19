import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/post_detail.dart';
import 'models/comment.dart';
import 'models/post.dart';
import 'widgets/media_carousel.dart';
import 'widgets/auto_play_video.dart';
import 'widgets/comment_thread.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/post_options_menu.dart';
import 'widgets/share_bottom_sheet.dart';

class PostPage extends StatefulWidget {
  final String postId;

  const PostPage({super.key, required this.postId});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  bool _showTranslation = false;
  late PostDetail _post;
  bool _isLiked = false;
  bool _isBookmarked = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _post = getSamplePostDetail();
    _isLiked = _post.userReaction != null;
    _isBookmarked = _post.isBookmarked;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _toggleTranslation() {
    setState(() {
      _showTranslation = !_showTranslation;
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  void _showPostOptions() {
    PostOptionsMenu.show(
      context,
      authorName: _post.authorName,
      postId: _post.id,
      onReport: () {
        // Handle report functionality - now handled by ReportBottomSheet
      },
      onMute: () {
        // Handle mute functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_post.authorName} muted',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      position: const Offset(16, 120),
    );
  }

  void _showShareOptions() {
    ShareBottomSheet.show(
      context,
      onStories: () {
        // Handle share to stories
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Stories', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
      onCopyLink: () {
        // Handle copy link
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Link copied to clipboard',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF9E9E9E),
          ),
        );
      },
      onTelegram: () {
        // Handle share to Telegram
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Telegram', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF0088CC),
          ),
        );
      },
      onFacebook: () {
        // Handle share to Facebook
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Facebook', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      },
      onMore: () {
        // Handle more share options
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('More share options', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      onSendToUsers: (selectedUsers, message) {
        // Handle sending to selected users
        final userNames = selectedUsers.map((user) => user.name).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent to $userNames${message.isNotEmpty ? ' with message: "$message"' : ''}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFFBFAE01),
          ),
        );
      },
    );
  }

  void _submitComment() {
    // Handle comment submission
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final surfaceColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),

                  // Title
                  Expanded(
                    child: Center(
                      child: Text(
                        'Post',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),

                  // More button
                  GestureDetector(
                    onTap: _showPostOptions,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0),
                        blurRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author info
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(_post.authorAvatarUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.authorName,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    _getTimeAgo(_post.createdAt),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Post text
                        if (_post.text.isNotEmpty) ...[
                          Text(
                            _showTranslation
                                ? 'Translated: ${_post.text}'
                                : _post.text,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black,
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
                          const SizedBox(height: 20),
                        ],

                        // Media content
                        if (_post.mediaType != MediaType.none) ...[
                          if (_post.mediaType == MediaType.image &&
                              _post.imageUrls.isNotEmpty)
                            MediaCarousel(
                              imageUrls: _post.imageUrls,
                              height: 650,
                            ),
                          if (_post.mediaType == MediaType.video &&
                              _post.videoUrl != null)
                            AutoPlayVideo(
                              videoUrl: _post.videoUrl!,
                              width: double.infinity,
                              height: 300,
                              borderRadius: BorderRadius.circular(25),
                            ),
                          const SizedBox(height: 16),
                        ],

                        // Engagement bar
                        Row(
                          children: [
                            // Like button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLiked = !_isLiked;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked
                                        ? Icons.thumb_up_alt
                                        : Icons.thumb_up_alt_outlined,
                                    size: 20,
                                    color: _isLiked
                                        ? const Color(0xFFBFAE01)
                                        : const Color(0xFF666666),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _post.counts.likes.toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Comment button
                            Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                  color: Color(0xFF666666),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _post.counts.comments.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 20),

                            // Share button
                            GestureDetector(
                              onTap: _showShareOptions,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.share_outlined,
                                    size: 20,
                                    color: Color(0xFF666666),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _post.counts.shares.toString(),
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.repeat,
                                  size: 20,
                                  color: Color(0xFF666666),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _post.counts.reposts.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Bookmark button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isBookmarked = !_isBookmarked;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _isBookmarked
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    size: 20,
                                    color: _isBookmarked
                                        ? const Color(0xFFBFAE01)
                                        : const Color(0xFF666666),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _post.counts.bookmarks.toString(),
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

                        const SizedBox(height: 12),

                        // Post date
                        Text(
                          _getTimeAgo(_post.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF666666),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Separator
                        Container(
                          height: 0.2,
                          color: const Color(0xFF666666).withValues(alpha: 51),
                        ),

                        const SizedBox(height: 20),

                        // Comments section
                        if (_post.comments.isNotEmpty) ...[
                          ..._post.comments.map(
                            (comment) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: CommentThread(
                                comment: comment,
                                isFirstReply:
                                    false, // Top-level comments don't need connector lines
                                onReply: (commentId) {
                                  // Handle reply
                                },
                                onLike: (commentId) {
                                  // Handle comment like
                                },
                              ),
                            ),
                          ),

                          // View all comments button
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'View all comments',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Comment input card
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write a comment...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _submitComment,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedNavbar(
        selectedIndex: 0,
        onTabChange: (index) {
          Navigator.pop(context);
        },
      ),
    );
  }
}

// Sample data
PostDetail getSamplePostDetail() {
  return PostDetail(
    id: 'post_1',
    authorName: 'Emma Wilson',
    authorAvatarUrl:
        'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    text:
        'Get your hands dirty and create something beautiful! Discover the art of garden making — from shaping clay to adding the final touches.',
    mediaType: MediaType.image,
    imageUrls: [
      'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=600&h=400&fit=crop',
    ],
    counts: PostCounts(
      likes: 124,
      comments: 18,
      shares: 7,
      reposts: 3,
      bookmarks: 45,
    ),
    userReaction: null,
    isBookmarked: false,
    comments: [
      Comment(
        id: 'c1',
        userId: 'user_alex',
        userName: 'alexchldn',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
        text: 'This looks so peaceful! 😍',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likesCount: 12,
        isLikedByUser: true,
        replies: [
          Comment(
            id: 'c1r1',
            userId: 'user_emma',
            userName: 'emmawilson',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face',
            text: 'Thank you! It was such a relaxing afternoon 🌿',
            createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
            likesCount: 5,
            isLikedByUser: false,
            replies: [],
            parentCommentId: 'c1',
          ),
        ],
      ),
      Comment(
        id: 'c2',
        userId: 'user_garden',
        userName: 'gardenista',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face',
        text: 'Love this! Where did you get that beautiful clay? 🏺',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likesCount: 8,
        isLikedByUser: false,
        replies: [
          Comment(
            id: 'c2r1',
            userId: 'user_emma',
            userName: 'emmawilson',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face',
            text:
                'Local pottery studio downtown! They have amazing selection 😊',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            likesCount: 3,
            isLikedByUser: false,
            replies: [],
            parentCommentId: 'c2',
          ),
          Comment(
            id: 'c2r2',
            userId: 'user_johnny',
            userName: 'johnnyclay',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
            text: 'I know that place! Their workshops are incredible too',
            createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
            likesCount: 2,
            isLikedByUser: false,
            replies: [],
            parentCommentId: 'c2',
          ),
        ],
      ),
      Comment(
        id: 'c3',
        userId: 'user_art',
        userName: 'artlover',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop&crop=face',
        text: 'The textures in this photo are absolutely stunning! 🎨',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        likesCount: 15,
        isLikedByUser: false,
        replies: [],
      ),
    ],
  );
}
