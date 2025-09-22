import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/segmented_tabs.dart';
import 'widgets/new_chat_bottom_sheet.dart';
import 'chat_page.dart';
import 'models/message.dart';
import 'community_page.dart';
import 'invitation_page.dart';
import 'core/conversations_api.dart';

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
  bool _loadingConversations = false;
  String? _errorConversations;

  final List<ChatItem> _chats = [];

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
    // Note: we guarded mounted after the await before calling this
  }

  void _navigateToChat(ChatItem chatItem) {
    final chatUser = ChatUser(
      id: chatItem.id,
      name: chatItem.name,
      avatarUrl: chatItem.avatarUrl,
      isOnline: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          otherUser: chatUser,
          isDarkMode: widget.isDarkMode,
          conversationId: chatItem.conversationId,
        ),
      ),
    );
  }

  // ignore: unused_element
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
      builder: (context) =>
          NewChatBottomSheet(isDarkMode: isDark, availableUsers: []),
    );
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
                                color: const Color(
                                  0xFF666666,
                                ).withValues(alpha: 0.1),
                                indent: 64,
                              ),
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _navigateToChat(_chats[index]),
                                  onLongPress: () =>
                                      _showConversationActions(_chats[index]),
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
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    _chats[index].name,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                  Text(
                                                    _chats[index].lastTime,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
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
                                                  else if (_chats[index]
                                                          .lastType ==
                                                      MessageType.images)
                                                    const Icon(
                                                      Icons.image,
                                                      size: 16,
                                                      color: Color(0xFF666666),
                                                    )
                                                  else if (_chats[index]
                                                          .lastType ==
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
                                                          (_chats[index]
                                                                      .lastType ==
                                                                  MessageType
                                                                      .images
                                                              ? 'Images'
                                                              : _chats[index]
                                                                        .lastType ==
                                                                    MessageType
                                                                        .video
                                                              ? 'Video'
                                                              : _chats[index]
                                                                        .lastType ==
                                                                    MessageType
                                                                        .voice
                                                              ? 'Voice message'
                                                              : ''),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: const Color(
                                                          0xFF666666,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (_chats[index]
                                                          .unreadCount >
                                                      0)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Color(
                                                              0xFF007AFF,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: Text(
                                                        '${_chats[index].unreadCount}',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
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
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text(
                            'Communities coming soon...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
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
