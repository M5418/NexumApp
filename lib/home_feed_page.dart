import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/story_ring.dart';
import 'widgets/post_card.dart';
import 'widgets/badge_icon.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/share_bottom_sheet.dart';
import 'connections_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart';
import 'profile_page.dart';
import 'post_page.dart';
import 'core/posts_api.dart';
import 'data/sample_data.dart';
import 'models/post.dart';
import 'theme_provider.dart';
import 'search_page.dart';
import 'notification_page.dart';
import 'story_viewer_page.dart';
import 'story_compose_pages.dart';
import 'widgets/tools_overlay.dart';
import 'podcasts/podcasts_home_page.dart';
import 'books/books_home_page.dart';
import 'mentorship/mentorship_home_page.dart';
import 'video_scroll_page.dart';
import 'core/token_store.dart';
import 'sign_in_page.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  int _selectedNavIndex = 0;
  List<Post> _posts = [];
  List<Map<String, dynamic>> _stories = [];
  int _conversationsInitialTabIndex = 0; // 0: Chats, 1: Communities

  @override
  void initState() {
    super.initState();
    _ensureAuth();
    _loadData();
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

  Future<void> _loadData() async {
    try {
      final posts = await PostsApi().listFeed(limit: 20, offset: 0);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        // Restore stories UI with sample data for now
        _stories = SampleData.getSampleStories();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = [];
        _stories = SampleData.getSampleStories();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load feed', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onNavTabChange(int index) {
    setState(() {
      _selectedNavIndex = index;
      if (index != 3) {
        _conversationsInitialTabIndex = 0; // reset when leaving Conversations
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

  void _onBookmarkToggle(String postId) {
    setState(() {
      final postIndex = _posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        final newPost = Post(
          id: post.id,
          userName: post.userName,
          userAvatarUrl: post.userAvatarUrl,
          createdAt: post.createdAt,
          text: post.text,
          mediaType: post.mediaType,
          imageUrls: post.imageUrls,
          videoUrl: post.videoUrl,
          counts: post.counts,
          userReaction: post.userReaction,
          isBookmarked: !post.isBookmarked,
          isRepost: post.isRepost,
          repostedBy: post.repostedBy,
        );
        _posts[postIndex] = newPost;
      }
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
            content: Text(
              'Link copied to clipboard',
              style: GoogleFonts.inter(),
            ),
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

  void _onComment(String postId) {
    // UI-only implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Comment functionality (UI only)',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xFFBFAE01),
      ),
    );
  }

  void _onRepost(String postId) {
    // UI-only implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Repost functionality (UI only)',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xFFBFAE01),
      ),
    );
  }

  void _onPostTap(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostPage(postId: postId)),
    );
  }

  // Map story compose type to its page (ensures non-null return)
  Widget _composerPage(StoryComposeType type) {
    switch (type) {
      case StoryComposeType.image:
      case StoryComposeType.video:
      case StoryComposeType.text:
      case StoryComposeType.mixed:
        return const MixedMediaStoryComposerPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor = isDark
            ? const Color(0xFF0C0C0C)
            : const Color(0xFFF1F4F8);

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
                      // Switch bottom nav to Conversations and preselect Communities tab
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
              height: 230,
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
                            badgeCount: 6,
                            iconColor: const Color(0xFF666666),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationPage(),
                                ),
                              );
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
                          itemCount: _stories.length,
                          itemBuilder: (context, index) {
                            final story = _stories[index];
                            return Container(
                              width: 70,
                              margin: EdgeInsets.only(
                                right: index < _stories.length - 1 ? 16 : 0,
                              ),
                              child: StoryRing(
                                imageUrl: story['imageUrl'] as String?,
                                label: story['label'] as String,
                                isMine: story['isMine'] as bool,
                                isSeen: story['isSeen'] as bool,
                                onAddTap: (story['isMine'] as bool? ?? false)
                                    ? () {
                                        StoryTypePicker.show(
                                          context,
                                          onSelected: (type) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    _composerPage(type),
                                              ),
                                            );
                                          },
                                        );
                                      }
                                    : null,
                                onTap: () {
                                  final isMine =
                                      story['isMine'] as bool? ?? false;
                                  if (isMine) {
                                    StoryTypePicker.show(
                                      context,
                                      onSelected: (type) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => _composerPage(type),
                                          ),
                                        );
                                      },
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StoryViewerPage(
                                          rings: _stories,
                                          initialRingIndex: index,
                                        ),
                                      ),
                                    );
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
                  onBookmarkToggle: _onBookmarkToggle,
                  onTap: _onPostTap,
                  onShare: _onShare,
                  onComment: _onComment,
                  onRepost: _onRepost,
                  isDarkMode: isDark,
                );
              }, childCount: _posts.length),
            ),
          ),
        ],
      ),
    );
  }
}
