import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'widgets/segmented_tabs.dart';
import 'widgets/new_chat_bottom_sheet.dart';
import 'widgets/badge_icon.dart';

import 'chat_page.dart';
import 'models/message.dart';
import 'models/group_chat.dart';
import 'community_page.dart';
import 'groups/group_chat_page.dart';
import 'repositories/firebase/firebase_group_repository.dart';
import 'invitation_page.dart';
import 'conversation_search_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'core/i18n/language_provider.dart'; // Fixed import path
import 'core/admin_config.dart';

import 'package:provider/provider.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'repositories/interfaces/community_repository.dart';
import 'repositories/firebase/firebase_notification_repository.dart';
import 'responsive/responsive_breakpoints.dart';
import 'core/time_utils.dart';
import 'services/community_interest_sync_service.dart';
import 'services/app_cache_service.dart';
import 'core/profile_api.dart';

/// Global notifier for instant conversation list updates when messages are sent
class ConversationUpdateNotifier extends ChangeNotifier {
  static final ConversationUpdateNotifier _instance = ConversationUpdateNotifier._internal();
  factory ConversationUpdateNotifier() => _instance;
  ConversationUpdateNotifier._internal();

  String? _lastUpdatedConversationId;
  String? _lastMessageText;
  String? _lastMessageType;
  DateTime? _lastMessageTime;

  /// Call this from ChatPage when a message is sent
  void notifyMessageSent({
    required String conversationId,
    required String messageText,
    String messageType = 'text',
  }) {
    _lastUpdatedConversationId = conversationId;
    _lastMessageText = messageText;
    _lastMessageType = messageType;
    _lastMessageTime = DateTime.now();
    notifyListeners();
  }

  String? get lastUpdatedConversationId => _lastUpdatedConversationId;
  String? get lastMessageText => _lastMessageText;
  String? get lastMessageType => _lastMessageType;
  DateTime? get lastMessageTime => _lastMessageTime;
}

class ConversationsPage extends StatefulWidget {
  final bool? isDarkMode;
  final VoidCallback? onThemeToggle;
  final int initialTabIndex;
  final bool hideDesktopTopNav;

