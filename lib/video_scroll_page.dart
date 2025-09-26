import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import 'models/post.dart';
import 'models/comment.dart';
import 'core/posts_api.dart';
import 'core/auth_api.dart';
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

  final Map<String, bool> _expandedTexts = {};
  final Map<String, CustomVideoPlayer> _videoPlayers = {};
  final Map<String, GlobalKey<CustomVideoPlayerState>> _videoPlayerKeys = {};

  List<Post> _videoPosts = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadCurrentUserId();
    _loadVideoPosts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoPlayers.clear();
    _videoPlayerKeys.clear();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final res = await AuthApi().me();
      final id = (res['ok'] == true && res['data'] != null)
          ? res['data']['id'] as String?
          : null;
      if (!mounted) return;
      setState(() {
        _currentUserId = id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
      });
    }
  }

  Future<void> _loadVideoPosts() async {
    try {
      // Fetch feed and keep only video posts
      final posts = await PostsApi().listFeed(limit: 50, offset: 0);
      final onlyVideos =
          posts.where((p) => p.mediaType == MediaType.video).toList();
      if (!mounted) return;
      setState(() {
        _videoPosts = onlyVideos;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_toError(e), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _toError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final reason = (data['error'] ?? data['message'] ?? data).toString();
        return 'HTTP ${code ?? 'error'}: $reason';
      }
      return 'HTTP ${code ?? 'error'}';
    }
    return e.toString();
  }

  int _findPostIndex(String postId) =>
      _videoPosts.indexWhere((post) => post.id == postId);

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

  void _onReactionSelected(ReactionType reaction) async {
    final postIndex = _videoPosts.indexWhere(
      (post) => post.id == _reactionPickerPostId,
    );
    if (postIndex == -1) {
      _hideReactions();
      return;
    }

    final original = _videoPosts[postIndex];
    final hadReaction = original.userReaction != null;
    final isSameReaction = original.userReaction == reaction;

    // Toggle ON when no previous reaction
    if (!hadReaction) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes + 1,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic =
          original.copyWith(userReaction: reaction, counts: updatedCounts);
      setState(() {
        _videoPosts[postIndex] = optimistic;
      });
      try {
        await PostsApi().like(original.id);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[postIndex] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Like failed: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      _hideReactions();
      return;
    }

    // Toggle OFF when same reaction
    if (isSameReaction) {
      final newLikes =
          original.counts.likes > 0 ? original.counts.likes - 1 : 0;
      final updatedCounts = PostCounts(
        likes: newLikes,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic = original.copyWith(userReaction: null, counts: updatedCounts);
      setState(() {
        _videoPosts[postIndex] = optimistic;
      });
      try {
        await PostsApi().unlike(original.id);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[postIndex] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Unlike failed: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      _hideReactions();
      return;
    }

    // Change reaction type (still liked): UI-only
    setState(() {
      _videoPosts[postIndex] = original.copyWith(userReaction: reaction);
    });
    _hideReactions();
  }

  Future<void> _handleLikeFromPlayer(Post post) async {
    final idx = _findPostIndex(post.id);
    if (idx == -1) return;
    final original = _videoPosts[idx];

    // If not liked yet: optimistic + API
    if (original.userReaction == null) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes + 1,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic =
          original.copyWith(userReaction: ReactionType.heart, counts: updatedCounts);
      setState(() {
        _videoPosts[idx] = optimistic;
      });
      try {
        await PostsApi().like(post.id);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[idx] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Like failed: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // If already liked with a different reaction: only switch locally
    if (original.userReaction != ReactionType.heart) {
      setState(() {
        _videoPosts[idx] = original.copyWith(userReaction: ReactionType.heart);
      });
    }
  }

  Future<void> _handleUnlikeFromPlayer(Post post) async {
    final idx = _findPostIndex(post.id);
    if (idx == -1) return;
    final original = _videoPosts[idx];

    // Only handle unlike when current reaction is heart (what the player toggles)
    if (original.userReaction == ReactionType.heart) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes > 0 ? original.counts.likes - 1 : 0,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      final optimistic = original.copyWith(userReaction: null, counts: updatedCounts);
      setState(() {
        _videoPosts[idx] = optimistic;
      });
      try {
        await PostsApi().unlike(post.id);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _videoPosts[idx] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Unlike failed: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBookmark(String postId) async {
    final idx = _findPostIndex(postId);
    if (idx == -1) return;

    final original = _videoPosts[idx];
    final willBookmark = !original.isBookmarked;
    final newBookmarks =
        (original.counts.bookmarks + (willBookmark ? 1 : -1)).clamp(0, 1 << 30);

    final updatedCounts = PostCounts(
      likes: original.counts.likes,
      comments: original.counts.comments,
      shares: original.counts.shares,
      reposts: original.counts.reposts,
      bookmarks: newBookmarks,
    );

    final optimistic =
        original.copyWith(isBookmarked: willBookmark, counts: updatedCounts);

    setState(() {
      _videoPosts[idx] = optimistic;
    });

    try {
      if (willBookmark) {
        await PostsApi().bookmark(postId);
      } else {
        await PostsApi().unbookmark(postId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoPosts[idx] = original;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bookmark failed: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
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
          // Handle double-tap like from player
          _handleLikeFromPlayer(post);
        },
        onUnlike: () {
          // Handle double-tap unlike from player
          _handleUnlikeFromPlayer(post);
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // optional search for videos
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
                              currentReaction: _videoPosts
                                  .firstWhere(
                                    (p) => p.id == _reactionPickerPostId,
                                    orElse: () => _videoPosts.first,
                                  )
                                  .userReaction,
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
                  icon: post.userReaction == null
                      ? Icons.favorite_border
                      : Icons.favorite,
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
                  onTap: () {
                    _showComments(context, post.id);
                  },
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[600],
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
                  icon: post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
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

  Future<void> _showComments(BuildContext context, String postId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Comment> comments = [];
    try {
      comments = await PostsApi().listComments(postId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Load comments failed: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;

    CommentBottomSheet.show(
      context,
      postId: postId,
      comments: comments,
      currentUserId: _currentUserId ?? '',
      isDarkMode: isDark,
      onAddComment: (text) async {
        try {
          await PostsApi().addComment(postId, content: text);

          // Optimistically increment comments count on the post
          final idx = _findPostIndex(postId);
          if (idx != -1) {
            final p = _videoPosts[idx];
            final updatedCounts = PostCounts(
              likes: p.counts.likes,
              comments: p.counts.comments + 1,
              shares: p.counts.shares,
              reposts: p.counts.reposts,
              bookmarks: p.counts.bookmarks,
            );
            setState(() {
              _videoPosts[idx] = p.copyWith(counts: updatedCounts);
            });
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment posted!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Post comment failed: ${_toError(e)}', style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onReplyToComment: (commentId, replyText) async {
        try {
          await PostsApi()
              .addComment(postId, content: replyText, parentCommentId: commentId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reply posted!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Reply failed: ${_toError(e)}', style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
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