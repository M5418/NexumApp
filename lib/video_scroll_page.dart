import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/post.dart';
import 'data/sample_data.dart';
import 'data/sample_comments.dart';
import 'widgets/custom_video_player.dart';
import 'widgets/reaction_picker.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'widgets/share_bottom_sheet.dart';

class VideoScrollPage extends StatefulWidget {
  const VideoScrollPage({super.key});

  @override
  State<VideoScrollPage> createState() => _VideoScrollPageState();
}

class _VideoScrollPageState extends State<VideoScrollPage> {
  late PageController _pageController;
  bool _showReactionPicker = false;
  String? _reactionPickerPostId;
  List<Post> _videoPosts = [];
  final Map<String, bool> _expandedTexts =
      {}; // Track expanded state for each post
  final Map<String, CustomVideoPlayer> _videoPlayers = {};
  final Map<String, GlobalKey<CustomVideoPlayerState>> _videoPlayerKeys = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadVideoPosts();
  }

  void _loadVideoPosts() {
    // Filter only video posts from sample data
    final allPosts = SampleData.getSamplePosts();
    _videoPosts = allPosts
        .where((post) => post.mediaType == MediaType.video)
        .toList();

    // Add more sample video posts for demonstration
    _videoPosts.addAll([
      Post(
        id: 'video_2',
        userName: 'Sarah Chen',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        text:
            'Behind the scenes of our latest product launch! The team worked incredibly hard to make this happen. 🚀',
        mediaType: MediaType.video,
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        imageUrls: [],
        counts: const PostCounts(
          likes: 892,
          comments: 156,
          shares: 89,
          reposts: 45,
          bookmarks: 234,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
      ),
      Post(
        id: 'video_3',
        userName: 'Marcus Johnson',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        text:
            'Quick tip for entrepreneurs: Always validate your ideas before building! Here\'s how we did it.',
        mediaType: MediaType.video,
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        imageUrls: [],
        counts: const PostCounts(
          likes: 567,
          comments: 89,
          shares: 123,
          reposts: 67,
          bookmarks: 178,
        ),
        userReaction: ReactionType.like,
        isBookmarked: true,
        isRepost: false,
      ),
      Post(
        id: 'video_4',
        userName: 'Emma Rodriguez',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
        text:
            'Investor pitch day! Nervous but excited to share our vision with potential partners. 💼✨',
        mediaType: MediaType.video,
        videoUrl:
            'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
        imageUrls: [],
        counts: const PostCounts(
          likes: 1234,
          comments: 234,
          shares: 156,
          reposts: 89,
          bookmarks: 345,
        ),
        userReaction: ReactionType.heart,
        isBookmarked: false,
        isRepost: false,
      ),
      Post(
        id: 'video_long_text',
        userName: 'Alexandra Thompson',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        text:
            'Today I want to share with you the incredible journey we\'ve been on over the past 18 months building our startup from the ground up. It all started with a simple idea during a late-night brainstorming session with my co-founder. We were frustrated with the existing solutions in the market and knew there had to be a better way. What began as sketches on napkins has now evolved into a fully-featured platform that serves thousands of users worldwide. The challenges we faced were immense - from technical hurdles to fundraising difficulties, from team building struggles to market validation concerns. But every obstacle taught us something valuable. We learned the importance of listening to our users, iterating quickly, and staying true to our core mission. The support from our community has been absolutely overwhelming, and seeing how our product positively impacts people\'s daily lives makes every sleepless night worth it. This video shows some behind-the-scenes moments from our recent Series A announcement. Thank you to everyone who believed in us! 🚀💪 #startup #entrepreneurship #innovation',
        mediaType: MediaType.video,
        videoUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        imageUrls: [],
        counts: const PostCounts(
          likes: 2156,
          comments: 387,
          shares: 245,
          reposts: 156,
          bookmarks: 567,
        ),
        userReaction: null,
        isBookmarked: true,
        isRepost: false,
      ),
    ]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Clear video players
    _videoPlayers.clear();
    _videoPlayerKeys.clear();
    super.dispose();
  }

  void _showReactions(String postId) {
    setState(() {
      _showReactionPicker = true;
      _reactionPickerPostId = postId;
    });
  }

  void _hideReactions() {
    setState(() {
      _showReactionPicker = false;
      _reactionPickerPostId = null;
    });
  }

  void _onReactionSelected(ReactionType reaction) {
    // Handle reaction selection
    final postIndex = _videoPosts.indexWhere(
      (post) => post.id == _reactionPickerPostId,
    );
    if (postIndex != -1) {
      setState(() {
        _videoPosts[postIndex] = _videoPosts[postIndex].copyWith(
          userReaction: _videoPosts[postIndex].userReaction == reaction
              ? null
              : reaction,
        );
      });
    }
    _hideReactions();
  }

  void _toggleBookmark(String postId) {
    final postIndex = _videoPosts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      setState(() {
        _videoPosts[postIndex] = _videoPosts[postIndex].copyWith(
          isBookmarked: !_videoPosts[postIndex].isBookmarked,
        );
      });
    }
  }

  CustomVideoPlayer _getVideoPlayer(String videoUrl, Post post) {
    if (!_videoPlayers.containsKey(videoUrl)) {
      _videoPlayerKeys[videoUrl] ??= GlobalKey<CustomVideoPlayerState>();
      _videoPlayers[videoUrl] = CustomVideoPlayer(
        key: _videoPlayerKeys[videoUrl],
        videoUrl: videoUrl,
        isLiked: post.userReaction == ReactionType.heart,
        onLike: () {
          final postIndex = _videoPosts.indexWhere((p) => p.id == post.id);
          if (postIndex != -1) {
            setState(() {
              _videoPosts[postIndex] = _videoPosts[postIndex].copyWith(
                userReaction: ReactionType.heart,
              );
            });
          }
        },
        onUnlike: () {
          final postIndex = _videoPosts.indexWhere((p) => p.id == post.id);
          if (postIndex != -1) {
            setState(() {
              _videoPosts[postIndex] = _videoPosts[postIndex].copyWith(
                userReaction: null,
              );
            });
          }
        },
      );
    }
    return _videoPlayers[videoUrl]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Videos',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Handle search
            },
          ),
        ],
      ),
      body: _videoPosts.isEmpty
          ? Center(
              child: Text(
                'No videos available',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _videoPosts.length,
                  onPageChanged: (index) {},
                  itemBuilder: (context, index) {
                    final post = _videoPosts[index];
                    return _buildVideoItem(context, post, isDark);
                  },
                ),
                if (_showReactionPicker && _reactionPickerPostId != null)
                  Stack(
                    children: [
                      // Full screen invisible overlay to catch background taps
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _hideReactions,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      // Reaction picker positioned on the right
                      Positioned(
                        right: 80,
                        top: 80,
                        bottom: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ReactionPicker(
                              onReactionSelected: _onReactionSelected,
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

  Widget _buildVideoItem(BuildContext context, Post post, bool isDark) {
    final isExpanded = _expandedTexts[post.id] ?? false;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Video player
          if (post.videoUrl != null)
            Positioned.fill(
              child: GestureDetector(
                onLongPress: () => _showReactions(post.id),
                child: _getVideoPlayer(post.videoUrl!, post),
              ),
            ),

          // Subtle gradient overlay only at the bottom for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 102),
                  ],
                ),
              ),
            ),
          ),

          // User info and actions
          Positioned(
            bottom: 40,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(post.userAvatarUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.userName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withValues(alpha: 128),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTimeAgo(post.createdAt),
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withValues(alpha: 128),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Connect',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Post text with expand/collapse
                if (post.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedTexts[post.id] = !isExpanded;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpanded
                              ? post.text
                              : (post.text.length > 100
                                    ? '${post.text.substring(0, 100)}...'
                                    : post.text),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 128),
                              ),
                            ],
                          ),
                        ),
                        if (post.text.length > 100)
                          Text(
                            isExpanded ? 'Read less' : 'Read more',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black.withValues(alpha: 128),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Video progress bar
                if (post.videoUrl != null)
                  (_videoPlayerKeys[post.videoUrl!]?.currentState
                          ?.buildProgressBar() ??
                      const SizedBox.shrink()),
              ],
            ),
          ),

          // Action buttons
          Positioned(
            bottom: 50,
            right: 16,
            child: Column(
              children: [
                // Like button
                _buildActionButton(
                  icon: post.userReaction == ReactionType.heart
                      ? Icons.favorite
                      : Icons.favorite_border,
                  count: post.counts.likes,
                  isActive: post.userReaction != null,
                  onTap: () => _showReactions(post.id),
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Comment button
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  count: post.counts.comments,
                  onTap: () => _showComments(context, post.id),
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Share button
                _buildActionButton(
                  icon: Icons.share_outlined,
                  count: post.counts.shares,
                  onTap: () {
                    ShareBottomSheet.show(
                      context,
                      onStories: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added to Stories!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[600],
                          ),
                        );
                      },
                      onCopyLink: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Link copied to clipboard!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[600],
                          ),
                        );
                      },
                      onTelegram: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Shared to Telegram!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[600],
                          ),
                        );
                      },
                      onFacebook: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Shared to Facebook!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[600],
                          ),
                        );
                      },
                      onMore: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'More sharing options coming soon!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[600],
                          ),
                        );
                      },
                      onSendToUsers: (selectedUsers, message) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sent to ${selectedUsers.length} ${selectedUsers.length == 1 ? 'person' : 'people'}!',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[600],
                          ),
                        );
                      },
                    );
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Bookmark button
                _buildActionButton(
                  icon: post.isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  count: post.counts.bookmarks,
                  isActive: post.isBookmarked,
                  onTap: () => _toggleBookmark(post.id),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    required bool isDark,
    bool isActive = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 128)
                  : Colors.white.withValues(alpha: 128),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive
                  ? const Color(0xFFBFAE01)
                  : (isDark ? Colors.white : Colors.black),
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCount(count),
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showComments(BuildContext context, String postId) {
    final comments = SampleComments.getCommentsForPost(postId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        postId: postId,
        comments: comments,
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
        onLikeComment: (commentId) {
          // Handle comment like
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment liked!', style: GoogleFonts.inter()),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[600],
            ),
          );
        },
        onReplyToComment: (commentId, replyText) {
          // Handle comment reply
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reply posted!', style: GoogleFonts.inter()),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[600],
            ),
          );
        },
        onAddComment: (commentText) {
          // Handle new comment
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment posted!', style: GoogleFonts.inter()),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[600],
            ),
          );
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
