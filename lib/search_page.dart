import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'widgets/segmented_tabs.dart';
import 'widgets/post_card.dart';
import 'data/sample_data.dart';
import 'models/post.dart';

import 'widgets/community_card.dart';
import 'conversations_page.dart'; // for CommunityItem model
import 'community_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  int _selectedTabIndex = 0;

  late final List<Post> _allPosts;
  late final List<_SearchUser> _allUsers;
  late final List<CommunityItem> _communities;

  @override
  void initState() {
    super.initState();
    _allPosts = SampleData.getSamplePosts();
    _allUsers = [
      _SearchUser(
        'Gia Monroe',
        '@gia_monroe_',
        'https://picsum.photos/200/200?random=301',
      ),
      _SearchUser(
        'Reid Vaughn',
        '@reidv',
        'https://picsum.photos/200/200?random=302',
      ),
      _SearchUser(
        'Blake Lambert',
        '@blakelmbrt',
        'https://picsum.photos/200/200?random=303',
      ),
      _SearchUser(
        'Aiden Blaze',
        '@aidenblaze',
        'https://picsum.photos/200/200?random=304',
        connected: true,
      ),
      _SearchUser(
        'Aiden Frost',
        '@aidenfrost',
        'https://picsum.photos/200/200?random=305',
        connected: true,
      ),
      _SearchUser(
        'Aiden Nova',
        '@aidennova',
        'https://picsum.photos/200/200?random=306',
      ),
      _SearchUser(
        'Aiden Vibe',
        '@aidenvibe',
        'https://picsum.photos/200/200?random=307',
      ),
      _SearchUser(
        'Aiden Wolf',
        '@aidenwolf',
        'https://picsum.photos/200/200?random=308',
      ),
      _SearchUser(
        'Aiden Skye',
        '@aidenskye',
        'https://picsum.photos/200/200?random=309',
      ),
      _SearchUser(
        'Aiden Lux',
        '@aidenlux',
        'https://picsum.photos/200/200?random=310',
      ),
    ];
    _communities = [
      CommunityItem(
        id: 'c1',
        name: 'Farm Harmony',
        avatarUrl: 'https://picsum.photos/200/200?random=351',
        bio: 'Connecting growers, makers, and nature lovers.',
        friendsInCommon: '+102',
        unreadPosts: 0,
      ),
      CommunityItem(
        id: 'c2',
        name: 'PartyPlanet Crew',
        avatarUrl: 'https://picsum.photos/200/200?random=352',
        bio: 'Vibes, dance, and shine together ✨',
        friendsInCommon: '+1K',
        unreadPosts: 0,
      ),
      CommunityItem(
        id: 'c3',
        name: 'Day One Code',
        avatarUrl: 'https://picsum.photos/200/200?random=353',
        bio: 'Builders and makers writing code from day one.',
        friendsInCommon: '+345',
        unreadPosts: 0,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_SearchUser> get _filteredUsers {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.handle.toLowerCase().contains(q),
        )
        .toList();
  }

  List<Post> get _filteredPosts {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return _allPosts;
    return _allPosts
        .where(
          (p) =>
              p.userName.toLowerCase().contains(q) ||
              p.text.toLowerCase().contains(q),
        )
        .toList();
  }

  List<CommunityItem> get _filteredCommunities {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return _communities;
    return _communities
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.bio.toLowerCase().contains(q),
        )
        .toList();
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
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.inter(fontSize: 15),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Search...',
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
                                setState(() {});
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
              tabs: const ['Trending', 'Account', 'Post', 'Community'],
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

  // Trending = a few suggested accounts + a trending post
  Widget _buildTrending(bool isDark) {
    final users = _filteredUsers.take(3).toList();
    final posts = _filteredPosts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        for (int i = 0; i < users.length; i++) ...[
          _UserRowTile(
            user: users[i],
            isDark: isDark,
            onToggleConnect: () =>
                setState(() => users[i].connected = !users[i].connected),
          ),
          if (i < users.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        if (posts.isNotEmpty) PostCard(post: posts.first, isDarkMode: isDark),
      ],
    );
  }

  // Account tab
  Widget _buildAccounts(bool isDark) {
    final users = _filteredUsers;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final u = users[index];
        return _UserRowTile(
          user: u,
          isDark: isDark,
          onToggleConnect: () => setState(() => u.connected = !u.connected),
        );
      },
    );
  }

  // Post tab
  Widget _buildPosts(bool isDark) {
    final posts = _filteredPosts;
    if (posts.isEmpty) {
      return _emptyState('No posts found', isDark);
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
    final communities = _filteredCommunities;
    if (communities.isEmpty) {
      return _emptyState('No communities found', isDark);
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
                builder: (context) => CommunityPage(communityName: c.name),
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

// Simple user model for Search page
class _SearchUser {
  final String name;
  final String handle;
  final String avatarUrl;
  bool connected;

  _SearchUser(this.name, this.handle, this.avatarUrl, {this.connected = false});
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
                      'Connected',
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
                      'Connect',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
