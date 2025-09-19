import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/segmented_tabs.dart';
import 'widgets/new_chat_bottom_sheet.dart';
import 'chat_page.dart';
import 'models/message.dart';
import 'community_page.dart';
import 'invitation_page.dart';

class ConversationsPage extends StatefulWidget {
  final bool? isDarkMode;
  final VoidCallback? onThemeToggle;
  final int initialTabIndex;

  const ConversationsPage({
    super.key,
    this.isDarkMode,
    this.onThemeToggle,
    this.initialTabIndex = 0,
  });

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  final List<ChatItem> _chats = [
    ChatItem(
      id: '1',
      name: 'Thea Palmer',
      avatarUrl: 'https://picsum.photos/200/200?random=1',
      lastType: MessageType.text,
      lastText: 'This weather is crazy! 🌧️',
      lastTime: '12:07',
      unreadCount: 3,
    ),
    ChatItem(
      id: '2',
      name: 'Valerie Azer',
      avatarUrl: 'https://picsum.photos/200/200?random=2',
      lastType: MessageType.video,
      lastText: 'New episode dropped!',
      lastTime: '12:07',
      unreadCount: 1,
    ),
    ChatItem(
      id: '3',
      name: 'Nova Reeves',
      avatarUrl: 'https://picsum.photos/200/200?random=3',
      lastType: MessageType.images,
      lastText: null,
      lastTime: '12:07',
      unreadCount: 1,
    ),
    ChatItem(
      id: '4',
      name: 'Luca Holland',
      avatarUrl: 'https://picsum.photos/200/200?random=4',
      lastType: MessageType.video,
      lastText: null,
      lastTime: '12:07',
      unreadCount: 0,
    ),
    ChatItem(
      id: '5',
      name: 'Beau Archer',
      avatarUrl: 'https://picsum.photos/200/200?random=5',
      lastType: MessageType.text,
      lastText: 'I can\'t stop eating snacks 😅',
      lastTime: '12:07',
      unreadCount: 0,
    ),
    ChatItem(
      id: '6',
      name: 'Ada Cruz',
      avatarUrl: 'https://picsum.photos/200/200?random=6',
      lastType: MessageType.voice,
      lastText: 'That song is stuck in my head 🎵',
      lastTime: '12:07',
      unreadCount: 0,
    ),
    ChatItem(
      id: '7',
      name: 'Benny Blankon',
      avatarUrl: 'https://picsum.photos/200/200?random=7',
      lastType: MessageType.text,
      lastText: 'You free this weekend?',
      lastTime: '12:07',
      unreadCount: 0,
    ),
    ChatItem(
      id: '8',
      name: 'Aiden Blaze',
      avatarUrl: 'https://picsum.photos/200/200?random=8',
      lastType: MessageType.images,
      lastText: 'Let\'s do a photo dump 📸',
      lastTime: '12:07',
      unreadCount: 0,
    ),
  ];

  final List<CommunityItem> _communities = [
    CommunityItem(
      id: '1',
      name: 'Environment',
      avatarUrl: 'https://picsum.photos/200/200?random=11',
      bio: 'A vibrant community of music lovers sharing their passion',
      friendsInCommon: '+1K',
      unreadPosts: 0,
    ),
    CommunityItem(
      id: '2',
      name: 'Story Telling',
      avatarUrl: 'https://picsum.photos/200/200?random=12',
      bio: 'A vibrant community of music lovers sharing their passion',
      friendsInCommon: '+1K',
      unreadPosts: 0,
    ),
    CommunityItem(
      id: '3',
      name: 'Day One Code',
      avatarUrl: 'https://picsum.photos/200/200?random=13',
      bio: 'A vibrant community of music lovers sharing their passion',
      friendsInCommon: '+1K',
      unreadPosts: 0,
    ),
    CommunityItem(
      id: '4',
      name: 'Aviations',
      avatarUrl: 'https://picsum.photos/200/200?random=14',
      bio: 'A vibrant community of music lovers sharing their passion',
      friendsInCommon: '+1K',
      unreadPosts: 0,
    ),
    CommunityItem(
      id: '5',
      name: 'PartyPlanet Crew',
      avatarUrl: 'https://picsum.photos/200/200?random=15',
      bio: 'A vibrant community of music lovers sharing their passion',
      friendsInCommon: '+1K',
      unreadPosts: 0,
    ),
    CommunityItem(
      id: '6',
      name: 'Ghost',
      avatarUrl: 'https://picsum.photos/200/200?random=16',
      bio: 'A vibrant community of music lovers sharing their passion',
      friendsInCommon: '+1K',
      unreadPosts: 0,
    ),
  ];

