import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets/segmented_tabs.dart';
import 'widgets/new_chat_bottom_sheet.dart';
import 'chat_page.dart';
import 'models/message.dart';
import 'community_page.dart';
import 'invitation_page.dart';
import 'core/conversations_api.dart';
import 'core/communities_api.dart';
import 'conversation_search_page.dart';

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
  final ConversationsApi _conversationsApi = ConversationsApi();

  // Chats state
  bool _loadingConversations = false;
  String? _errorConversations;
  final List<ChatItem> _chats = [];

  // Communities state
  final CommunitiesApi _communitiesApi = CommunitiesApi();
  bool _loadingCommunities = false;
  String? _errorCommunities;
  final List<CommunityItem> _communities = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1).toInt(),
    );
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1).toInt();
    _loadConversations();
    _loadCommunities();
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

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _loadingConversations = true;
        _errorConversations = null;
      });
      final list = await _conversationsApi.list();
      if (!mounted) return;
      final mapped = list
          .map(
            (c) => ChatItem(
              conversationId: c.id,
              id: c.otherUserId,
              name: c.otherUser.name,
              avatarUrl: c.otherUser.avatarUrl ?? '',
              lastType: _mapLastType(c.lastMessageType),
              lastText: c.lastMessageText,
              lastTime: _formatTime(c.lastMessageAt),
              unreadCount: c.unreadCount,
              muted: c.muted,
            ),
          )
          .toList();
      setState(() {
        _chats
          ..clear()
          ..addAll(mapped);
      });
    } catch (e) {
      setState(() {
        _errorConversations = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingConversations = false;
        });
      }
    }
  }

  Future<void> _loadCommunities() async {
    try {
      setState(() {
        _loadingCommunities = true;
        _errorCommunities = null;
      });
      final list = await _communitiesApi.listMine();
      if (!mounted) return;
      final mapped = list
          .map(
            (c) => CommunityItem(
              id: c.id,
              name: c.name,
              avatarUrl: c.avatarUrl,
              bio: c.bio,
              friendsInCommon: c.friendsInCommon,
              unreadPosts: c.unreadPosts,
            ),
          )
          .toList();
      setState(() {
        _communities
          ..clear()
          ..addAll(mapped);
      });
    } catch (e) {
      setState(() {
        _errorCommunities = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCommunities = false;
        });
      }
    }
  }

  MessageType _mapLastType(String? t) {
    switch (t) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.images;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      default:
        return MessageType.text;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final tod = TimeOfDay.fromDateTime(dt);
    return tod.format(context);
  }

  Future<void> _navigateToChat(ChatItem chatItem) async {
    final chatUser = ChatUser(
      id: chatItem.id,
      name: chatItem.name,
      avatarUrl: chatItem.avatarUrl,
      isOnline: true,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          otherUser: chatUser,
          isDarkMode: widget.isDarkMode,
          conversationId: chatItem.conversationId,
        ),
      ),
    );

    if (!mounted) return;
    await _loadConversations();
  }

  void _navigateToCommunity(CommunityItem community) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CommunityPage(
        communityId: community.id,
        communityName: community.name,
      ),
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

    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          NewChatBottomSheet(isDarkMode: isDark, availableUsers: []),
    ).then((result) async {
      if (!mounted) return;
      if (result == null) return;
      final convId = (result['conversationId'] ?? '').toString();
      final user = result['user'];
      if (convId.isEmpty || user == null) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            otherUser: user,
            isDarkMode: widget.isDarkMode,
            conversationId: convId,
          ),
        ),
      );

      await _loadConversations();
    });
  }

  void _showConversationActions(ChatItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(item.muted ? Icons.volume_up : Icons.volume_off),
                title: Text(item.muted ? 'Unmute' : 'Mute'),
                onTap: () async {
                  final ctx = context;
                  Navigator.pop(ctx);
                  try {
                    if (item.muted) {
                      await _conversationsApi.unmute(item.conversationId);
                    } else {
                      await _conversationsApi.mute(item.conversationId);
                    }
                    if (!ctx.mounted) return;
                    setState(() {
                      final idx = _chats.indexWhere(
                        (c) => c.conversationId == item.conversationId,
                      );
                      if (idx != -1) {
                        _chats[idx] = _chats[idx].copyWith(muted: !item.muted);
                      }
                    });
                  } catch (e) {
                    if (!ctx.mounted) return;
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Action failed: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined),
                title: const Text('Mark as read'),
                onTap: () async {
                  final ctx = context;
                  Navigator.pop(ctx);
                  try {
                    await _conversationsApi.markRead(item.conversationId);
                    if (!ctx.mounted) return;
                    setState(() {
                      final idx = _chats.indexWhere(
                        (c) => c.conversationId == item.conversationId,
                      );
                      if (idx != -1) {
                        _chats[idx] = _chats[idx].copyWith(unreadCount: 0);
                      }
                    });
                  } catch (e) {
                    if (!ctx.mounted) return;
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to mark read: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete'),
                onTap: () async {
                  final ctx = context;
                  Navigator.pop(ctx);
                  try {
                    await _conversationsApi.delete(item.conversationId);
                    if (!ctx.mounted) return;
                    setState(() {
                      _chats.removeWhere(
                        (c) => c.conversationId == item.conversationId,
                      );
                    });
                  } catch (e) {
                    if (!ctx.mounted) return;
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
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
            _buildAppBar(isDark),
            _buildTabSwitcher(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Chats tab
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
                      child: _loadingConversations
                          ? const Center(child: CircularProgressIndicator())
                          : _errorConversations != null
                              ? Center(child: Text(_errorConversations!))
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _chats.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: const Color(0xFF666666).withValues(alpha: 0.1),
                                    indent: 64,
                                  ),
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () => _navigateToChat(_chats[index]),
                                      onLongPress: () => _showConversationActions(_chats[index]),
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
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        _chats[index].name,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white : Colors.black,
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
                                                      if (_chats[index].lastType == MessageType.video)
                                                        const Icon(Icons.videocam, size: 16, color: Color(0xFF666666))
                                                      else if (_chats[index].lastType == MessageType.images)
                                                        const Icon(Icons.image, size: 16, color: Color(0xFF666666))
                                                      else if (_chats[index].lastType == MessageType.voice)
                                                        const Icon(Icons.mic, size: 16, color: Color(0xFF666666)),
                                                      if (_chats[index].lastType != MessageType.text)
                                                        const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          _chats[index].lastText ??
                                                              (_chats[index].lastType == MessageType.images
                                                                  ? 'Images'
                                                                  : _chats[index].lastType == MessageType.video
                                                                      ? 'Video'
                                                                      : _chats[index].lastType == MessageType.voice
                                                                          ? 'Voice message'
                                                                          : ''),
                                                          style: GoogleFonts.inter(
                                                            fontSize: 14,
                                                            color: const Color(0xFF666666),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (_chats[index].unreadCount > 0)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  // Communities tab
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
                      child: _loadingCommunities
                          ? const Center(child: CircularProgressIndicator())
                          : _errorCommunities != null
                              ? Center(child: Text(_errorCommunities!))
                              : _communities.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40.0),
                                        child: Text(
                                          'No communities yet.\nAdd or update your interests to join communities automatically.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 16, color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      itemCount: _communities.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final c = _communities[index];
                                        return GestureDetector(
                                          onTap: () => _navigateToCommunity(c),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.black : Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                // Avatar
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(24),
                                                  child: CachedNetworkImage(
                                                    imageUrl: c.avatarUrl,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF666666).withValues(alpha: 0),
                                                        borderRadius: BorderRadius.circular(24),
                                                      ),
                                                      child: const Icon(Icons.group, color: Color(0xFF666666), size: 24),
                                                    ),
                                                    errorWidget: (context, url, error) => Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF666666).withValues(alpha: 51),
                                                        borderRadius: BorderRadius.circular(24),
                                                      ),
                                                      child: const Icon(Icons.group, color: Color(0xFF666666), size: 24),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Content
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        c.name,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white : Colors.black,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        c.bio,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          color: const Color(0xFF666666),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Right side: avatars stack + unread badge
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    SizedBox(
                                                      width: 80,
                                                      height: 24,
                                                      child: Stack(
                                                        children: [
                                                          for (int i = 0; i < 3; i++)
                                                            Positioned(
                                                              right: i * 16.0,
                                                              child: Container(
                                                                width: 24,
                                                                height: 24,
                                                                decoration: BoxDecoration(
                                                                  color: _getMemberAvatarColor(i),
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(
                                                                    color: isDark ? Colors.black : Colors.white,
                                                                    width: 2,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          Positioned(
                                                            right: 0,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF666666).withValues(alpha: 0),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                c.friendsInCommon,
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w500,
                                                                  color: const Color(0xFF666666),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    if (c.unreadPosts > 0)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFF2196F3),
                                                          borderRadius: BorderRadius.all(Radius.circular(12)),
                                                        ),
                                                        child: Text(
                                                          c.unreadPosts.toString(),
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

  Color _getMemberAvatarColor(int index) {
    const colors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFFF44336),
    ];
    return colors[index % colors.length];
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
            Text(
              'Conversations',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConversationSearchPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF666666),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
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

enum MessageType { text, images, video, voice }

class ChatItem {
  final String conversationId;
  final String id;
  final String name;
  final String avatarUrl;
  final MessageType lastType;
  final String? lastText;
  final String lastTime;
  final int unreadCount;
  final bool muted;

  ChatItem({
    required this.conversationId,
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.lastType,
    this.lastText,
    required this.lastTime,
    required this.unreadCount,
    this.muted = false,
  });

  ChatItem copyWith({
    String? conversationId,
    String? id,
    String? name,
    String? avatarUrl,
    MessageType? lastType,
    String? lastText,
    String? lastTime,
    int? unreadCount,
    bool? muted,
  }) {
    return ChatItem(
      conversationId: conversationId ?? this.conversationId,
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastType: lastType ?? this.lastType,
      lastText: lastText ?? this.lastText,
      lastTime: lastTime ?? this.lastTime,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
    );
  }
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