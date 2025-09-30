import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'widgets/segmented_tabs.dart';
import 'widgets/new_chat_bottom_sheet.dart';
import 'widgets/badge_icon.dart';

import 'chat_page.dart';
import 'models/message.dart';
import 'community_page.dart';
import 'invitation_page.dart';
import 'conversation_search_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';

import 'core/conversations_api.dart';
import 'core/communities_api.dart';
import 'core/notifications_api.dart';

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
  // Tabs
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // APIs
  final ConversationsApi _conversationsApi = ConversationsApi();
  final CommunitiesApi _communitiesApi = CommunitiesApi();

  // Notifications badge
  int _unreadNotifications = 0;

  // Chats state
  bool _loadingConversations = false;
  String? _errorConversations;
  final List<ChatItem> _chats = [];

  // Communities state
  bool _loadingCommunities = false;
  String? _errorCommunities;
  final List<CommunityItem> _communities = [];

  // Split-view selection (desktop)
  ChatItem? _selectedChat;
  CommunityItem? _selectedCommunity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1).toInt(),
    );
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1).toInt();
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });

    _loadConversations();
    _loadCommunities();
    _loadUnreadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isWideLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return kIsWeb && size.width >= 1280 && size.height >= 800;
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final c = await NotificationsApi().unreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }

  // Map last message type from API to UI model
  MessageType _mapLastType(String? t) {
    switch (t) {
      case 'text':
        return MessageType.text;
      case 'image':
      case 'images':
        return MessageType.image;
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

  // -----------------------------
  // Data loading
  // -----------------------------
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
        if (_isWideLayout(context) && _selectedChat == null && _chats.isNotEmpty) {
          _selectedChat = _chats.first;
          _selectedCommunity = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorConversations = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
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
      if (!mounted) return;
      setState(() {
        _errorCommunities = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingCommunities = false);
    }
  }

  // -----------------------------
  // Selection + navigation
  // -----------------------------
  void _selectChat(ChatItem item) async {
    if (_isWideLayout(context)) {
      setState(() {
        _selectedChat = item;
        _selectedCommunity = null;
        final idx = _chats.indexWhere((c) => c.conversationId == item.conversationId);
        if (idx != -1) _chats[idx] = _chats[idx].copyWith(unreadCount: 0);
      });
      try {
        await _conversationsApi.markRead(item.conversationId);
      } catch (_) {}
    } else {
      await _navigateToChat(item);
    }
  }

  void _selectCommunity(CommunityItem item) {
    if (_isWideLayout(context)) {
      setState(() {
        _selectedCommunity = item;
        _selectedChat = null;
      });
    } else {
      _navigateToCommunity(item);
    }
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

      final createdChat = ChatItem(
        conversationId: convId,
        id: user.id,
        name: user.name,
        avatarUrl: user.avatarUrl ?? '',
        lastType: MessageType.text,
        lastText: '',
        lastTime: '',
        unreadCount: 0,
      );

      if (_isWideLayout(context)) {
        setState(() {
          _chats.insert(0, createdChat);
          _selectedChat = createdChat;
          _selectedCommunity = null;
        });
      } else {
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
      }
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
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Action failed: $e')),
                    );
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
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to mark read: $e')),
                    );
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
                      if (_selectedChat?.conversationId == item.conversationId) {
                        _selectedChat = null;
                      }
                    });
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

    // -----------------------------
  // Build
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode ?? theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    if (_isWideLayout(context)) {
      return _buildDesktop(context, isDark, bg);
    }

    // Mobile / small
    return Scaffold(
      backgroundColor: bg,
      appBar: _buildMobileAppBar(isDark),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildTabSwitcher(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _buildChatsList(isDark, isDesktop: false),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _buildCommunitiesList(isDark, isDesktop: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, bool isDark, Color backgroundColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildDesktopTopNav(isDark),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: _buildLeftPanel(isDark)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildRightPanel(isDark)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTopNav(bool isDark) {
    final barColor = isDark ? Colors.black : Colors.white;
    return Material(
      color: barColor,
      elevation: isDark ? 0 : 2,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu, color: Color(0xFF666666)),
                  const Spacer(),
                  Text(
                    'NEXUM',
                    style: GoogleFonts.inika(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  BadgeIcon(
                    icon: Icons.notifications_outlined,
                    badgeCount: _unreadNotifications,
                    iconColor: const Color(0xFF666666),
                                        onTap: () async {
                      // Desktop top-right popup
                      final size = MediaQuery.of(context).size;
                      final desktop = kIsWeb && size.width >= 1280 && size.height >= 800;
                      if (desktop) {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.black26,
                          builder: (_) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final double width = 420;
                            final double height = size.height * 0.8;
                            return SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16, right: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: Material(
                                        color: isDark ? const Color(0xFF000000) : Colors.white,
                                        child: const NotificationPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationPage()),
                        );
                      }
                      if (!mounted) return;
                      await _loadUnreadNotifications();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _navButton(isDark, icon: Icons.home_outlined, label: 'Home', onTap: () {
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  }),
                  _navButton(isDark, icon: Icons.people_outline, label: 'Connections', onTap: () {}),
                  _navButton(isDark, icon: Icons.chat_bubble_outline, label: 'Conversations', selected: true, onTap: () {}),
                  _navButton(isDark, icon: Icons.person_outline, label: 'My Profil', onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(bool isDark) {
    final barColor = isDark ? Colors.black : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;
    const iconColor = Color(0xFF666666);

    return AppBar(
      backgroundColor: barColor,
      elevation: isDark ? 0 : 2,
      centerTitle: false,
      title: Text(
        'Conversations',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search, color: iconColor),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConversationSearchPage()),
            );
          },
        ),
        IconButton(
          tooltip: 'Invitations',
          icon: const Icon(Icons.mail_outline, color: iconColor),
          onPressed: _navigateToInvitations,
        ),
        IconButton(
          tooltip: 'New chat',
          icon: const Icon(Icons.add, color: iconColor),
          onPressed: _showNewChatBottomSheet,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: BadgeIcon(
            icon: Icons.notifications_outlined,
            badgeCount: _unreadNotifications,
            iconColor: iconColor,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
              await _loadUnreadNotifications();
            },
          ),
        ),
      ],
    );
  }

  Widget _navButton(bool isDark, {required IconData icon, required String label, bool selected = false, VoidCallback? onTap}) {
    final color = selected ? const Color(0xFFBFAE01) : const Color(0xFF666666);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: GoogleFonts.inter(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      ),
    );
  }

  Widget _buildLeftPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text('Conversations', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                const Spacer(),
                _circleIcon(icon: Icons.search, tooltip: 'Search', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationSearchPage()));
                }),
                const SizedBox(width: 8),
                                _circleIcon(
                  icon: Icons.mail_outline,
                  tooltip: 'Invitations',
                  onTap: () async {
                    final size = MediaQuery.of(context).size;
                    final desktop = kIsWeb && size.width >= 1280 && size.height >= 800;
                    if (desktop) {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierColor: Colors.black26,
                        builder: (_) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final double width = 420;
                          final double height = size.height * 0.8;
                          return SafeArea(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16, left: 16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: width,
                                    height: height,
                                    child: Material(
                                      color: isDark ? const Color(0xFF000000) : Colors.white,
                                      child: const InvitationPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      _navigateToInvitations();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _circleIcon(icon: Icons.add, tooltip: 'New chat', filled: true, onTap: _showNewChatBottomSheet),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _selectedTabIndex == 0
                  ? _buildChatsList(isDark, isDesktop: true)
                  : _buildCommunitiesList(isDark, isDesktop: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;

    if (_selectedChat == null && _selectedCommunity == null) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text('Select a chat or community',
              style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600)),
        ),
      );
    }

    if (_selectedChat != null) {
      final u = _selectedChat!;
      final chatUser = ChatUser(id: u.id, name: u.name, avatarUrl: u.avatarUrl, isOnline: true);
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ChatPage(
          key: ValueKey('chat:${u.conversationId}'),
          otherUser: chatUser,
          isDarkMode: isDark,
          conversationId: u.conversationId,
        ),
      );
    }

    final c = _selectedCommunity!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CommunityPage(
        key: ValueKey('community:${c.id}'),
        communityId: c.id,
        communityName: c.name,
      ),
    );
  }

  Widget _circleIcon({required IconData icon, String? tooltip, bool filled = false, required VoidCallback onTap}) {
    final bg = filled ? const Color(0xFF007AFF) : Colors.transparent;
    final border = filled ? const Color(0xFF007AFF) : const Color(0xFF666666);
    final iconColor = filled ? Colors.white : const Color(0xFF666666);
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg, border: Border.all(color: border, width: 0.6)),
        child: IconButton(onPressed: onTap, icon: Icon(icon, size: 18, color: iconColor), padding: EdgeInsets.zero),
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

    // -----------------------------
  // Lists (left column content)
  // -----------------------------
  Widget _buildChatsList(bool isDark, {required bool isDesktop}) {
    if (_loadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorConversations != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorConversations!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadConversations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_chats.isEmpty) {
      return Center(
        child: Text(
          'No conversations yet',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF666666),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _chats.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: const Color(0xFF666666).withOpacity(0.10),
        indent: 64,
      ),
      itemBuilder: (context, index) {
        final item = _chats[index];
        final selected =
            _isWideLayout(context) && _selectedChat?.conversationId == item.conversationId;

        return ChatListTile(
          item: item,
          isDark: isDark,
          selected: selected,
          onTap: () => _selectChat(item),
          onLongPress: () => _showConversationActions(item),
        );
      },
    );
  }

  Widget _buildCommunitiesList(bool isDark, {required bool isDesktop}) {
    if (_loadingCommunities) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCommunities != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorCommunities!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadCommunities,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_communities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            'No communities yet.\nAdd or update your interests to join communities automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF666666)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _communities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _communities[index];
        final selected = _isWideLayout(context) && _selectedCommunity?.id == c.id;

        return CommunityListTile(
          item: c,
          isDark: isDark,
          selected: selected,
          onTap: () => _selectCommunity(c),
        );
      },
    );
  }
}