  const ConversationsPage({
    super.key,
    this.isDarkMode,
    this.onThemeToggle,
    this.initialTabIndex = 0,
    this.hideDesktopTopNav = false,
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
  late ConversationRepository _convRepo;
  late CommunityRepository _commRepo;

  // Notifications badge
  int _unreadNotifications = 0;

  // Chats state
  bool _loadingConversations = false;
  String? _errorConversations;
  final List<ChatItem> _chats = [];
  StreamSubscription<List<ConversationSummaryModel>>? _conversationsSubscription;
  
  // Groups state
  final FirebaseGroupRepository _groupRepo = FirebaseGroupRepository();
  final List<GroupChat> _groups = [];
  bool _loadingGroups = false;

  // Communities state
  bool _loadingCommunities = false;
  String? _errorCommunities;
  final List<CommunityItem> _communities = [];
  
  // Pagination for communities
  final ScrollController _communitiesScrollController = ScrollController();
  bool _loadingMoreCommunities = false;
  bool _hasMoreCommunities = true;
  String? _lastCommunityId;
  static const int _communitiesPerPage = 20;

  // Split-view selection (desktop)
  ChatItem? _selectedChat;
  CommunityItem? _selectedCommunity;
  GroupChat? _selectedGroup;

  late final AppCacheService _appCache;
  
  @override
  void initState() {
    super.initState();
    _convRepo = context.read<ConversationRepository>();
    _commRepo = context.read<CommunityRepository>();
    _appCache = AppCacheService();
    
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1).toInt(),
    );
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 1).toInt();
    _tabController.addListener(() {
      // Update on any index change (tap or swipe)
      if (_tabController.index != _selectedTabIndex) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    
    // Add scroll listener for communities pagination
    _communitiesScrollController.addListener(_onCommunitiesScroll);
    
    // FASTFEED: Listen for instant updates when messages are sent from ChatPage
    ConversationUpdateNotifier().addListener(_onConversationUpdated);
    
    // Listen for cache updates
    _appCache.addListener(_onAppCacheChanged);

    // INSTANT: Apply cached data immediately
    _applyCachedDataSync();
    
    // Background refresh
    _loadConversations();
    _loadGroups();
    _loadCommunities();
    _loadUnreadNotifications();
    
    // Subscribe to real-time conversation updates for unread badges
    _subscribeToConversations();
  }
  
  void _subscribeToConversations() {
    _conversationsSubscription?.cancel();
    _conversationsSubscription = _convRepo.listStream().listen((list) {
      if (!mounted) return;
      final mapped = list
          .map((c) => ChatItem(
                conversationId: c.id,
                id: c.otherUserId,
                name: c.otherUser.name,
                avatarUrl: c.otherUser.avatarUrl ?? '',
                lastType: _mapLastType(c.lastMessageType),
                lastText: _cleanLastMessageText(c.lastMessageText),
                lastTime: _formatTime(c.lastMessageAt),
                lastMessageAt: c.lastMessageAt,
                unreadCount: c.unreadCount,
                muted: c.muted,
              ))
          .toList();
      setState(() {
        _chats.clear();
        _chats.addAll(mapped);
      });
    });
  }
  
  void _onAppCacheChanged() {
    if (!mounted) return;
    _applyCachedDataSync();
  }
  
  void _applyCachedDataSync() {
    // Apply cached conversations
    if (_appCache.isConversationsLoaded && _appCache.conversations.isNotEmpty) {
      final mapped = _appCache.conversations
          .map((c) => ChatItem(
                conversationId: c.id,
                id: c.otherUserId,
                name: c.otherUser.name,
                avatarUrl: c.otherUser.avatarUrl ?? '',
                lastType: _mapLastType(c.lastMessageType),
                lastText: _cleanLastMessageText(c.lastMessageText),
                lastTime: _formatTime(c.lastMessageAt),
                lastMessageAt: c.lastMessageAt,
                unreadCount: c.unreadCount,
                muted: c.muted,
              ))
          .toList();
      _chats.clear();
      _chats.addAll(mapped);
      _loadingConversations = false;
    }
    
    // Apply cached communities
    if (_appCache.isCommunitiesLoaded && _appCache.communities.isNotEmpty) {
      final mapped = _appCache.communities
          .map((c) => CommunityItem(
                id: c.id,
                name: c.name,
                avatarUrl: c.avatarUrl,
                bio: c.bio,
                friendsInCommon: c.friendsInCommon,
                unreadPosts: c.unreadPosts,
              ))
          .toList();
      _communities.clear();
      _communities.addAll(mapped);
      _loadingCommunities = false;
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  /// INSTANT: Update conversation list when a message is sent from ChatPage
  void _onConversationUpdated() {
    final notifier = ConversationUpdateNotifier();
    final convId = notifier.lastUpdatedConversationId;
    final text = notifier.lastMessageText;
    final type = notifier.lastMessageType;
    final time = notifier.lastMessageTime;
    
    if (convId == null || !mounted) return;
    
    setState(() {
      // Find the chat and update it
      final idx = _chats.indexWhere((c) => c.conversationId == convId);
      if (idx != -1) {
        final chat = _chats[idx];
        // Move to top with updated last message
        _chats.removeAt(idx);
        _chats.insert(0, ChatItem(
          conversationId: chat.conversationId,
          id: chat.id,
          name: chat.name,
          avatarUrl: chat.avatarUrl,
          lastType: _mapLastType(type),
          lastText: text,
          lastTime: time != null ? _formatTime(time) : chat.lastTime,
          unreadCount: 0, // Reset for current user
          muted: chat.muted,
        ));
      }
    });
  }

  
  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    ConversationUpdateNotifier().removeListener(_onConversationUpdated);
    _appCache.removeListener(_onAppCacheChanged);
    _tabController.dispose();
    _communitiesScrollController.dispose();
    super.dispose();
  }
  
  void _onCommunitiesScroll() {
    if (_communitiesScrollController.position.pixels >=
        _communitiesScrollController.position.maxScrollExtent * 0.8) {
      if (!_loadingMoreCommunities && _hasMoreCommunities) {
        _loadMoreCommunities();
      }
    }
  }

  bool _isWideLayout(BuildContext context) {
    return kIsWeb && (context.isDesktop || context.isLargeDesktop);
  }

  /// Quick sync: Reconcile community memberships with user interests
  /// Runs in milliseconds - removes/adds memberships as needed
  Future<void> _syncCommunitiesWithInterests() async {
    try {
      // Get user's current interests from profile
      final profileData = await ProfileApi().me();
      final userData = profileData['data'] as Map<String, dynamic>?;
      if (userData == null) return;
      
      // Parse interests
      final interestsRaw = userData['interest_domains'];
      List<String> userInterests = [];
      if (interestsRaw is List) {
        userInterests = interestsRaw.map((e) => e.toString()).toList();
      } else if (interestsRaw is String) {
        // Handle JSON string
        userInterests = List<String>.from(jsonDecode(interestsRaw));
      }
      
      if (userInterests.isEmpty) return;
      
      // Get current community memberships
      final currentCommunities = await _commRepo.listMine();
      final currentCommunityNames = currentCommunities.map((c) => c.name).toSet();
      
      // Find mismatches
      final shouldHave = userInterests.toSet();
      final shouldRemove = currentCommunityNames.difference(shouldHave);
      final shouldAdd = shouldHave.difference(currentCommunityNames);
      
      // Quick sync if there are mismatches
      if (shouldRemove.isNotEmpty || shouldAdd.isNotEmpty) {
        await CommunityInterestSyncService().syncUserInterests(userInterests);
      }
    } catch (e) {
      // Silent fail - don't block community loading
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final c = await FirebaseNotificationRepository().getUnreadCount();
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
    return TimeUtils.relativeLabel(dt, locale: 'en_short');
  }

  // Clean story reply text to show only message without media URL
  String? _cleanLastMessageText(String? text) {
    if (text == null) return null;
    
    // Check if it's a story reply with media URL
    if (text.startsWith('📖 Story reply:')) {
      // Extract only the message part before the media URL separator
      // Format: "📖 Story reply: message|mediaUrl|mediaType"
      final parts = text.split('|');
      if (parts.isNotEmpty) {
        return parts[0]; // Return "📖 Story reply: message"
      }
    }
    
    return text;
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
      final list = await _convRepo.list();
      if (!mounted) return;
      final mapped = list
          .map(
            (c) => ChatItem(
              conversationId: c.id,
              id: c.otherUserId,
              name: c.otherUser.name,
              avatarUrl: c.otherUser.avatarUrl ?? '',
              lastType: _mapLastType(c.lastMessageType),
              lastText: _cleanLastMessageText(c.lastMessageText),
              lastTime: _formatTime(c.lastMessageAt),
              lastMessageAt: c.lastMessageAt,
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
      
      // Update global cache for instant display next time
      _appCache.updateConversations(list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorConversations = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      // Try cache first
      final cached = await _groupRepo.getMyGroupsFromCache();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _groups.clear();
          _groups.addAll(cached);
        });
      }
      
      // Then load fresh
      final groups = await _groupRepo.getMyGroups();
      if (!mounted) return;
      setState(() {
        _groups.clear();
        _groups.addAll(groups);
        _loadingGroups = false;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load groups: $e');
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  Future<void> _loadCommunities() async {
    try {
      setState(() {
        _loadingCommunities = true;
        _errorCommunities = null;
        _lastCommunityId = null;
        _hasMoreCommunities = true;
      });
      
      // Quick sync: Ensure communities match user's interests
      await _syncCommunitiesWithInterests();
      
      // Admin sees all communities, regular users see their communities
      final isAdmin = AdminConfig.isAdmin(fb.FirebaseAuth.instance.currentUser?.uid);
      debugPrint('📊 Loading initial communities (admin: $isAdmin)...');
      
      final list = isAdmin 
          ? await _commRepo.listAll(limit: _communitiesPerPage)
          : await _commRepo.listMine(limit: _communitiesPerPage);
      debugPrint('📨 Loaded ${list.length} communities');
      
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
        _lastCommunityId = list.isNotEmpty ? list.last.id : null;
        _hasMoreCommunities = list.length == _communitiesPerPage;
      });
      
      // Update global cache for instant display next time
      _appCache.updateCommunities(list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCommunities = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingCommunities = false);
    }
  }
  
  Future<void> _loadMoreCommunities() async {
    if (_loadingMoreCommunities || !_hasMoreCommunities || _lastCommunityId == null) return;
    
    setState(() => _loadingMoreCommunities = true);
    
    try {
      final isAdmin = AdminConfig.isAdmin(fb.FirebaseAuth.instance.currentUser?.uid);
      debugPrint('📊 Loading more communities after: $_lastCommunityId (admin: $isAdmin)');
      
      final list = isAdmin
          ? await _commRepo.listAll(
              limit: _communitiesPerPage,
              lastCommunityId: _lastCommunityId,
            )
          : await _commRepo.listMine(
              limit: _communitiesPerPage,
              lastCommunityId: _lastCommunityId,
            );
      debugPrint('📨 Loaded ${list.length} more communities');
      
      if (!mounted) return;
      
      if (list.isEmpty) {
        setState(() {
          _hasMoreCommunities = false;
          _loadingMoreCommunities = false;
        });
        return;
      }
      
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
        _communities.addAll(mapped);
        _lastCommunityId = list.last.id;
        _hasMoreCommunities = list.length == _communitiesPerPage;
        _loadingMoreCommunities = false;
      });
      
      debugPrint('✅ Total communities loaded: ${_communities.length}');
    } catch (e) {
      debugPrint('❌ Error loading more communities: $e');
      if (!mounted) return;
      setState(() => _loadingMoreCommunities = false);
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
        await _convRepo.markRead(item.conversationId);
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
        settings: const RouteSettings(name: 'chat'),
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
        settings: const RouteSettings(name: 'community'),
        builder: (context) => CommunityPage(
          communityId: community.id,
          communityName: community.name,
        ),
      ),
    );
  }

  void _selectGroup(GroupChat group) async {
    if (_isWideLayout(context)) {
      setState(() {
        _selectedGroup = group;
        _selectedChat = null;
        _selectedCommunity = null;
      });
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'group_chat'),
        builder: (context) => GroupChatPage(group: group),
      ),
    );

