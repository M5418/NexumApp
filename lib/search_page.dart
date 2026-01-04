import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'providers/follow_state.dart';

import 'widgets/post_card.dart';
import 'widgets/segmented_tabs.dart';
import 'core/i18n/language_provider.dart';
import 'models/post.dart';

import 'widgets/community_card.dart';
import 'conversations_page.dart'; // for CommunityItem model
import 'community_page.dart';
import 'other_user_profile_page.dart';
import 'profile_page.dart';

import 'repositories/firebase/firebase_search_repository.dart';
import 'repositories/interfaces/search_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  int _selectedTabIndex = 0;

  final FirebaseSearchRepository _searchRepo = FirebaseSearchRepository();

  bool _loading = false;
  String? _error;

  List<SearchUser> _accounts = const [];
  List<Post> _posts = const [];
  List<CommunityItem> _communities = const [];

  // Connection state is managed globally by FollowState

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // No initial fetch until user types.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FollowState>().initialize();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _accounts = const [];
        _posts = const [];
        _communities = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _searchRepo.search(query: q, limit: 12);
      if (!mounted) return;
      setState(() {
        _accounts = result.users;
        _posts = result.posts;
        _communities = result.communities
            .map((c) => CommunityItem(
                  id: c.id,
                  name: c.name,
                  avatarUrl: c.avatarUrl,
                  bio: c.bio,
                  friendsInCommon: '+0',
                  unreadPosts: 0,
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
                  // Search field (pill)
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
                                hintText: Provider.of<LanguageProvider>(context).t('search.hint'),
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
                                  _accounts = const [];
                                  _posts = const [];
                                  _communities = const [];
                                  _error = null;
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
          // Tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedTabs(
              tabs: [
                Provider.of<LanguageProvider>(context).t('search.trending'),
                Provider.of<LanguageProvider>(context).t('search.account'),
                Provider.of<LanguageProvider>(context).t('search.post'),
                Provider.of<LanguageProvider>(context).t('search.community'),
              ],
              selectedIndex: _selectedTabIndex,
              onTabSelected: (i) => setState(() => _selectedTabIndex = i),
            ),
          ),
          // Content
          Expanded(child: _buildTabContent(isDark)),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.red),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    switch (_selectedTabIndex) {
      case 0:
        return _buildTrending(isDark);
      case 1:
        return _buildAccounts(isDark);
      case 2:
        return _buildPosts(isDark);
      case 3:
      default:
        return _buildCommunities(isDark);
    }
  }

  // Trending
  Widget _buildTrending(bool isDark) {
    return Center(
      child: Text(
        Provider.of<LanguageProvider>(context).t('search.coming_soon'),
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF666666),
        ),
      ),
    );
  }

  // Account tab
  Widget _buildAccounts(bool isDark) {
    final users = _accounts;
    final follow = context.watch<FollowState>();
    if (_controller.text.isEmpty) {
      return _emptyState(Provider.of<LanguageProvider>(context).t('search.start_typing_accounts'), isDark);
    }
    if (users.isEmpty) {
      return _emptyState(Provider.of<LanguageProvider>(context).t('search.no_accounts'), isDark);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final u = users[index];
        final isConnected = follow.isConnected(u.id);
        final vm = _SearchUser(
          u.id,
          u.name,
          u.username,
          u.avatarUrl ?? '',
          connected: isConnected,
        );
        return _UserRowTile(
          user: vm,
          isDark: isDark,
          onToggleConnect: () async {
            final messenger = ScaffoldMessenger.of(context);
            final errorMessage = Provider.of<LanguageProvider>(context, listen: false).t('my_connections.action_failed');
            try {
              await context.read<FollowState>().toggle(u.id);
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(errorMessage)),
              );
            }
          },
        );
      },
    );
  }

  // Post tab
  Widget _buildPosts(bool isDark) {
    final posts = _posts;
    if (_controller.text.isEmpty) {
      return _emptyState(Provider.of<LanguageProvider>(context).t('search.start_typing_posts'), isDark);
    }
    if (posts.isEmpty) {
      return _emptyState(Provider.of<LanguageProvider>(context).t('search.no_posts'), isDark);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return PostCard(post: posts[index], isDarkMode: isDark);
      },
    );
  }

  // Community tab
  Widget _buildCommunities(bool isDark) {
    final communities = _communities;
    if (_controller.text.isEmpty) {
      return _emptyState(Provider.of<LanguageProvider>(context).t('search.start_typing_communities'), isDark);
    }
    if (communities.isEmpty) {
      return _emptyState(Provider.of<LanguageProvider>(context).t('search.no_communities'), isDark);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: communities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = communities[index];
        return CommunityCard(
          community: c,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'community'),
                builder: (context) => CommunityPage(
                  communityId: c.id,
                  communityName: c.name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState(String text, bool isDark) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF666666)),
      ),
    );
  }
}

// Simple user model used by the existing row tile
class _SearchUser {
  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  bool connected;

  _SearchUser(this.id, this.name, this.handle, this.avatarUrl, {this.connected = false});
}

// Row tile (avatar + name/handle + Connect/Connected button)
class _UserRowTile extends StatelessWidget {
  final _SearchUser user;
  final bool isDark;
  final VoidCallback onToggleConnect;

  const _UserRowTile({
    required this.user,
    required this.isDark,
    required this.onToggleConnect,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId == user.id) {
            Navigator.push(
              context,
              MaterialPageRoute(settings: const RouteSettings(name: 'other_user_profile'), builder: (context) => const ProfilePage()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'other_user_profile'),
                builder: (context) => OtherUserProfilePage(
                  userId: user.id,
                  userName: user.name,
                  userAvatarUrl: user.avatarUrl,
                  userBio: '',
                ),
              ),
            );
          }
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CachedNetworkImage(
                imageUrl: user.avatarUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF666666).withValues(alpha: 0),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF666666)),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF666666).withValues(alpha: 0),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF666666)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.handle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
            height: 34,
            child: user.connected
                ? OutlinedButton(
                    onPressed: onToggleConnect,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF666666),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      Provider.of<LanguageProvider>(context).t('connections.connected'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: onToggleConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      Provider.of<LanguageProvider>(context).t('connections.connect'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}