import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'data/sample_data.dart';
import 'models/post.dart';
import 'post_page.dart';
import 'theme_provider.dart';
import 'widgets/post_card.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/segmented_tabs.dart';

class CommunityPage extends StatefulWidget {
  final String communityName;

  const CommunityPage({super.key, required this.communityName});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Post> _posts = [];
  int _selectedTabIndex = 0;

  // Sample media albums for the Media tab
  final List<Map<String, String>> _mediaAlbums = [
    {
      'title': 'Green Moments',
      'year': '2024',
      'imageUrl':
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=600&h=400&fit=crop',
    },
    {
      'title': 'Joyful Faces',
      'year': '2024',
      'imageUrl':
          'https://images.unsplash.com/photo-1511988617509-a57c8a288659?w=600&h=400&fit=crop',
    },
    {
      'title': 'Community Day',
      'year': '2023',
      'imageUrl':
          'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=600&h=400&fit=crop',
    },
    {
      'title': 'Project Smile',
      'year': '2023',
      'imageUrl':
          'https://images.unsplash.com/photo-1529665253569-6d01c0eaf7b6?w=600&h=400&fit=crop',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      // Reuse the same sample posts to ensure identical look to Home feed
      _posts = SampleData.getSamplePosts();
    });
  }

  void _onBookmarkToggle(String postId) {
    setState(() {
      final postIndex = _posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        final updated = Post(
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
        _posts[postIndex] = updated;
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

  void _onComment(String postId) {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor = isDark
            ? const Color(0xFF0C0C0C)
            : const Color(0xFFF1F4F8);
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
              widget.communityName,
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
                // Tab content area should not exceed 650px height
                SizedBox(
                  height: 650,
                  child: _selectedTabIndex == 0
                      ? ListView.builder(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final p = _posts[index];
                            return PostCard(
                              post: p,
                              onBookmarkToggle: _onBookmarkToggle,
                              onTap: _onPostTap,
                              onShare: _onShare,
                              onComment: _onComment,
                              onRepost: _onRepost,
                              isDarkMode: isDark,
                            );
                          },
                        )
                      : _selectedTabIndex == 1
                      ? SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0)
                                        : Colors.black.withValues(alpha: 13),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  Text(
                                    'People of Purpose is a community of changemakers, dreamers, and doers—united by passion and driven by impact. We uplift, serve, and grow together, creating meaningful change in our lives, our communities, and the world around us.\n\nFound at the heart of the community since 2015.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0)
                                        : Colors.black.withValues(alpha: 13),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 1.2,
                                    ),
                                itemCount: _mediaAlbums.length,
                                itemBuilder: (context, index) {
                                  final album = _mediaAlbums[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark
                                              ? Colors.black.withValues(
                                                  alpha: 0,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 13,
                                                ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: const Color(
                                          0xFF666666,
                                        ).withValues(alpha: 26),
                                        width: 0.6,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: CachedNetworkImage(
                                            imageUrl: album['imageUrl'] ?? '',
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (context, url) => SizedBox(
                                              height: 160,
                                              width: double.infinity,
                                              child: Image.network(
                                                'https://picsum.photos/1200/400?random=42',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => SizedBox(
                                                  height: 160,
                                                  width: double.infinity,
                                                  child: Image.network(
                                                    'https://picsum.photos/1200/400?random=42',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  album['title'] ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '• ${album['year'] ?? ''}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(
                                                    0xFF666666,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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

  Widget _buildCommunityHeader(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    const secondaryTextColor = Color(0xFF666666);

    final handle = widget.communityName.toLowerCase().replaceAll(
      RegExp(r"[^a-z0-9]"),
      '',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0)
                : Colors.black.withValues(alpha: 13),
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

          // Cover with avatar + Joined chip
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: CachedNetworkImage(
                  imageUrl:
                      'https://images.unsplash.com/photo-1520974735194-6c0a1a1a6bb3?w=1400&h=500&fit=crop',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.network(
                      'https://picsum.photos/1200/400?random=42',
                      fit: BoxFit.cover,
                    ),
                  ),
                  errorWidget: (context, url, error) => SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.network(
                      'https://picsum.photos/1200/400?random=42',
                      fit: BoxFit.cover,
                    ),
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
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop',
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0C0C0C),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Joined',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('298.2k', 'Contributor', isDark),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: secondaryTextColor.withValues(alpha: 51),
              ),
              _buildStatItem('1,920', 'Post', isDark),
            ],
          ),

          const SizedBox(height: 12),

          // Community title & tagline
          Text(
            widget.communityName,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Building dreams, learning daily, growing with purpose ✨',
            style: GoogleFonts.inter(fontSize: 14, color: secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}