// -----------------------------
// List tiles
// -----------------------------
class ChatListTile extends StatelessWidget {
  final ChatItem item;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatListTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bgSelected = isDark ? const Color(0xFF151515) : const Color(0xFFF7F9FC);
    final nameColor = isDark ? Colors.white : Colors.black;
    final subColor = const Color(0xFF666666);

    return Material(
      color: selected ? bgSelected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: nameColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.lastTime,
                          style: GoogleFonts.inter(fontSize: 12, color: subColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.lastType == MessageType.video)
                          const Icon(Icons.videocam, size: 16, color: Color(0xFF666666))
                        else if (item.lastType == MessageType.image)
                          const Icon(Icons.image, size: 16, color: Color(0xFF666666))
                        else if (item.lastType == MessageType.voice)
                          const Icon(Icons.mic, size: 16, color: Color(0xFF666666)),
                        if (item.lastType != MessageType.text) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.lastText?.isNotEmpty == true
                                ? item.lastText!
                                : (item.lastType == MessageType.image
                                    ? 'Images'
                                    : item.lastType == MessageType.video
                                        ? 'Video'
                                        : item.lastType == MessageType.voice
                                            ? 'Voice message'
                                            : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, color: subColor),
                          ),
                        ),
                        if (item.unreadCount > 0) const SizedBox(width: 8),
                        if (item.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF007AFF),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${item.unreadCount}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (item.muted) const SizedBox(width: 8),
                        if (item.muted)
                          const Icon(Icons.volume_off, size: 16, color: Color(0xFF999999)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final hasImage = item.avatarUrl.isNotEmpty;
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CachedNetworkImage(
          imageUrl: item.avatarUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withOpacity(0.20),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person, color: Color(0xFF666666), size: 20),
          ),
          errorWidget: (context, url, error) => Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withOpacity(0.20),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person, color: Color(0xFF666666), size: 20),
          ),
        ),
      );
    }

    final letter = (item.name.trim().isNotEmpty ? item.name.trim()[0] : '?').toUpperCase();
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF007AFF),
      child: Text(
        letter,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class CommunityListTile extends StatelessWidget {
  final CommunityItem item;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  const CommunityListTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgSelected = isDark ? const Color(0xFF151515) : const Color(0xFFF7F9FC);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subColor = const Color(0xFF666666);

    return Material(
      color: selected ? bgSelected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: item.avatarUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF666666).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.group, color: Color(0xFF666666), size: 24),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF666666).withOpacity(0.20),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.group, color: Color(0xFF666666), size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, color: subColor),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF666666).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.friendsInCommon,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: subColor),
                          ),
                        ),
                        const Spacer(),
                        if (item.unreadPosts > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Text(
                              item.unreadPosts.toString(),
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
      ),
    );
  }
}

// -----------------------------
// Models for left list
// -----------------------------
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