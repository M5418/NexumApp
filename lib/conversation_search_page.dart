import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'widgets/segmented_tabs.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'repositories/interfaces/community_repository.dart';
import 'chat_page.dart';
import 'community_page.dart';
import 'models/message.dart'; // for ChatUser
import 'core/time_utils.dart';

class ConversationSearchPage extends StatefulWidget {
  const ConversationSearchPage({super.key});

  @override
  State<ConversationSearchPage> createState() => _ConversationSearchPageState();
}

class _ConversationSearchPageState extends State<ConversationSearchPage> {
  final TextEditingController _controller = TextEditingController();
  late ConversationRepository _convRepo;
  late CommunityRepository _commRepo;

  int _selectedTabIndex = 0;

  bool _loadingConversations = false;
  bool _loadingCommunities = false;
  String? _errorConversations;
  String? _errorCommunities;

  // Full datasets
  List<ConversationSummaryModel> _allConversations = [];
  List<CommunityModel> _allCommunities = [];

  // Filtered results for the current query
  List<ConversationSummaryModel> _convResults = [];
  List<CommunityModel> _commResults = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _convRepo = context.read<ConversationRepository>();
    _commRepo = context.read<CommunityRepository>();
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await Future.wait([_loadConversations(), _loadCommunities()]);
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loadingConversations = true;
      _errorConversations = null;
    });
    try {
      final list = await _convRepo.list();
      if (!mounted) return;
      setState(() {
        _allConversations = list;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorConversations = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingConversations = false);
      }
    }
  }

  Future<void> _loadCommunities() async {
    setState(() {
      _loadingCommunities = true;
      _errorCommunities = null;
    });
    try {
      final list = await _commRepo.listMine();
      if (!mounted) return;
      setState(() {
        _allCommunities = list;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCommunities = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingCommunities = false);
      }
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _applyFilter);
  }

  void _applyFilter() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _convResults = [];
        _commResults = [];
      });
      return;
    }

    // Chats: filter by other user name/username/last message text
    final conv = _allConversations.where((c) {
      final name = c.otherUser.name.toLowerCase();
      final handle = c.otherUser.username.toLowerCase();
      final last = (c.lastMessageText ?? '').toLowerCase();
      return name.contains(q) || handle.contains(q) || last.contains(q);
    }).toList();

    // Communities: filter by community name and bio
    final comm = _allCommunities.where((c) {
      final name = c.name.toLowerCase();
      final bio = c.bio.toLowerCase();
      return name.contains(q) || bio.contains(q);
    }).toList();

    setState(() {
      _convResults = conv;
      _commResults = comm;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final appBarBg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: appBarBg,
          elevation: 5,
          automaticallyImplyLeading: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Row(
                children: [
                  // Back
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
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Color(0xFF666666),
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search field
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF666666).withValues(alpha: 0),
                          width: 0.6,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF666666),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _onQueryChanged,
                              style: GoogleFonts.inter(fontSize: 15),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: _selectedTabIndex == 0
                                    ? Provider.of<LanguageProvider>(context, listen: false).t('convsearch.search_chats')
                                    : Provider.of<LanguageProvider>(context, listen: false).t('convsearch.search_communities'),
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() {
                                  _convResults = [];
                                  _commResults = [];
                                  _errorConversations = null;
                                  _errorCommunities = null;
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedTabs(
              tabs: [Provider.of<LanguageProvider>(context, listen: false).t('convsearch.tabs_chats'), Provider.of<LanguageProvider>(context, listen: false).t('convsearch.tabs_communities')],
              selectedIndex: _selectedTabIndex,
              onTabSelected: (i) => setState(() => _selectedTabIndex = i),
            ),
          ),
          Expanded(child: _buildTabContent(isDark)),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    if (_selectedTabIndex == 0) {
      // Chats tab
      if (_loadingConversations && _allConversations.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (_errorConversations != null && _allConversations.isEmpty) {
        return _errorBox(_errorConversations!);
      }
      if (_controller.text.isEmpty) {
        return _hint(Provider.of<LanguageProvider>(context, listen: false).t('convsearch.start_typing'));
      }
      if (_convResults.isEmpty) {
        return _hint(Provider.of<LanguageProvider>(context, listen: false).t('convsearch.no_match'));
      }
      return RefreshIndicator(
        color: const Color(0xFFBFAE01),
        onRefresh: _loadConversations,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: _convResults.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: const Color(0xFF666666).withValues(alpha: 0.1),
            indent: 64,
          ),
          itemBuilder: (context, index) {
            final c = _convResults[index];
            final avatar = c.otherUser.avatarUrl;
            final name = c.otherUser.name;
            final last = c.lastMessageText ?? _labelType(c.lastMessageType);
            final time = _formatTimeOrDate(c.lastMessageAt);
            final unread = c.unreadCount;

            return InkWell(
              onTap: () async {
                final user = ChatUser(
                  id: c.otherUserId,
                  name: c.otherUser.name,
                  avatarUrl: c.otherUser.avatarUrl,
                  isOnline: true,
                );
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'chat'),
                    builder: (_) => ChatPage(
                      otherUser: user,
                      conversationId: c.id,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildAvatarCircle(name, avatar),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              Text(
                                time,
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
                              Expanded(
                                child: Text(
                                  last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF007AFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unread',
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
      );
    } else {
      // Communities tab
      if (_loadingCommunities && _allCommunities.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (_errorCommunities != null && _allCommunities.isEmpty) {
        return _errorBox(_errorCommunities!);
      }
      if (_controller.text.isEmpty) {
        return _hint(Provider.of<LanguageProvider>(context, listen: false).t('convsearch.start_typing_comm'));
      }
      if (_commResults.isEmpty) {
        return _hint(Provider.of<LanguageProvider>(context, listen: false).t('convsearch.no_match_comm'));
      }
      return RefreshIndicator(
        color: const Color(0xFFBFAE01),
        onRefresh: _loadCommunities,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: _commResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = _commResults[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'community'),
                    builder: (_) => CommunityPage(
                      communityId: c.id,
                      communityName: c.name,
                    ),
                  ),
                );
              },
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
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
                          child: const Icon(Icons.group,
                              color: Color(0xFF666666), size: 24),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF666666).withValues(alpha: 51),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.group,
                              color: Color(0xFF666666), size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF666666),
                            ),
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
      );
    }
  }

  Widget _hint(String text) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF666666),
        ),
      ),
    );
  }

  Widget _errorBox(String text) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.red),
      ),
    );
  }

  Widget _buildAvatarCircle(String name, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF007AFF),
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
    }

  String _labelType(String? t) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    switch ((t ?? '').toLowerCase()) {
      case 'image':
        return lang.t('convsearch.type_photo');
      case 'video':
        return lang.t('convsearch.type_video');
      case 'voice':
        return lang.t('convsearch.type_voice');
      case 'file':
        return lang.t('convsearch.type_file');
      default:
        return '';
    }
  }

String _formatTimeOrDate(DateTime? dt) {
  if (dt == null) return '';
  return TimeUtils.relativeLabel(dt, locale: 'en_short');
}
}