    if (!mounted) return;
    await _loadGroups();
  }

  void _showGroupActions(GroupChat group) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(group.isMuted(fb.FirebaseAuth.instance.currentUser?.uid ?? '') 
                    ? Icons.volume_up : Icons.volume_off),
                title: Text(group.isMuted(fb.FirebaseAuth.instance.currentUser?.uid ?? '')
                    ? lang.t('conversations.unmute') : lang.t('conversations.mute')),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    if (group.isMuted(fb.FirebaseAuth.instance.currentUser?.uid ?? '')) {
                      await _groupRepo.unmuteGroup(group.id);
                    } else {
                      await _groupRepo.muteGroup(group.id);
                    }
                    await _loadGroups();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: Text(lang.t('groups.leave_group'), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(lang.t('groups.leave_group')),
                      content: Text(lang.t('groups.leave_confirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(lang.t('common.cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: Text(lang.t('groups.leave')),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await _groupRepo.removeMember(group.id, fb.FirebaseAuth.instance.currentUser!.uid);
                      await _loadGroups();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
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

  void _navigateToInvitations() {
    Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'invitations'), builder: (context) => const InvitationPage()),
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
            settings: const RouteSettings(name: 'chat'),
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
                title: Text(Provider.of<LanguageProvider>(context, listen: false).t(item.muted ? 'conversations.unmute' : 'conversations.mute')),
                onTap: () async {
                  final ctx = context;
                  Navigator.pop(ctx);
                  try {
                    if (item.muted) {
                      await _convRepo.unmute(item.conversationId);
                    } else {
                      await _convRepo.mute(item.conversationId);
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
                      SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('conversations.action_failed')}: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined),
                title: Text(Provider.of<LanguageProvider>(context, listen: false).t('conversations.mark_read')),
                onTap: () async {
                  final ctx = context;
                  Navigator.pop(ctx);
                  try {
                    await _convRepo.markRead(item.conversationId);
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
                      SnackBar(content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('conversations.mark_read_failed')}: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(Provider.of<LanguageProvider>(context, listen: false).t('conversations.delete')),
                onTap: () async {
                  final ctx = context;
                  Navigator.pop(ctx);
                  try {
                    await _convRepo.delete(item.conversationId);
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
                      SnackBar(content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('conversations.delete_failed')}: $e')),
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
      if (widget.hideDesktopTopNav) {
        return Container(
          color: bg,
          child: _buildDesktopBody(isDark),
        );
      }
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
        Expanded(child: _buildDesktopBody(isDark)),
      ],
    ),
  );
}

Widget _buildDesktopBody(bool isDark) {
  return Center(
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
                    final desktop = kIsWeb && (context.isDesktop || context.isLargeDesktop);
                    if (desktop) {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierColor: Colors.black26,
                        builder: (_) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final size = MediaQuery.of(context).size;
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
                        MaterialPageRoute(settings: const RouteSettings(name: 'notifications'), builder: (_) => const NotificationPage()),
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
                  _navButton(isDark, icon: Icons.home_outlined, label: Provider.of<LanguageProvider>(context, listen: false).t('nav.home'), onTap: () {
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  }),
                  _navButton(isDark, icon: Icons.people_outline, label: Provider.of<LanguageProvider>(context, listen: false).t('nav.connections'), onTap: () {}),
                  _navButton(isDark, icon: Icons.chat_bubble_outline, label: Provider.of<LanguageProvider>(context, listen: false).t('conversations.title'), selected: true, onTap: () {}),
                  _navButton(isDark, icon: Icons.person_outline, label: Provider.of<LanguageProvider>(context, listen: false).t('nav.profile'), onTap: () {
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'profile'), builder: (_) => const ProfilePage()));
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
      automaticallyImplyLeading: false,
      title: Text(
        Provider.of<LanguageProvider>(context, listen: false).t('conversations.title'),
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      actions: [
        IconButton(
          tooltip: Provider.of<LanguageProvider>(context, listen: false).t('common.search'),
          icon: const Icon(Icons.search, color: iconColor),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(settings: const RouteSettings(name: 'conversation_search'), builder: (_) => const ConversationSearchPage()),
            );
          },
        ),
        IconButton(
          tooltip: Provider.of<LanguageProvider>(context, listen: false).t('invitations.title'),
          icon: const Icon(Icons.mail_outline, color: iconColor),
          onPressed: _navigateToInvitations,
        ),
        IconButton(
          tooltip: Provider.of<LanguageProvider>(context, listen: false).t('common.new_chat'),
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
                MaterialPageRoute(settings: const RouteSettings(name: 'notifications'), builder: (_) => const NotificationPage()),
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
              color: Colors.black.withValues (alpha: 0.05),
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
                Text(Provider.of<LanguageProvider>(context, listen: false).t('conversations.title'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                const Spacer(),
                _circleIcon(icon: Icons.search, tooltip: Provider.of<LanguageProvider>(context, listen: false).t('common.search'), onTap: () {
                  Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'conversation_search'), builder: (_) => const ConversationSearchPage()));
                }),
                const SizedBox(width: 8),
                                _circleIcon(
                  icon: Icons.mail_outline,
                  tooltip: Provider.of<LanguageProvider>(context, listen: false).t('invitations.title'),
                  onTap: () async {
                    final size = MediaQuery.of(context).size;
                    final desktop = kIsWeb && (context.isDesktop || context.isLargeDesktop);
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
                _circleIcon(icon: Icons.add, tooltip: Provider.of<LanguageProvider>(context, listen: false).t('common.new_chat'), filled: true, onTap: _showNewChatBottomSheet),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedTabs(
              tabs: [Provider.of<LanguageProvider>(context, listen: false).t('conversations.chats'), Provider.of<LanguageProvider>(context, listen: false).t('conversations.communities')],
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
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues (alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(Provider.of<LanguageProvider>(context, listen: false).t('conversations.select_chat'),
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
        tabs: [Provider.of<LanguageProvider>(context, listen: false).t('conversations.chats'), Provider.of<LanguageProvider>(context, listen: false).t('conversations.communities')],
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
    if (_loadingConversations && _loadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorConversations != null && _groups.isEmpty) {
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
                child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_chats.isEmpty && _groups.isEmpty) {
      return Center(
        child: Text(
          Provider.of<LanguageProvider>(context).t('chat.no_conversations'),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF666666),
          ),
        ),
      );
    }

    // Combine chats and groups into a single list sorted by time
    final combinedItems = <_CombinedChatItem>[];
    
    // Add regular chats
    for (final chat in _chats) {
      combinedItems.add(_CombinedChatItem(
        isGroup: false,
        chat: chat,
        sortTime: chat.lastMessageAt ?? DateTime(2000),
      ));
    }
    
    // Add groups
    for (final group in _groups) {
      combinedItems.add(_CombinedChatItem(
        isGroup: true,
        group: group,
        sortTime: group.lastMessageAt ?? group.updatedAt,
      ));
    }
    
    // Sort by most recent first
    combinedItems.sort((a, b) => b.sortTime.compareTo(a.sortTime));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: combinedItems.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: const Color(0xFF666666).withValues(alpha: 0.10),
        indent: 64,
      ),
      itemBuilder: (context, index) {
        final item = combinedItems[index];
        
        if (item.isGroup) {
          final group = item.group!;
          final selected = _isWideLayout(context) && _selectedGroup?.id == group.id;
          
          return _GroupListTile(
            group: group,
            isDark: isDark,
            selected: selected,
            onTap: () => _selectGroup(group),
            onLongPress: () => _showGroupActions(group),
          );
        } else {
          final chat = item.chat!;
          final selected = _isWideLayout(context) && _selectedChat?.conversationId == chat.conversationId;

          return ChatListTile(
            item: chat,
            isDark: isDark,
            selected: selected,
            onTap: () => _selectChat(chat),
            onLongPress: () => _showConversationActions(chat),
          );
        }
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
                child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.retry')),
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
      controller: _communitiesScrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _communities.length + (_loadingMoreCommunities ? 1 : 0) + (!_hasMoreCommunities && _communities.isNotEmpty ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index >= _communities.length) return const SizedBox.shrink();
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        // Show communities
        if (index < _communities.length) {
          final c = _communities[index];
          final selected = _isWideLayout(context) && _selectedCommunity?.id == c.id;

          return CommunityListTile(
            item: c,
            isDark: isDark,
            selected: selected,
            onTap: () => _selectCommunity(c),
          );
        }
        
        // Show loading indicator
        if (_loadingMoreCommunities && index == _communities.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading more communities...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Show end of list indicator
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'All communities loaded! 🎉',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF999999),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

  // Get display text for last message, handling story replies
  String _getDisplayText(ChatItem item) {
    final text = item.lastText;
    if (text == null || text.isEmpty) {
      // Fallback for media types
      if (item.lastType == MessageType.image) return 'Photo';
      if (item.lastType == MessageType.video) return 'Video';
      if (item.lastType == MessageType.voice) return 'Voice message';
      return '';
    }
    
    // Story reply: extract just the message part
    if (text.contains('Story reply:')) {
      final idx = text.indexOf('Story reply:');
      final afterPrefix = text.substring(idx + 'Story reply:'.length).trim();
      final parts = afterPrefix.split('|');
      final message = parts[0].trim();
      return message.isNotEmpty ? message : 'Replied to story';
    }
    
    return text;
  }

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
                          const Icon(Icons.mic, size: 16, color: Color(0xFF666666))
                        else if (item.lastText?.contains('Story reply') == true)
                          const Icon(Icons.auto_stories, size: 16, color: Color(0xFF9D7BFF)),
                        if (item.lastType != MessageType.text || item.lastText?.contains('Story reply') == true) 
                          const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getDisplayText(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, color: subColor),
                          ),
                        ),
                        if (item.unreadCount > 0) const SizedBox(width: 8),
                        if (item.unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBFAE01),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
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
              color: const Color(0xFF666666).withValues (alpha: 0.20),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person, color: Color(0xFF666666), size: 20),
          ),
          errorWidget: (context, url, error) => Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withValues (alpha: 0.20),
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
                      color: const Color(0xFF666666).withValues (alpha:0.10),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.group, color: Color(0xFF666666), size: 24),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF666666).withValues(alpha: 0.20),
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
                            color: const Color(0xFF666666).withValues(alpha: 0.10),
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
  final DateTime? lastMessageAt;
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
    this.lastMessageAt,
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
    DateTime? lastMessageAt,
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
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
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

/// Helper class to combine chats and groups for unified list
class _CombinedChatItem {
  final bool isGroup;
  final ChatItem? chat;
  final GroupChat? group;
  final DateTime sortTime;

  _CombinedChatItem({
    required this.isGroup,
    this.chat,
    this.group,
    required this.sortTime,
  });
}

/// Group list tile widget
class _GroupListTile extends StatelessWidget {
  final GroupChat group;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GroupListTile({
    required this.group,
    required this.isDark,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = const Color(0xFF666666);
    final unreadCount = group.unreadCounts[fb.FirebaseAuth.instance.currentUser?.uid] ?? 0;

    return Material(
      color: selected
          ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED))
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Group avatar with group icon overlay
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: group.avatarUrl != null
                        ? CachedNetworkImageProvider(group.avatarUrl!)
                        : null,
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    child: group.avatarUrl == null
                        ? Icon(Icons.group, color: Colors.grey[500], size: 24)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0C0C0C) : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.group, size: 10, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.lastMessageAt != null)
                          Text(
                            TimeUtils.relativeLabel(group.lastMessageAt!, locale: 'en_short'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: unreadCount > 0 ? const Color(0xFFBFAE01) : subtitleColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.lastMessageText ?? '${group.memberIds.length} members',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: subtitleColor,
                              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFBFAE01),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
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