import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/story_ring.dart' as story_widget;
import 'widgets/post_card.dart';
import 'widgets/badge_icon.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'connections_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart';
import 'profile_page.dart';
import 'post_page.dart';
import 'core/posts_api.dart';
import 'core/stories_api.dart' as stories_api;
import 'models/post.dart';
import 'models/comment.dart';
import 'theme_provider.dart';
import 'search_page.dart';
import 'notification_page.dart';
import 'story_viewer_page.dart';
import 'story_compose_pages.dart';
import 'widgets/tools_overlay.dart';
import 'widgets/my_stories_bottom_sheet.dart';
import 'podcasts/podcasts_home_page.dart';
import 'books/books_home_page.dart';
import 'mentorship/mentorship_home_page.dart';
import 'video_scroll_page.dart';
import 'core/token_store.dart';
import 'sign_in_page.dart';
import 'core/auth_api.dart';
import 'package:dio/dio.dart';
import 'core/notifications_api.dart';
import 'core/post_events.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  int _selectedNavIndex = 0;
  List<Post> _posts = [];
  List<stories_api.StoryRing> _storyRings = [];
  int _conversationsInitialTabIndex = 0; // 0: Chats, 1: Communities
  String? _currentUserId;

  // Unread notifications badge
  int _unreadCount = 0;

  // Live updates between feed and post page
  StreamSubscription<PostUpdateEvent>? _postEventsSub;

  @override
  void initState() {
    super.initState();
    _ensureAuth();
    () async {
      await _loadCurrentUserId();
      await _loadData();
      await _loadUnreadCount();
    }();

    // Subscribe to post update events to keep feed in sync with PostPage
    _postEventsSub = PostEvents.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _posts = _posts.map((p) {
          if (p.id == e.originalPostId || p.originalPostId == e.originalPostId) {
            return p.copyWith(
              counts: e.counts,
              userReaction: e.userReaction ?? p.userReaction,
              isBookmarked: e.isBookmarked ?? p.isBookmarked,
            );
          }
          return p;
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _postEventsSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureAuth() async {
    final t = await TokenStore.read();
    if (t == null || t.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        );
      }
    }
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

  Future<void> _loadUnreadCount() async {
    try {
      final c = await NotificationsApi().unreadCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = c;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
      });
    }
  }

  Future<void> _loadData() async {
    List<Post> posts = [];
    List<stories_api.StoryRing> rings = [];
    String? errMsg;

    try {
      posts = await PostsApi().listFeed(limit: 20, offset: 0);
      posts = await _hydrateReposts(posts);
    } catch (e) {
      errMsg = 'Posts failed: ${_toError(e)}';
    }

    try {
      rings = await stories_api.StoriesApi().getRings();
    } catch (e) {
      final s = 'Stories failed: ${_toError(e)}';
      errMsg = errMsg == null ? s : '$errMsg | $s';
    }

    // Ensure "Your Story" ring shows even if you have no active stories
    if (_currentUserId != null &&
        !rings.any((r) => r.userId == _currentUserId)) {
      rings = [
        stories_api.StoryRing(
          userId: _currentUserId!,
          name: '',
          username: '',
          hasUnseen: false,
          lastStoryAt: DateTime.now(),
          thumbnailUrl: null,
          storyCount: 0,
        ),
        ...rings,
      ];
    }

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _storyRings = rings;
    });

    if (errMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg, style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch original posts for repost items when the backend didn't hydrate them.
  Future<List<Post>> _hydrateReposts(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    final api = PostsApi();
    final result = List<Post>.from(posts);

    final futures = <Future<void>>[];
    for (int i = 0; i < result.length; i++) {
      final p = result[i];
      if (!p.isRepost) continue;
      final ogId = p.originalPostId;
      if (ogId == null || ogId.isEmpty) continue;

      futures.add(() async {
        final og = await api.getPost(ogId);
        if (og == null) return;
        final merged = p.copyWith(
          userName: og.userName,
          userAvatarUrl: og.userAvatarUrl,
          text: og.text,
          mediaType: og.mediaType,
          imageUrls: og.imageUrls,
          videoUrl: og.videoUrl,
          counts: og.counts,
        );
        result[i] = merged;
      }());
    }

    try {
      await Future.wait(futures);
    } catch (_) {
      // Ignore hydration errors
    }

    return result;
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
    void _onNavTabChange(int index) {
    setState(() {
      _selectedNavIndex = index;
      if (index != 3) {
        _conversationsInitialTabIndex = 0;
      }
    });

    if (index == 2) {
      () async {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );
        if (created == true) {
          await _loadData();
        }
      }();
    } else if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VideoScrollPage()),
      );
    }
  }

  // Helpers for updating all feed entries tied to the same original post
  List<int> _indexesForOriginal(String originalId) {
    final idxs = <int>[];
    for (int i = 0; i < _posts.length; i++) {
      final p = _posts[i];
      if (p.id == originalId || p.originalPostId == originalId) {
        idxs.add(i);
      }
    }
    return idxs;
  }

  Post? _baseForOriginal(String originalId) {
    final direct = _posts.where((p) => p.id == originalId).toList();
    if (direct.isNotEmpty) return direct.first;
    final viaRepost =
        _posts.where((p) => p.originalPostId == originalId).toList();
    if (viaRepost.isNotEmpty) return viaRepost.first;
    return null;
  }

  void _applyToOriginal(String originalId,
      {required PostCounts counts,
      ReactionType? userReaction,
      bool? isBookmarked}) {
    final idxs = _indexesForOriginal(originalId);
    for (final i in idxs) {
      final p = _posts[i];
      _posts[i] = p.copyWith(
        counts: counts,
        userReaction: userReaction ?? p.userReaction,
        isBookmarked: isBookmarked ?? p.isBookmarked,
      );
    }
  }

  void _onBookmarkToggle(String originalId) async {
    final base = _baseForOriginal(originalId);
    if (base == null) return;

    final willBookmark = !base.isBookmarked;
    final newBookmarks =
        (base.counts.bookmarks + (willBookmark ? 1 : -1)).clamp(0, 1 << 30);

    final updatedCounts = PostCounts(
      likes: base.counts.likes,
      comments: base.counts.comments,
      shares: base.counts.shares,
      reposts: base.counts.reposts,
      bookmarks: newBookmarks,
    );

    final prevPosts = List<Post>.from(_posts);
    setState(() {
      _applyToOriginal(originalId,
          counts: updatedCounts, isBookmarked: willBookmark);
    });

    try {
      if (willBookmark) {
        await PostsApi().bookmark(originalId);
      } else {
        await PostsApi().unbookmark(originalId);
      }
      // Emit for PostPage listeners
      PostEvents.emit(PostUpdateEvent(
        originalPostId: originalId,
        counts: updatedCounts,
        userReaction: base.userReaction,
        isBookmarked: willBookmark,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = prevPosts;
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

  void _onReactionChanged(String originalId, ReactionType reaction) async {
    final base = _baseForOriginal(originalId);
    if (base == null) return;

    final hadReaction = base.userReaction != null;
    final isSameReaction = base.userReaction == reaction;

    final prevPosts = List<Post>.from(_posts);

    if (!hadReaction) {
      final updatedCounts = PostCounts(
        likes: base.counts.likes + 1,
        comments: base.counts.comments,
        shares: base.counts.shares,
        reposts: base.counts.reposts,
        bookmarks: base.counts.bookmarks,
      );
      setState(() {
        _applyToOriginal(originalId,
            counts: updatedCounts, userReaction: reaction);
      });
      try {
        await PostsApi().like(originalId);
        PostEvents.emit(PostUpdateEvent(
          originalPostId: originalId,
          counts: updatedCounts,
          userReaction: reaction,
          isBookmarked: base.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _posts = prevPosts;
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

    if (isSameReaction) {
      final newLikes = (base.counts.likes > 0 ? base.counts.likes - 1 : 0);
      final updatedCounts = PostCounts(
        likes: newLikes,
        comments: base.counts.comments,
        shares: base.counts.shares,
        reposts: base.counts.reposts,
        bookmarks: base.counts.bookmarks,
      );

      setState(() {
        _applyToOriginal(originalId,
            counts: updatedCounts, userReaction: null);
      });

      try {
        await PostsApi().unlike(originalId);
        PostEvents.emit(PostUpdateEvent(
          originalPostId: originalId,
          counts: updatedCounts,
          userReaction: null,
          isBookmarked: base.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _posts = prevPosts;
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

    // Different reaction but still a "like" concept: update icon only (no extra like API)
    setState(() {
      _applyToOriginal(originalId,
          counts: base.counts, userReaction: reaction);
    });
  }

  void _onShare(String originalId) {
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

  Future<void> _openCommentsSheet(String originalId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Comment> comments = [];
    try {
      comments = await PostsApi().listComments(originalId);
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
      postId: originalId,
      comments: comments,
      currentUserId: _currentUserId ?? '',
      isDarkMode: isDark,
      onAddComment: (text) async {
        try {
          await PostsApi().addComment(originalId, content: text);

          final base = _baseForOriginal(originalId);
          if (base != null) {
            final updatedCounts = PostCounts(
              likes: base.counts.likes,
              comments: base.counts.comments + 1,
              shares: base.counts.shares,
              reposts: base.counts.reposts,
              bookmarks: base.counts.bookmarks,
            );
            setState(() {
              _applyToOriginal(originalId, counts: updatedCounts);
            });
            PostEvents.emit(PostUpdateEvent(
              originalPostId: originalId,
              counts: updatedCounts,
              userReaction: base.userReaction,
              isBookmarked: base.isBookmarked,
            ));
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
              content: Text('Post comment failed: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onReplyToComment: (commentId, replyText) async {
        try {
          await PostsApi()
              .addComment(originalId, content: replyText, parentCommentId: commentId);

          // Count reply as part of comments for the action row
          final base = _baseForOriginal(originalId);
          if (base != null) {
            final updatedCounts = PostCounts(
              likes: base.counts.likes,
              comments: base.counts.comments + 1,
              shares: base.counts.shares,
              reposts: base.counts.reposts,
              bookmarks: base.counts.bookmarks,
            );
            setState(() {
              _applyToOriginal(originalId, counts: updatedCounts);
            });
            PostEvents.emit(PostUpdateEvent(
              originalPostId: originalId,
              counts: updatedCounts,
              userReaction: base.userReaction,
              isBookmarked: base.isBookmarked,
            ));
          }

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
              content: Text('Reply failed: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _onComment(String originalId) => _openCommentsSheet(originalId);

  void _onRepost(String originalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Repost this?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to repost this?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Repost',
                style:
                    GoogleFonts.inter(color: const Color(0xFFBFAE01))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await PostsApi().repost(originalId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Post reposted successfully', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      await _loadData();
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
                child:
                    Text('Remove', style: GoogleFonts.inter(color: Colors.red)),
              ),
            ],
          ),
        );
        if (remove == true) {
          try {
            await PostsApi().unrepost(originalId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Repost removed', style: GoogleFonts.inter()),
                backgroundColor: const Color(0xFF9E9E9E),
              ),
            );
            await _loadData();
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
          content: Text('Repost failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onPostTap(String originalId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostPage(postId: originalId)),
    );
    // Refresh after returning from Post page
    await _loadData();
  }
    // Map story compose type to its page
  Widget _composerPage(StoryComposeType type) {
    switch (type) {
      case StoryComposeType.text:
        return const TextStoryComposerPage();
      case StoryComposeType.image:
      case StoryComposeType.video:
      case StoryComposeType.mixed:
        return const MixedMediaStoryComposerPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor =
            isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

        return Scaffold(
          backgroundColor: backgroundColor,
          body: _selectedNavIndex == 1
              ? ConnectionsPage(isDarkMode: isDark, onThemeToggle: () {})
              : _selectedNavIndex == 3
                  ? ConversationsPage(
                      isDarkMode: isDark,
                      onThemeToggle: () {},
                      initialTabIndex: _conversationsInitialTabIndex,
                    )
                  : _selectedNavIndex == 4
                      ? const ProfilePage()
                      : _selectedNavIndex == 5
                          ? const VideoScrollPage()
                          : _buildHomeFeed(context, isDark, backgroundColor),
          bottomNavigationBar: AnimatedNavbar(
            selectedIndex: _selectedNavIndex,
            onTabChange: _onNavTabChange,
            isDarkMode: isDark,
          ),
          floatingActionButton:
              (_selectedNavIndex == 0 || _selectedNavIndex == 1)
                  ? FloatingActionButton(
                      heroTag: 'toolsFabMain',
                      onPressed: () => ToolsOverlay.show(
                        context,
                        onCommunities: () {
                          setState(() {
                            _conversationsInitialTabIndex = 1;
                            _selectedNavIndex = 3;
                          });
                        },
                        onPodcasts: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PodcastsHomePage(),
                            ),
                          );
                        },
                        onBooks: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BooksHomePage(),
                            ),
                          );
                        },
                        onMentorship: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MentorshipHomePage(),
                            ),
                          );
                        },
                        onVideos: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VideoScrollPage(),
                            ),
                          );
                        },
                      ),
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.widgets_outlined),
                    )
                  : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildHomeFeed(
    BuildContext context,
    bool isDark,
    Color backgroundColor,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification) {
          // Hide reaction picker when scrolling starts
          ReactionPickerManager.hideReactions();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar + stories as a scrollable sliver
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(25),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row with search, title, and notifications
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchPage(),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.search,
                              color: Color(0xFF666666),
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'NEXUM',
                                style: GoogleFonts.inika(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          BadgeIcon(
                            icon: Icons.notifications_outlined,
                            badgeCount: _unreadCount,
                            iconColor: const Color(0xFF666666),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationPage(),
                                ),
                              );
                              await _loadUnreadCount();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stories row
                    SizedBox(
                      height: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _storyRings.length,
                          itemBuilder: (context, index) {
                            final ring = _storyRings[index];
                            final isMine = ring.userId == _currentUserId;

                            return Container(
                              width: 70,
                              margin: EdgeInsets.only(
                                right: index < _storyRings.length - 1 ? 16 : 0,
                              ),
                              child: story_widget.StoryRing(
                                imageUrl: ring.thumbnailUrl ?? ring.avatarUrl,
                                label: isMine
                                    ? 'Your Story'
                                    : (ring.name.isNotEmpty
                                        ? ring.name
                                        : (ring.username.startsWith('@')
                                            ? ring.username
                                            : '@${ring.username}')),
                                isMine: isMine,
                                isSeen: !ring.hasUnseen,

                                // Full ring AND plus icon follow the same conditions
                                onAddTap: isMine
                                    ? () {
                                        if (ring.storyCount > 0 &&
                                            _currentUserId != null) {
                                          MyStoriesBottomSheet.show(
                                            context,
                                            currentUserId: _currentUserId!,
                                            onAddStory: () {
                                              StoryTypePicker.show(
                                                context,
                                                onSelected: (type) async {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          _composerPage(type),
                                                    ),
                                                  );
                                                  await _loadData();
                                                },
                                              );
                                            },
                                          );
                                        } else {
                                          StoryTypePicker.show(
                                            context,
                                            onSelected: (type) async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      _composerPage(type),
                                                ),
                                              );
                                              await _loadData();
                                            },
                                          );
                                        }
                                      }
                                    : null,
                                onTap: () async {
                                  if (isMine) {
                                    if (ring.storyCount > 0 &&
                                        _currentUserId != null) {
                                      MyStoriesBottomSheet.show(
                                        context,
                                        currentUserId: _currentUserId!,
                                        onAddStory: () {
                                          StoryTypePicker.show(
                                            context,
                                            onSelected: (type) async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      _composerPage(type),
                                                ),
                                              );
                                              await _loadData();
                                            },
                                          );
                                        },
                                      );
                                    } else {
                                      StoryTypePicker.show(
                                        context,
                                        onSelected: (type) async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _composerPage(type),
                                            ),
                                          );
                                          await _loadData(); // refresh rings after composing
                                        },
                                      );
                                    }
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StoryViewerPage(
                                          rings: _storyRings
                                              .map((r) => {
                                                    'userId': r.userId,
                                                    'imageUrl': r.thumbnailUrl ??
                                                        r.avatarUrl,
                                                    'label': r.name,
                                                    'isMine': r.userId ==
                                                        _currentUserId,
                                                    'isSeen': !r.hasUnseen,
                                                  })
                                              .toList(),
                                          initialRingIndex: index,
                                        ),
                                      ),
                                    );
                                    await _loadData(); // refresh rings after viewing
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Feed as a sliver list so it scrolls together with the header
          SliverPadding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
              return PostCard(
                post: _posts[index],
                onReactionChanged: _onReactionChanged,
                onBookmarkToggle: _onBookmarkToggle,
                onTap: _onPostTap,
                onShare: _onShare,
                onComment: _onComment,
                onRepost: _onRepost,
                isDarkMode: isDark,
                currentUserId: _currentUserId,
              );
              }, childCount: _posts.length),
            ),
          ),
        ],
      ),
    );
  }
}