  // Sample users available for new chats
  final List<UserItem> _availableUsers = [
    UserItem(
      id: 'u1',
      name: 'Sarah Johnson',
      avatarUrl: 'https://picsum.photos/200/200?random=21',
      bio: 'Entrepreneur & Tech Enthusiast',
      isOnline: true,
      mutualConnections: 12,
    ),
    UserItem(
      id: 'u2',
      name: 'Michael Chen',
      avatarUrl: 'https://picsum.photos/200/200?random=22',
      bio: 'Investment Analyst at Goldman Sachs',
      isOnline: false,
      mutualConnections: 8,
    ),
    UserItem(
      id: 'u3',
      name: 'Emma Rodriguez',
      avatarUrl: 'https://picsum.photos/200/200?random=23',
      bio: 'Startup Founder | AI & Machine Learning',
      isOnline: true,
      mutualConnections: 15,
    ),
    UserItem(
      id: 'u4',
      name: 'David Kim',
      avatarUrl: 'https://picsum.photos/200/200?random=24',
      bio: 'Venture Capitalist at Sequoia Capital',
      isOnline: false,
      mutualConnections: 23,
    ),
    UserItem(
      id: 'u5',
      name: 'Lisa Thompson',
      avatarUrl: 'https://picsum.photos/200/200?random=25',
      bio: 'Product Manager at Meta',
      isOnline: true,
      mutualConnections: 7,
    ),
    UserItem(
      id: 'u6',
      name: 'Alex Morgan',
      avatarUrl: 'https://picsum.photos/200/200?random=26',
      bio: 'Blockchain Developer & Crypto Investor',
      isOnline: false,
      mutualConnections: 19,
    ),
    UserItem(
      id: 'u7',
      name: 'Rachel Green',
      avatarUrl: 'https://picsum.photos/200/200?random=27',
      bio: 'Marketing Director at Spotify',
      isOnline: true,
      mutualConnections: 11,
    ),
    UserItem(
      id: 'u8',
      name: 'James Wilson',
      avatarUrl: 'https://picsum.photos/200/200?random=28',
      bio: 'Serial Entrepreneur | 3 Exits',
      isOnline: false,
      mutualConnections: 31,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToChat(ChatItem chatItem) {
    // Convert ChatItem to ChatUser for navigation
    final chatUser = ChatUser(
      id: chatItem.id,
      name: chatItem.name,
      avatarUrl: chatItem.avatarUrl,
      isOnline: true, // You can modify this based on your logic
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatPage(otherUser: chatUser, isDarkMode: widget.isDarkMode),
      ),
    );
  }

  void _navigateToCommunity(CommunityItem community) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityPage(communityName: community.name),
      ),
    );
  }

  void _navigateToInvitations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InvitationPage()),
    );
  }

  void _showNewChatBottomSheet() {
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NewChatBottomSheet(
        isDarkMode: isDark,
        availableUsers: _availableUsers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode ?? theme.brightness == Brightness.dark;

    debugPrint('ConversationsPage building with isDark: $isDark');

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(isDark),

            // Tab Switcher
            _buildTabSwitcher(isDark),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _chats.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: const Color(0xFF666666).withValues(alpha: 26),
                          indent: 64,
                        ),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _navigateToChat(_chats[index]),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: index % 2 == 0
                                        ? const Color(0xFF007AFF)
                                        : Colors.white,
                                    child: Text(
                                      _chats[index].name.substring(0, 1),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: index % 2 == 0
                                            ? Colors.white
                                            : const Color(0xFF007AFF),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _chats[index].name,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              _chats[index].lastTime,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: const Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (_chats[index].lastType ==
                                                MessageType.video)
                                              const Icon(
                                                Icons.videocam,
                                                size: 16,
                                                color: Color(0xFF666666),
                                              )
                                            else if (_chats[index].lastType ==
                                                MessageType.images)
                                              const Icon(
                                                Icons.image,
                                                size: 16,
                                                color: Color(0xFF666666),
                                              )
                                            else if (_chats[index].lastType ==
                                                MessageType.voice)
                                              const Icon(
                                                Icons.mic,
                                                size: 16,
                                                color: Color(0xFF666666),
                                              ),
                                            if (_chats[index].lastType !=
                                                MessageType.text)
                                              const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _chats[index].lastText ??
                                                    (_chats[index].lastType ==
                                                            MessageType.images
                                                        ? 'Images'
                                                        : _chats[index]
                                                                  .lastType ==
                                                              MessageType.video
                                                        ? 'Video'
                                                        : _chats[index]
                                                                  .lastType ==
                                                              MessageType.voice
                                                        ? 'Voice message'
                                                        : ''),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: const Color(
                                                    0xFF666666,
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_chats[index].unreadCount > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF007AFF),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '${_chats[index].unreadCount}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _communities.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: const Color(0xFF666666).withValues(alpha: 26),
                          indent: 64,
                        ),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () =>
                                _navigateToCommunity(_communities[index]),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: index % 2 == 0
                                        ? const Color(0xFF007AFF)
                                        : Colors.white,
                                    child: Text(
                                      _communities[index].name.substring(0, 1),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: index % 2 == 0
                                            ? Colors.white
                                            : const Color(0xFF007AFF),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _communities[index].name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _communities[index].bio,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: const Color(0xFF666666),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Member avatars stack
                                      SizedBox(
                                        width: 60,
                                        height: 24,
                                        child: Stack(
                                          children: [
                                            for (int i = 0; i < 3; i++)
                                              Positioned(
                                                right: i * 14.0,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.primaries[(i +
                                                                index) %
                                                            Colors
                                                                .primaries
                                                                .length],
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark
                                                          ? Colors.black
                                                          : Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _communities[index].friendsInCommon,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Text(
              'Conversations',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),

            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF666666),
                      width: 0.6,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF666666),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(width: 12),

                // Invitations button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF666666),
                      width: 0.6,
                    ),
                  ),
                  child: IconButton(
                    onPressed: _navigateToInvitations,
                    icon: const Icon(
                      Icons.mail_outline,
                      size: 18,
                      color: Color(0xFF666666),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(width: 12),

                // Add new chat button (replaced notification button)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF007AFF),
                    border: Border.all(
                      color: const Color(0xFF007AFF),
                      width: 0.6,
                    ),
                  ),
                  child: IconButton(
                    onPressed: _showNewChatBottomSheet,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SegmentedTabs(
        tabs: const ['Chats', 'Communities'],
        selectedIndex: _selectedTabIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
            _tabController.animateTo(index);
          });
        },
      ),
    );
  }
}

// Data Models
enum MessageType { text, images, video, voice }

class ChatItem {
  final String id;
  final String name;
  final String avatarUrl;
  final MessageType lastType;
  final String? lastText;
  final String lastTime;
  final int unreadCount;

  ChatItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.lastType,
    this.lastText,
    required this.lastTime,
    required this.unreadCount,
  });
}

class CommunityItem {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final String friendsInCommon;
  final int unreadPosts;

  CommunityItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.friendsInCommon,
    required this.unreadPosts,
  });
}

class UserItem {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final bool isOnline;
  final int mutualConnections;

  UserItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.isOnline,
    required this.mutualConnections,
  });
}

/* ========================= Invitations Feature (moved to lib/invitation_page.dart) ========================= */
