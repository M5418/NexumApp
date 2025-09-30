import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';

import 'models/post.dart';
import 'core/community_posts_api.dart';
import 'core/communities_api.dart';
import 'community_post_page.dart';
import 'theme_provider.dart';
import 'widgets/post_card.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/segmented_tabs.dart';

class CommunityPage extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityPage({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Post> _posts = [];
  int _selectedTabIndex = 0;

  // Loading states
  bool _loadingPosts = false;
  bool _loadingDetails = false;

  // Community details
  ApiCommunity? _community;

  // Media items aggregated from posts
  final List<_CommunityMediaItem> _mediaItems = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadDetails(),
      _loadPostsAndBuildMedia(),
    ]);
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loadingDetails = true;
    });
    try {
      final c = await CommunitiesApi().details(widget.communityId);
      if (!mounted) return;
      setState(() {
        _community = c;
      });
    } catch (e) {
      if (!mounted) return;
      // Non-blocking; show a toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load community details: ${_toError(e)}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetails = false;
        });
      }
    }
  }

  Future<void> _loadPostsAndBuildMedia() async {
    setState(() {
      _loadingPosts = true;
    });

    try {
      final list = await CommunityPostsApi()
          .list(widget.communityId, limit: 100, offset: 0);
      if (!mounted) return;
      setState(() {
        _posts = list;
      });

      // Build media list: all images and videos (exclude repost rows to avoid duplicates)
      _mediaItems
        .clear();
      for (final p in list) {
        if (p.isRepost) continue; // exclude repost media to avoid duplicates
        if (p.mediaType == MediaType.video && p.videoUrl != null) {
          _mediaItems.add(_CommunityMediaItem(
            postId: p.id,
            url: p.videoUrl!,
            isVideo: true,
          ));
        } else if (p.mediaType == MediaType.image && p.imageUrls.isNotEmpty) {
          _mediaItems.add(_CommunityMediaItem(
            postId: p.id,
            url: p.imageUrls.first,
            isVideo: false,
          ));
        } else if (p.mediaType == MediaType.images && p.imageUrls.isNotEmpty) {
          for (final u in p.imageUrls) {
            _mediaItems.add(_CommunityMediaItem(
              postId: p.id,
              url: u,
              isVideo: false,
            ));
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load community posts: ${_toError(e)}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingPosts = false;
      });
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

  // Toggle bookmark for a post (optimistic UI + backend)
  void _onBookmarkToggle(String postId) async {
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) return;

    final original = _posts[postIndex];
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

    final optimistic = original.copyWith(
      isBookmarked: willBookmark,
      counts: updatedCounts,
    );

    setState(() {
      _posts[postIndex] = optimistic;
    });

    try {
      if (willBookmark) {
        await CommunityPostsApi().bookmark(widget.communityId, postId);
      } else {
        await CommunityPostsApi().unbookmark(widget.communityId, postId);
      }
    } catch (e) {
      if (!mounted) return;
      // Revert UI on failure
      setState(() {
        _posts[postIndex] = original;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bookmark failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Likes: toggle on/off; long-press changes reaction type locally
  void _onReactionChanged(String postId, ReactionType reaction) async {
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) return;

    final original = _posts[postIndex];
    final hadReaction = original.userReaction != null;
    final isSameReaction = original.userReaction == reaction;

    // Toggle ON: no previous reaction
    if (!hadReaction) {
      final updatedCounts = PostCounts(
        likes: original.counts.likes + 1,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );

      final optimistic = original.copyWith(
        userReaction: reaction,
        counts: updatedCounts,
      );

      setState(() {
        _posts[postIndex] = optimistic;
      });

      try {
        await CommunityPostsApi().like(widget.communityId, postId);
      } catch (e) {
        if (!mounted) return;
        // Revert UI on failure
        setState(() {
          _posts[postIndex] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Like failed: ${_toError(e)}',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Toggle OFF: same reaction tapped again
    if (isSameReaction) {
      final newLikes = (original.counts.likes > 0
          ? original.counts.likes - 1
          : 0);
      final updatedCounts = PostCounts(
        likes: newLikes,
        comments: original.counts.comments,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );

      // Build a new Post to null-out userReaction
      final optimistic = Post(
        id: original.id,
        userName: original.userName,
        userAvatarUrl: original.userAvatarUrl,
        createdAt: original.createdAt,
        text: original.text,
        mediaType: original.mediaType,
        imageUrls: original.imageUrls,
        videoUrl: original.videoUrl,
        counts: updatedCounts,
        userReaction: null,
        isBookmarked: original.isBookmarked,
        isRepost: original.isRepost,
        repostedBy: original.repostedBy,
        originalPostId: original.originalPostId,
      );

      setState(() {
        _posts[postIndex] = optimistic;
      });

      try {
        await CommunityPostsApi().unlike(widget.communityId, postId);
      } catch (e) {
        if (!mounted) return;
        // Revert UI on failure
        setState(() {
          _posts[postIndex] = original;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlike failed: ${_toError(e)}',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Change reaction type (still liked): UI-only; no backend call needed
    setState(() {
      _posts[postIndex] = original.copyWith(userReaction: reaction);
    });
  }

  void _onShare(String postId) {
    ShareBottomSheet.show(
      context,
      onStories: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Stories', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
      onCopyLink: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link copied to clipboard', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF9E9E9E),
          ),
        );
      },
      onTelegram: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Telegram', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF0088CC),
          ),
        );
      },
      onFacebook: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Facebook', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      },
      onMore: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('More share options', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      onSendToUsers: (selectedUsers, message) {
        final userNames = selectedUsers.map((u) => u.name).join(', ');
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

  // Navigate to full community post page for comments and details
  void _onComment(String postId) {
    _onPostTap(postId);
  }

  Future<void> _onRepost(String postId) async {
    // Confirm repost action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text('Repost this?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content:
            Text('Are you sure you want to repost this?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Repost',
                style: GoogleFonts.inter(color: const Color(0xFFBFAE01))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CommunityPostsApi().repost(widget.communityId, postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Post reposted successfully', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      await _loadPostsAndBuildMedia(); // refresh feed and media
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      final msg = _toError(e);

      final isAlreadyReposted = code == 409 ||
          (data is Map &&
              ((data['error'] ?? data['message'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('already')));

      if (isAlreadyReposted) {
        final remove = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove repost?',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            content: Text('You already reposted this. Remove your repost?',
                style: GoogleFonts.inter()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Remove',
                    style: GoogleFonts.inter(color: Colors.red)),
              ),
            ],
          ),
        );

        if (remove == true) {
          try {
            await CommunityPostsApi().unrepost(widget.communityId, postId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Repost removed', style: GoogleFonts.inter()),
                backgroundColor: const Color(0xFF9E9E9E),
              ),
            );
            await _loadPostsAndBuildMedia();
          } catch (e2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to remove repost: ${_toError(e2)}',
                    style: GoogleFonts.inter()),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repost failed: $msg', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Repost failed: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onPostTap(String postId) {
    final p = _posts.firstWhere(
      (e) => e.id == postId,
      orElse: () => _posts.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityPostPage(
          communityId: widget.communityId,
          post: p, // pass full post for instant render
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor =
            isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
        final appBarBg = isDark ? Colors.black : Colors.white;
        final appBarFg = isDark ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: appBarBg,
            foregroundColor: appBarFg,
            elevation: 0,
            centerTitle: true,
            title: Text(
              _community?.name ?? widget.communityName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: appBarFg,
              ),
            ),
          ),
          body: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollStartNotification) {
                // Hide reaction picker when scrolling starts
                ReactionPickerManager.hideReactions();
              }
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              children: [
                _buildCommunityHeader(isDark),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedTabs(
                    tabs: const ['Post', 'About', 'Media'],
                    selectedIndex: _selectedTabIndex,
                    onTabSelected: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 650,
                  child: _selectedTabIndex == 0
                      ? (_loadingPosts
                          ? const Center(child: CircularProgressIndicator())
                          : (_posts.isEmpty
                              ? Center(
                                  child: Text(
                                    'No posts yet',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemCount: _posts.length,
                                  itemBuilder: (context, index) {
                                    final p = _posts[index];
                                    return PostCard(
                                      post: p,
                                      onReactionChanged: _onReactionChanged,
                                      onBookmarkToggle: _onBookmarkToggle,
                                      onTap: (id) => _onPostTap(id),
                                      onShare: _onShare,
                                      onComment: _onComment,
                                      onRepost: _onRepost,
                                      isDarkMode: isDark,
                                    );
                                  },
                                )))
                      : _selectedTabIndex == 1
                          ? SingleChildScrollView(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black
                                                .withValues(alpha: 0)
                                            : Colors.black
                                                .withValues(alpha: 13),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'About this Community',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_loadingDetails)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: LinearProgressIndicator(),
                                        ),
                                      Text(
                                        _community?.bio.isNotEmpty == true
                                            ? _community!.bio
                                            : 'A vibrant community.',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _chipStat(
                                            icon: Icons.article_outlined,
                                            label:
                                                '${_community?.postsCount ?? _posts.length} Posts',
                                            isDark: isDark,
                                          ),
                                          _chipStat(
                                            icon: Icons.people_outline,
                                            label:
                                                '${_community?.memberCount ?? 0} Members',
                                            isDark: isDark,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black
                                                .withValues(alpha: 0)
                                            : Colors.black
                                                .withValues(alpha: 13),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _loadingPosts
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            mainAxisSpacing: 8,
                                            crossAxisSpacing: 8,
                                            childAspectRatio: 1.0,
                                          ),
                                          itemCount: _mediaItems.length,
                                          itemBuilder: (context, index) {
                                            final item = _mediaItems[index];
                                            return GestureDetector(
                                              onTap: () => _onPostTap(item.postId),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    if (!item.isVideo)
                                                      CachedNetworkImage(
                                                        imageUrl: item.url,
                                                        fit: BoxFit.cover,
                                                        placeholder: (c, _) =>
                                                            Container(
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF121212)
                                                              : const Color(
                                                                  0xFFEFEFEF),
                                                        ),
                                                        errorWidget:
                                                            (c, _, __) =>
                                                                Container(
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF121212)
                                                              : const Color(
                                                                  0xFFEFEFEF),
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF121212)
                                                            : const Color(
                                                                0xFFEFEFEF),
                                                        child: Center(
                                                          child: Icon(
                                                            Icons
                                                                .play_circle_fill,
                                                          size: 48,
                                                            color: Colors
                                                                .white70,
                                                          ),
                                                        ),
                                                      ),
                                                    if (item.isVideo)
                                                      Positioned(
                                                        bottom: 6,
                                                        right: 6,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .black54,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .videocam_outlined,
                                                                color: Colors
                                                                    .white,
                                                                size: 14,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                'Video',
                                                                style: GoogleFonts
                                                                    .inter(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .white,
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
                                          },
                                        ),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipStat({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF666666).withValues(alpha: 26),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityHeader(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    const secondaryTextColor = Color(0xFF666666);

    final displayName = _community?.name ?? widget.communityName;
    final handle = displayName.toLowerCase().replaceAll(
      RegExp(r"[^a-z0-9]"),
      '',
    );

    final coverUrl = _community?.coverUrl;
    final avatarUrl = _community?.avatarUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isDark ? Colors.black.withValues(alpha: 0) : Colors.black.withValues(alpha: 13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle at top center
          Center(
            child: Text(
              handle,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Cover with avatar + stats chips
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                          ),
                        ),
                        errorWidget: (context, url, error) => SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                          ),
                        ),
                      )
                    : Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
              ),
              Positioned(
                left: 16,
                bottom: 12,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 104,
                            height: 104,
                            color: isDark ? const Color(0xFF222222) : const Color(0xFFDDDDDD),
                            child: Center(
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                                style: GoogleFonts.inter(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // Stats chips
              Positioned(
                right: 12,
                bottom: 12,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _chipStat(
                      icon: Icons.article_outlined,
                      label: '${_community?.postsCount ?? _posts.length} Posts',
                      isDark: isDark,
                    ),
                    _chipStat(
                      icon: Icons.people_outline,
                      label: '${_community?.memberCount ?? 0} Members',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            displayName,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          if (_community?.bio.isNotEmpty == true)
            Text(
              _community!.bio,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF666666),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _CommunityMediaItem {
  final String postId;
  final String url;
  final bool isVideo;

  _CommunityMediaItem({
    required this.postId,
    required this.url,
    required this.isVideo,
  });
}