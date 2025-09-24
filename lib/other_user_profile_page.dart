import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'widgets/home_post_card.dart';
import 'widgets/activity_post_card.dart';
import 'widgets/message_invite_card.dart';
import 'models/post.dart';
import 'theme_provider.dart';
import 'core/connections_api.dart';
import 'core/conversations_api.dart';
import 'chat_page.dart';
import 'models/message.dart' hide MediaType;

class OtherUserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String userBio;
  final String userCoverUrl;
  final bool isConnected;
  final bool theyConnectToYou;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.userBio,
    this.userCoverUrl = '',
    this.isConnected = false,
    this.theyConnectToYou = false,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late bool _isConnected;
  final ConversationsApi _conversationsApi = ConversationsApi();

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.isDarkMode;
          return Scaffold(
            key: scaffoldKey,
            backgroundColor:
                isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
            endDrawer: _buildDrawer(isDark),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header with Cover Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: (widget.userCoverUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(widget.userCoverUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: widget.userCoverUrl.isEmpty
                          ? (isDark ? Colors.black : Colors.grey[300])
                          : null,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  scaffoldKey.currentState!.openEndDrawer(),
                              child: const Icon(
                                Icons.more_horiz,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main Profile Card
                  Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF000000) : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0)
                              : Colors.black.withValues(alpha: 13),
                          blurRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile Avatar and Stats
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar positioned to overlap cover
                              Transform.translate(
                                offset: const Offset(0, -50),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF000000)
                                          : Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 58,
                                    backgroundImage: NetworkImage(
                                      widget.userAvatarUrl,
                                    ),
                                  ),
                                ),
                              ),

                              // Stats Row
                              Transform.translate(
                                offset: const Offset(0, -30),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatColumn('2,8K', 'Connections'),
                                    const SizedBox(width: 40),
                                    _buildStatColumn('892', 'Connected'),
                                  ],
                                ),
                              ),

                              // Name and Bio
                              Transform.translate(
                                offset: const Offset(0, -20),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          widget.userName,
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.verified,
                                          color: Color(0xFFBFAE01),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.userBio,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Action Buttons
                              Transform.translate(
                                offset: const Offset(0, -10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final ctx = context;
                                          final api = ConnectionsApi();
                                          final next = !_isConnected;
                                          setState(() {
                                            _isConnected = next;
                                          });
                                          try {
                                            if (next) {
                                              await api.connect(widget.userId);
                                            } else {
                                              await api.disconnect(
                                                widget.userId,
                                              );
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              setState(() {
                                                _isConnected = !next;
                                              });
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to ${next ? 'connect' : 'disconnect'}',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isConnected
                                              ? Colors.grey[300]
                                              : const Color(0xFFBFAE01),
                                          foregroundColor: _isConnected
                                              ? Colors.black87
                                              : Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _isConnected
                                              ? 'Disconnect'
                                              : (widget.theyConnectToYou
                                                  ? 'Connect Back'
                                                  : 'Connect'),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _handleMessageUser,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF000000)
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          'Message',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF000000)
                                              : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                      child: const Icon(
                                        Icons.person_add_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Professional Experiences Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.work,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Professional Experiences',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Doctor In Physiopine',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Coach Football',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Trainings Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Trainings',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'University of Pens',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Professor',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Interest Section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Interest',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildInterestChip('Aerospace'),
                                  _buildInterestChip('Engineering'),
                                  _buildInterestChip('Environment'),
                                  _buildInterestChip('Technology'),
                                  _buildInterestChip('Health & Wellness'),
                                  _buildInterestChip('Sports'),
                                  _buildInterestChip('Photography'),
                                  _buildInterestChip('Travel'),
                                  _buildInterestChip('Music'),
                                  _buildInterestChip('Cooking'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab Section
                  _buildTabSection(isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleMessageUser() async {
    final ctx = context;
    try {
      // Check if conversation already exists
      final conversationId = await _conversationsApi.checkConversationExists(
        widget.userId,
      );

      if (!ctx.mounted) return;

      if (conversationId != null) {
        // Conversation exists - navigate to chat
        final chatUser = ChatUser(
          id: widget.userId,
          name: widget.userName,
          avatarUrl: widget.userAvatarUrl,
        );

        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              otherUser: chatUser,
              isDarkMode: false,
              conversationId: conversationId,
            ),
          ),
        );
      } else {
        // No conversation - show invite bottom sheet
        if (ctx.mounted) {
          _showMessageBottomSheet(ctx);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling message user: $e');
      // Fallback to invite sheet on error
      if (ctx.mounted) {
        _showMessageBottomSheet(ctx);
      }
    }
  }

  void _showMessageBottomSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: MessageInviteCard(
          receiverId: widget.userId,
          fullName: widget.userName,
          bio: widget.userBio,
          avatarUrl: widget.userAvatarUrl,
          coverUrl: widget.userCoverUrl,
          onClose: () => Navigator.pop(ctx),
          onInvitationSent: (invitation) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Invitation sent to ${widget.userName}')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.report,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
              title: Text(
                'Report User',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // Add report functionality here
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
              title: Text(
                'Block User',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // Add block functionality here
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildInterestChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTabSection(bool isDark) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.black,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.grey[300] : Colors.white,
              unselectedLabelColor:
                  isDark ? const Color(0xFF666666) : const Color(0xFF666666),
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: 'Activity'),
                Tab(text: 'Posts'),
                Tab(text: 'Podcasts'),
                Tab(text: 'Media'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 650,
            child: TabBarView(
              children: [
                _buildActivityTab(isDark),
                _buildPostsTab(isDark),
                _buildPodcastsTab(isDark),
                _buildMediaTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(bool isDark) {
    final activities = [
      Post(
        id: '1',
        userName: 'Wellness Weekly',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            '5 Simple habits that changed my life completely. Small changes, big impact! 🌟',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 156,
          comments: 34,
          shares: 22,
          reposts: 0,
          bookmarks: 67,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          actionType: 'reposted this',
        ),
      ),
      Post(
        id: '2',
        userName: 'Mindful Living',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face',
        text:
            'Morning meditation changed everything for me. Starting each day with intention 🧘‍♀️',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 89,
          comments: 12,
          shares: 8,
          reposts: 0,
          bookmarks: 23,
        ),
        userReaction: ReactionType.like,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          actionType: 'liked this',
        ),
      ),
      Post(
        id: '3',
        userName: 'Fitness Journey',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
        text:
            'Consistency beats perfection every single time. Keep showing up! 💪',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 234,
          comments: 45,
          shares: 18,
          reposts: 0,
          bookmarks: 89,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          actionType: 'commented on this',
        ),
      ),
      Post(
        id: '4',
        userName: 'Healthy Habits',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face',
        text:
            'The power of small daily actions. Transform your life one habit at a time ✨',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 167,
          comments: 28,
          shares: 31,
          reposts: 0,
          bookmarks: 54,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          actionType: 'shared this',
        ),
      ),
      Post(
        id: '5',
        userName: 'Nature Therapy',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face',
        text: 'Spending time in nature is the best medicine for the soul 🌿',
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 198,
          comments: 67,
          shares: 25,
          reposts: 0,
          bookmarks: 78,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          actionType: 'was tagged in this',
        ),
      ),
      Post(
        id: '6',
        userName: 'Tech Innovation',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'The future of AI is here! Exciting times ahead for technology enthusiasts 🚀',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 312,
          comments: 89,
          shares: 45,
          reposts: 0,
          bookmarks: 156,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: widget.userName,
          userAvatarUrl: widget.userAvatarUrl,
          actionType: 'reposted this',
        ),
      ),
    ];

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return ActivityPostCard(
          post: activities[index],
          onReactionChanged: (postId, reaction) {
            // Handle reaction change
          },
          onBookmarkToggle: (postId) {
            // Handle bookmark toggle
          },
          onShare: (postId) {
            // Handle share
          },
          onComment: (postId) {
            // Handle comment
          },
          onRepost: (postId) {
            // Handle repost
          },
        );
      },
    );
  }

  Widget _buildPostsTab(bool isDark) {
    final posts = [
      Post(
        id: '6',
        userName: widget.userName,
        userAvatarUrl: widget.userAvatarUrl,
        text: 'Beautiful morning meditation session! 🧘‍♀️ #mindfulness',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 89,
          comments: 12,
          shares: 5,
          reposts: 0,
          bookmarks: 23,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
        repostedBy: null,
      ),
    ];

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return HomePostCard(
          post: posts[index],
          onReactionChanged: (postId, reaction) {
            // Handle reaction change
          },
          onBookmarkToggle: (postId) {
            // Handle bookmark toggle
          },
          onShare: (postId) {
            // Handle share
          },
          onComment: (postId) {
            // Handle comment
          },
          onRepost: (postId) {
            // Handle repost
          },
        );
      },
    );
  }

  Widget _buildPodcastsTab(bool isDark) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        _buildPodcastItem(
          'Wellness Wednesday',
          'Episode 12: Finding Balance in Busy Life',
          '45 min',
          'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=300&h=300&fit=crop',
          isDark,
        ),
        _buildPodcastItem(
          'Mindful Moments',
          'Episode 8: The Power of Gratitude',
          '32 min',
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=300&fit=crop',
          isDark,
        ),
      ],
    );
  }

  Widget _buildPodcastItem(
    String title,
    String episode,
    String duration,
    String imageUrl,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF000000)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill, size: 32),
        ],
      ),
    );
  }

  Widget _buildMediaTab(bool isDark) {
    final mediaItems = [
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=300&h=300&fit=crop',
    ];

    return GridView.count(
      primary: false,
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: mediaItems.map((imageUrl) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(imageUrl, fit: BoxFit.cover),
        );
      }).toList(),
    );
  }
}
