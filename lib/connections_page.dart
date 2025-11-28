import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'widgets/outlined_icon_button.dart';
import 'widgets/connection_card.dart'; // used in mobile layout
import 'widgets/message_invite_card.dart';
import 'widgets/badge_icon.dart';
import 'notification_page.dart';
import 'conversations_page.dart';
import 'profile_page.dart';

import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/firebase/firebase_notification_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'repositories/interfaces/podcast_repository.dart';
import 'repositories/interfaces/follow_repository.dart';
import 'core/profile_api.dart';
import 'providers/follow_state.dart';

import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'dart:convert';
import 'widgets/home_post_card.dart';
import 'widgets/activity_post_card.dart';
import 'models/post.dart';
import 'models/message.dart' hide MediaType;
import 'chat_page.dart';
import 'create_post_page.dart';
import 'responsive/responsive_breakpoints.dart';

class User {
  final String id;
  final String fullName;
  final String username;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final bool isConnected;
  final bool theyConnectToYou;

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.coverUrl,
    this.isConnected = false,
    this.theyConnectToYou = false,
  });

  User copyWith({
    String? id,
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    bool? isConnected,
    bool? theyConnectToYou,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      isConnected: isConnected ?? this.isConnected,
      theyConnectToYou: theyConnectToYou ?? this.theyConnectToYou,
    );
  }
}

class ConnectionsPage extends StatefulWidget {
  final bool? isDarkMode;
  final VoidCallback? onThemeToggle;
  final bool hideDesktopTopNav;

  const ConnectionsPage({
    super.key,
    this.isDarkMode,
    this.onThemeToggle,
    this.hideDesktopTopNav = false,
  });

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  // Shared state
  List<User> users = [];
  bool _loading = true;
  String? _error;

  // Desktop: selected user detail
  String? _selectedUserId;

  // Mobile overlay invite
  User? activeInviteUser;

  // Notifications badge
  int _unreadCount = 0;
  
  // ⚡ OPTIMIZATION: Cache user profiles to avoid redundant fetches
  final Map<String, dynamic> _userProfileCache = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadUnreadCount();
  }

  // -----------------------------
  // Data loading
  // -----------------------------
  Future<void> _loadUsers() async {
    try {
      final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        if (!mounted) return;
        setState(() {
          users = [];
          _loading = false;
        });
        return;
      }

      final followRepo = context.read<FollowRepository>();
      final userRepo = FirebaseUserRepository();

      // Fetch ALL followers and following via pagination to avoid missing users
      const pageSize = 500;
      final followers = <dynamic>[];
      final following = <dynamic>[];

      FollowModel? lastFollower;
      while (true) {
        final page = await followRepo.getFollowers(userId: currentUid, limit: pageSize, lastFollow: lastFollower);
        if (page.isEmpty) break;
        followers.addAll(page);
        lastFollower = page.last;
        if (page.length < pageSize) break;
      }

      FollowModel? lastFollowing;
      while (true) {
        final page = await followRepo.getFollowing(userId: currentUid, limit: pageSize, lastFollow: lastFollowing);
        if (page.isEmpty) break;
        following.addAll(page);
        lastFollowing = page.last;
        if (page.length < pageSize) break;
      }

      final inboundIds = followers.map((f) => f.followerId).toSet();
      final outboundIds = following.map((f) => f.followedId).toSet();

      debugPrint('👥 Connection Stats:');
      debugPrint('   Followers (who follow you): ${inboundIds.length}');
      debugPrint('   Following (you follow them): ${outboundIds.length}');

      // ⚡ OPTIMIZATION: Fetch users with caching
      final allProfiles = await userRepo.getSuggestedUsers(limit: 100);

      // Convert to list and filter out current user
      final profiles = allProfiles.where((p) => p.uid != currentUid).toList();

      // ⚡ OPTIMIZATION: Batch fetch all unique user profiles in parallel
      final uniqueUserIds = profiles.map((p) => p.uid).toSet();
      final userProfileFutures = uniqueUserIds.map((userId) async {
        if (_userProfileCache.containsKey(userId)) {
          return MapEntry(userId, _userProfileCache[userId]);
        }
        // Fetch profile if not cached
        final profile = profiles.firstWhere((p) => p.uid == userId);
        _userProfileCache[userId] = profile;
        return MapEntry(userId, profile);
      });
      final cachedProfiles = Map.fromEntries(await Future.wait(userProfileFutures));
      
      if (!mounted) return;

      final mapped = profiles.map((p) {
        final cached = cachedProfiles[p.uid] ?? p;
        final id = cached.uid;
        final name = (cached.displayName ?? '').trim();
        final uname = (cached.username ?? '').trim();
        final bio = (cached.bio ?? '').trim();
        final avatar = (cached.avatarUrl ?? '').trim();
        final cover = (cached.coverUrl ?? '').trim();
        return User(
          id: id,
          fullName: name.isNotEmpty
              ? name
              : ((cached.firstName ?? '').trim().isNotEmpty || (cached.lastName ?? '').trim().isNotEmpty)
                  ? [cached.firstName ?? '', cached.lastName ?? ''].where((s) => (s).trim().isNotEmpty).join(' ').trim()
                  : ((cached.email ?? '').contains('@') ? (cached.email ?? '').split('@').first : 'User'),
          username: uname.isNotEmpty ? (uname.startsWith('@') ? uname : '@$uname') : ((cached.email ?? '').contains('@') ? '@${(cached.email ?? '').split('@').first}' : '@user'),
          bio: bio,
          avatarUrl: avatar,
          coverUrl: cover.isNotEmpty ? cover : avatar,
          isConnected: outboundIds.contains(id),
          theyConnectToYou: inboundIds.contains(id),
        );
      }).toList();

      // ⚡ FILTER: Exclude ONLY mutually connected users
      // Show ALL other users: one-way connections AND no connections
      final filteredUsers = mapped.where((user) {
        // Exclude if BOTH users follow each other (mutual connection)
        final isMutuallyConnected = user.isConnected && user.theyConnectToYou;
        return !isMutuallyConnected; // Show if NOT mutually connected
      }).toList();

      if (!mounted) return;
      setState(() {
        users = List<User>.from(filteredUsers);
        _loading = false;

        if (_selectedUserId == null && kIsWeb && users.isNotEmpty) {
          _selectUser(users.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load users';
        _loading = false;
        users = [];
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final c = await FirebaseNotificationRepository().getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadCount = 0);
    }
  }

  // Map helpers (from UsersApi /api/users/all)

  // -----------------------------
  // Selection + profile details
  // -----------------------------
  void _selectUser(User user) {
  setState(() {
    _selectedUserId = user.id;
  });
}



  User? get _selectedUser => (_selectedUserId == null)
      ? null
      : users.where((u) => u.id == _selectedUserId).cast<User?>().firstOrNull;

  // -----------------------------
  // BUILD
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = widget.isDarkMode ?? themeProvider.isDarkMode;
        final backgroundColor =
            isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

        if (kIsWeb && (context.isDesktop || context.isLargeDesktop)) {
          if (widget.hideDesktopTopNav) {
            return Container(
              color: backgroundColor,
              child: _buildDesktopBody(context, isDark, backgroundColor),
            );
          }
          return _buildDesktop(context, isDark, backgroundColor);
        }
          // Mobile / tablet / non-web
        return _buildMobile(context, isDark, backgroundColor);
      },
    );
  }

  // -----------------------------
  // Desktop Layout
  // -----------------------------
 Widget _buildDesktop(BuildContext context, bool isDark, Color backgroundColor) {
  return Scaffold(
    backgroundColor: backgroundColor,
    body: Stack(
      children: [
        Column(
          children: [
            _buildDesktopTopNav(context, isDark),
            Expanded(child: _buildDesktopBody(context, isDark, backgroundColor)),
          ],
        ),
        Positioned(
          left: 24,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'createPostFabConnections',
            onPressed: () async {
              await CreatePostPage.showPopup<bool>(context);
              // optional: refresh something if needed
            },
            backgroundColor: const Color(0xFFBFAE01),
            foregroundColor: Colors.black,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDesktopBody(BuildContext context, bool isDark, Color backgroundColor) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1280),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: _buildLeftGridPanel(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildRightDetailsPanel(isDark)),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDesktopTopNav(BuildContext context, bool isDark) {
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
              // Row: burger | title | notifications
              Row(
                children: [
                  Icon(Icons.menu, color: const Color(0xFF666666)),
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
                    badgeCount: _unreadCount,
                    iconColor: const Color(0xFF666666),
                    onTap: () async {
                      // Desktop-style: top-right popup
                      final size = MediaQuery.of(context).size;
                      final desktop =
                          kIsWeb && size.width >= 1280 && size.height >= 800;
                      if (desktop) {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.black26,
                          builder: (_) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final double width = 420;
                            final double height = size.height * 0.8;
                            return SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, right: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: Material(
                                        color: isDark
                                            ? const Color(0xFF000000)
                                            : Colors.white,
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
                          MaterialPageRoute(
                              builder: (_) => const NotificationPage()),
                        );
                      }
                      if (!mounted) return;
                      await _loadUnreadCount();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Top nav row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TopNavItem(
                    icon: Icons.home_outlined,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.home'),
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  _TopNavItem(
                    icon: Icons.people_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.connections'),
                    selected: true,
                    onTap: () {},
                  ),
                  _TopNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.conversations'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            initialTabIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  _TopNavItem(
                    icon: Icons.person_outline,
                    label: Provider.of<LanguageProvider>(context, listen: false).t('nav.profile'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftGridPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Provider.of<LanguageProvider>(context).t('connections.people'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                )),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : (_error != null)
                      ? Center(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 155 / 260,
                          ),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final u = users[index];
                            return ConnectionCard(
                              userId: u.id,
                              coverUrl: u.coverUrl,
                              avatarUrl: u.avatarUrl,
                              fullName: u.fullName,
                              username: u.username,
                              bio: u.bio,
                              initialConnectionStatus: u.isConnected,
                              theyConnectToYou: u.theyConnectToYou,
                              onMessage: () {
                                setState(() {
                                  activeInviteUser = u;
                                });
                              },
                              onTap: () => _selectUser(u),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightDetailsPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;

    if (_selectedUser == null) {
      return Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('connections.select_user'),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final u = _selectedUser!;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _RightProfilePanel(user: u, isDark: isDark),
    );
  }

  // -----------------------------
  // Mobile / Non-web Layout
  // -----------------------------
  Widget _buildMobile(
      BuildContext context, bool isDark, Color backgroundColor) {
    final appBarColor = isDark ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: appBarColor,
          elevation: 5,
          automaticallyImplyLeading: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Text(
                    'Connections',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  // Action buttons
                  Row(
                    children: [
                      OutlinedIconButton(
                        icon: Icons.search,
                        onPressed: () {
                          // Search page optional, left as is for parity
                          // Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: () async {
                          final size = MediaQuery.of(context).size;
                          final desktop = kIsWeb &&
                              size.width >= 1280 &&
                              size.height >= 800;
                          if (desktop) {
                            await showDialog(
                              context: context,
                              barrierDismissible: true,
                              barrierColor: Colors.black26,
                              builder: (_) {
                                final isDark = Theme.of(context).brightness ==
                                    Brightness.dark;
                                final double width = 420;
                                final double height = size.height * 0.8;
                                return SafeArea(
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 16, right: 16),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: SizedBox(
                                          width: width,
                                          height: height,
                                          child: Material(
                                            color: isDark
                                                ? const Color(0xFF000000)
                                                : Colors.white,
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
                              MaterialPageRoute(
                                  builder: (_) => const NotificationPage()),
                            );
                          }
                          if (!mounted) return;
                          await _loadUnreadCount();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadUsers,
            child: _loading
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 200),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 1,
                        childAspectRatio: 155 / 260,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ConnectionCard(
                          userId: user.id,
                          coverUrl: user.coverUrl,
                          avatarUrl: user.avatarUrl,
                          fullName: user.fullName,
                          username: user.username,
                          bio: user.bio,
                          initialConnectionStatus: user.isConnected,
                          theyConnectToYou: user.theyConnectToYou,
                          onMessage: () {
                            setState(() {
                              activeInviteUser = user;
                            });
                          },
                        );
                      },
                    ),
                  ),
          ),
          // Message invite overlay (same as your existing page)
          if (activeInviteUser != null) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => activeInviteUser = null),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withValues(alpha: 51)),
                ),
              ),
            ),
            Center(
              child: MessageInviteCard(
                receiverId: activeInviteUser!.id,
                fullName: activeInviteUser!.fullName,
                bio: activeInviteUser!.bio,
                avatarUrl: activeInviteUser!.avatarUrl,
                coverUrl: activeInviteUser!.coverUrl,
                onClose: () => setState(() => activeInviteUser = null),
                onInvitationSent: (_) {
                  setState(() => activeInviteUser = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Invitation sent to ${activeInviteUser!.fullName}')),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------
// Widgets
// --------------------------------------
class _TopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TopNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFBFAE01) : const Color(0xFF666666);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }
}

// Compact user tile for the left grid on desktop
// Removed _UserGridTile in favor of reusing ConnectionCard for parity across mobile and desktop

class _RightProfilePanel extends StatefulWidget {
  final User user;
  final bool isDark;

  const _RightProfilePanel({
    required this.user,
    required this.isDark,
  });

  @override
  State<_RightProfilePanel> createState() => _RightProfilePanelState();
}

class _RightProfilePanelState extends State<_RightProfilePanel> {
  late ConversationRepository _convRepo;


  // Backend profile data for selected user
  Map<String, dynamic>? _userProfile;
  String? _profilePhotoUrl;
  String _coverPhotoUrl = '';

  int _connectionsInboundCount = 0;
  int _connectionsTotalCount = 0;

  List<Map<String, dynamic>> _experiences = [];
  List<Map<String, dynamic>> _trainings = [];
  List<String> _interests = [];

  bool _loadingProfileData = true;

  // Data for tabs
  List<Post> _activityPosts = [];
  bool _loadingActivity = true;
  String? _errorActivity;

  List<Post> _userPosts = [];
  bool _loadingPosts = true;
  String? _errorPosts;

  List<String> _mediaImageUrls = [];
  bool _loadingMedia = true;

  List<Map<String, dynamic>> _podcasts = [];
  bool _loadingPodcasts = true;
  String? _errorPodcasts;

  @override
  void initState() {
    super.initState();
    _convRepo = context.read<ConversationRepository>();
    _loadUserProfile();
    _loadUserPosts();
    _loadActivity();
    _loadPodcasts();
  }

  @override
  void didUpdateWidget(covariant _RightProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _userProfile = null;
      _profilePhotoUrl = null;
      _coverPhotoUrl = '';

      _connectionsInboundCount = 0;
      _connectionsTotalCount = 0;

      _experiences = [];
      _trainings = [];
      _interests = [];

      _activityPosts = [];
      _userPosts = [];
      _mediaImageUrls = [];
      _podcasts = [];

      _errorActivity = null;
      _errorPosts = null;
      _errorPodcasts = null;

      _loadingProfileData = true;
      _loadingActivity = true;
      _loadingPosts = true;
      _loadingMedia = true;
      _loadingPodcasts = true;

      // Refetch all sections for the newly selected user
      _loadUserProfile();
      _loadUserPosts();
      _loadActivity();
      _loadPodcasts();
    }
  }

  // ---------- Helpers ----------
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final i = int.tryParse(v);
      if (i != null) return i;
    }
    return 0;
  }

  List<Map<String, dynamic>> _parseListOfMap(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  List<String> _parseStringList(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  String _formatCount(dynamic v) {
    final n = _toInt(v);
    if (n >= 1000000) {
      final m = n / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  // ---------- Loaders ----------
  Future<void> _loadUserProfile() async {
    final started = DateTime.now();
    try {
      final api = ProfileApi();
      final res = await api.getByUserId(widget.user.id);
      final body = Map<String, dynamic>.from(res);
      final data = Map<String, dynamic>.from(body['data'] ?? {});

      final experiences = _parseListOfMap(data['professional_experiences']);
      final trainings = _parseListOfMap(data['trainings']);
      final interests = _parseStringList(data['interest_domains']);

      final profileUrl = (data['profile_photo_url'] ?? '').toString();
      final coverUrl = (data['cover_photo_url'] ?? '').toString();

      // Ensure spinner is visible for at least 700ms
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }

      if (!mounted) return;
      setState(() {
        _userProfile = data;
        _profilePhotoUrl = profileUrl.isNotEmpty ? profileUrl : null;
        _coverPhotoUrl =
            coverUrl.isNotEmpty ? coverUrl : (widget.user.coverUrl);
        _experiences = experiences;
        _trainings = trainings;
        _interests = interests;

        _connectionsInboundCount = _toInt(data['connections_inbound_count']);
        _connectionsTotalCount = _toInt(data['connections_total_count']);

        _loadingProfileData = false;
      });
    } catch (_) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }
      if (!mounted) return;
      setState(() {
        _loadingProfileData = false;
      });
    }
  }


  Future<void> _loadUserPosts() async {
    setState(() {
      _loadingPosts = true;
      _errorPosts = null;
      _loadingMedia = true;
    });

    final started = DateTime.now();

    try {
      // Fetch user's posts from Firestore
      final repo = FirebasePostRepository();
      final models = await repo.getUserPosts(uid: widget.user.id, limit: 50);
      final posts = models.map((m) => Post(
        id: m.id,
        authorId: m.authorId,
        userName: widget.user.fullName,
        userAvatarUrl: widget.user.avatarUrl,
        createdAt: m.createdAt,
        text: m.text,
        mediaType: m.mediaUrls.isEmpty ? MediaType.none : (m.mediaUrls.length == 1 ? MediaType.image : MediaType.images),
        imageUrls: m.mediaUrls,
        videoUrl: null,
        counts: PostCounts(
          likes: m.summary.likes,
          comments: m.summary.comments,
          shares: m.summary.shares,
          reposts: m.summary.reposts,
          bookmarks: m.summary.bookmarks,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: (m.repostOf != null && m.repostOf!.isNotEmpty),
        repostedBy: null,
        originalPostId: m.repostOf,
      )).toList();

      final urls = <String>{};
      for (final post in posts) {
        if (post.isRepost) continue;
        if (post.mediaType == MediaType.image && post.imageUrls.isNotEmpty) {
          urls.add(post.imageUrls.first);
        } else if (post.mediaType == MediaType.images && post.imageUrls.isNotEmpty) {
          urls.addAll(post.imageUrls);
        }
      }

      // Ensure spinner is visible for at least 700ms
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }

      if (!mounted) return;
      setState(() {
        _userPosts = posts;
        _mediaImageUrls = urls.toList();
        _loadingPosts = false;
        _loadingMedia = false;
      });
    } catch (_) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }
      if (!mounted) return;
      setState(() {
        _errorPosts = 'Failed to load posts';
        _loadingPosts = false;
        _loadingMedia = false;
      });
    }
  }

  Future<void> _loadActivity() async {
    setState(() {
      _loadingActivity = true;
      _errorActivity = null;
    });

    final started = DateTime.now();

    try {
      // For now, surface recent posts as activity
      final repo = FirebasePostRepository();
      final models = await repo.getUserPosts(uid: widget.user.id, limit: 50);
      final results = models.map((m) => Post(
        id: m.id,
        authorId: m.authorId,
        userName: widget.user.fullName,
        userAvatarUrl: widget.user.avatarUrl,
        createdAt: m.createdAt,
        text: m.text,
        mediaType: m.mediaUrls.isEmpty ? MediaType.none : (m.mediaUrls.length == 1 ? MediaType.image : MediaType.images),
        imageUrls: m.mediaUrls,
        videoUrl: null,
        counts: PostCounts(
          likes: m.summary.likes,
          comments: m.summary.comments,
          shares: m.summary.shares,
          reposts: m.summary.reposts,
          bookmarks: m.summary.bookmarks,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: (m.repostOf != null && m.repostOf!.isNotEmpty),
        repostedBy: null,
        originalPostId: m.repostOf,
      )).toList();

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Ensure spinner is visible for at least 700ms
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }

      if (!mounted) return;
      setState(() {
        _activityPosts = results;
        _loadingActivity = false;
      });
    } catch (_) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }
      if (!mounted) return;
      setState(() {
        _errorActivity = 'Failed to load activity';
        _loadingActivity = false;
      });
    }
  }

  Future<void> _loadPodcasts() async {
    setState(() {
      _loadingPodcasts = true;
      _errorPodcasts = null;
    });

    final started = DateTime.now();

    try {
      final podcastRepo = context.read<PodcastRepository>();
      final podcastModels = await podcastRepo.listPodcasts(
        authorId: widget.user.id,
        limit: 50,
        page: 1,
      );
      final podcasts = podcastModels
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'coverUrl': p.coverUrl,
                'durationSec': p.durationSec,
              })
          .toList();

      // Ensure spinner is visible for at least 700ms
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }

      if (!mounted) return;
      setState(() {
        _podcasts = podcasts;
        _loadingPodcasts = false;
      });
    } catch (_) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 700)) {
        await Future.delayed(const Duration(milliseconds: 700) - elapsed);
      }
      if (!mounted) return;
      setState(() {
        _errorPodcasts = 'Failed to load podcasts';
        _loadingPodcasts = false;
      });
    }
  }

  // ---------- Actions ----------
  Future<void> _handleMessageUser() async {
    final ctx = context;
    try {
      final conversationId = await _convRepo.checkConversationExists(
        widget.user.id,
      );

      if (!ctx.mounted) return;

      if (conversationId != null) {
        final chatUser = ChatUser(
          id: widget.user.id,
          name: widget.user.fullName,
          avatarUrl: widget.user.avatarUrl,
        );
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              otherUser: chatUser,
              isDarkMode: widget.isDark,
              conversationId: conversationId,
            ),
          ),
        );
      } else {
        _showMessageBottomSheet(ctx);
      }
    } catch (_) {
      if (ctx.mounted) _showMessageBottomSheet(ctx);
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
          receiverId: widget.user.id,
          fullName: widget.user.fullName,
          bio: widget.user.bio,
          avatarUrl: widget.user.avatarUrl,
          coverUrl:
              _coverPhotoUrl.isNotEmpty ? _coverPhotoUrl : widget.user.coverUrl,
          onClose: () => Navigator.pop(ctx),
          onInvitationSent: (_) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                  content: Text('${Provider.of<LanguageProvider>(ctx, listen: false).t('connections.invitation_sent')} ${widget.user.fullName}')),
            );
          },
        ),
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final String displayName = (() {
      final p = _userProfile ?? {};
      final fullName = (p['full_name'] ?? '').toString().trim();
      if (fullName.isNotEmpty) return fullName;
      return widget.user.fullName;
    })();
    final String atUsername = (() {
      final p = _userProfile ?? {};
      final u = (p['username'] ?? '').toString().trim();
      return u.isNotEmpty ? '@$u' : widget.user.username;
    })();

    final String coverUrl =
        _coverPhotoUrl.isNotEmpty ? _coverPhotoUrl : widget.user.coverUrl;
    final String profileUrl =
        (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
            ? _profilePhotoUrl!
            : widget.user.avatarUrl;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover
          Container(
            height: 200,
            decoration: BoxDecoration(
              image: (coverUrl.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(coverUrl), fit: BoxFit.cover)
                  : null,
              color: coverUrl.isEmpty
                  ? (isDark ? Colors.black : Colors.grey[300])
                  : null,
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
                // Avatar + stats + name + bio
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar overlap
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
                            backgroundImage: profileUrl.isNotEmpty
                                ? NetworkImage(profileUrl)
                                : null,
                            child: profileUrl.isEmpty
                                ? Text(
                                    (displayName.isNotEmpty
                                            ? displayName[0]
                                            : 'U')
                                        .toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Stats
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatColumn(
                                _formatCount(_connectionsTotalCount),
                                'Connections'),
                            const SizedBox(width: 40),
                            _buildStatColumn(
                                _formatCount(_connectionsInboundCount),
                                'Connected'),
                          ],
                        ),
                      ),

                      // Name + @ + bio
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.verified,
                                    color: Color(0xFFBFAE01), size: 20),
                              ],
                            ),
                            if (atUsername.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  atUsername,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              widget.user.bio,
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

                      // Actions
                      Transform.translate(
                        offset: const Offset(0, -10),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final ctx = context;
                                  try {
                                    await ctx.read<FollowState>().toggle(widget.user.id);
                                  } catch (_) {
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('connections.action_failed'))),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.watch<FollowState>().isConnected(widget.user.id)
                                      ? Colors.grey[300]
                                      : const Color(0xFFBFAE01),
                                  foregroundColor: context.watch<FollowState>().isConnected(widget.user.id)
                                      ? Colors.black87
                                      : Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25)),
                                ),
                                child: Text(
                                  context.watch<FollowState>().isConnected(widget.user.id)
                                      ? Provider.of<LanguageProvider>(context).t('connections.disconnect')
                                      : ((widget.user.theyConnectToYou || context.watch<FollowState>().theyConnectToYou(widget.user.id))
                                          ? Provider.of<LanguageProvider>(context).t('connections.connect_back')
                                          : Provider.of<LanguageProvider>(context).t('connections.connect')),
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handleMessageUser,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25)),
                                  side: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF000000)
                                          : Colors.grey[300]!),
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
                                        : Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: const Icon(Icons.person_add_outlined,
                                  size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Professional Experiences
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work,
                              size: 20,
                              color:
                                  isDark ? Colors.grey[300] : Colors.black87),
                          const SizedBox(width: 8),
                          Text(Provider.of<LanguageProvider>(context).t('connections.professional_experiences'),
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loadingProfileData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_experiences.isEmpty)
                        Text(Provider.of<LanguageProvider>(context).t('connections.no_experiences'),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600]))
                      else
                        ..._experiences.expand((exp) => [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                    (exp['title'] ?? 'Experience').toString(),
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ),
                              if (exp['subtitle'] != null &&
                                  exp['subtitle'].toString().isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(exp['subtitle'].toString(),
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600])),
                                ),
                              const SizedBox(height: 8),
                            ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Trainings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school,
                              size: 20,
                              color:
                                  isDark ? Colors.grey[300] : Colors.black87),
                          const SizedBox(width: 8),
                          Text(Provider.of<LanguageProvider>(context).t('connections.trainings'),
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loadingProfileData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_trainings.isEmpty)
                        Text(Provider.of<LanguageProvider>(context).t('connections.no_trainings'),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600]))
                      else
                        ..._trainings.expand((t) => [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                    (t['title'] ?? 'Training').toString(),
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ),
                              if (t['subtitle'] != null &&
                                  t['subtitle'].toString().isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(t['subtitle'].toString(),
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600])),
                                ),
                              const SizedBox(height: 8),
                            ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Interests
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite,
                              size: 20,
                              color:
                                  isDark ? Colors.grey[300] : Colors.black87),
                          const SizedBox(width: 8),
                          Text(Provider.of<LanguageProvider>(context).t('connections.interests'),
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loadingProfileData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_interests.isEmpty)
                        Text(Provider.of<LanguageProvider>(context).t('connections.no_interests'),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600]))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _interests
                              .map((i) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF2A2A2A)
                                              : Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(i,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs: Activity / Posts / Podcasts / Media
          _buildTabSection(isDark),
        ],
      ),
    );
  }

  // ---------- Small UI helpers ----------
  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value,
            style:
                GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
      ],
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
              unselectedLabelColor: const Color(0xFF666666),
              labelStyle:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              unselectedLabelStyle:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
              tabs: [
                Tab(text: Provider.of<LanguageProvider>(context).t('connections.activity')),
                Tab(text: Provider.of<LanguageProvider>(context).t('connections.posts')),
                Tab(text: Provider.of<LanguageProvider>(context).t('connections.podcasts')),
                Tab(text: Provider.of<LanguageProvider>(context).t('connections.media')),
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
    if (_loadingActivity) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorActivity != null) {
      return Center(child: Text(_errorActivity!));
    }
    if (_activityPosts.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('connections.no_activity')));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _activityPosts.length,
      itemBuilder: (context, index) {
        return ActivityPostCard(
          post: _activityPosts[index],
          onReactionChanged: (postId, reaction) {},
          onBookmarkToggle: (postId) {},
          onShare: (postId) {},
          onComment: (postId) {},
          onRepost: (postId) {},
        );
      },
    );
  }

  Widget _buildPostsTab(bool isDark) {
    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPosts != null) {
      return Center(child: Text(_errorPosts!));
    }
    if (_userPosts.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('connections.no_posts')));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        return HomePostCard(
          post: _userPosts[index],
          onReactionChanged: (postId, reaction) {},
          onBookmarkToggle: (postId) {},
          onShare: (postId) {},
          onComment: (postId) {},
          onRepost: (postId) {},
        );
      },
    );
  }

  Widget _buildPodcastsTab(bool isDark) {
    if (_loadingPodcasts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPodcasts != null) {
      return Center(child: Text(_errorPodcasts!));
    }
    if (_podcasts.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('connections.no_podcasts')));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: _podcasts.length,
      itemBuilder: (context, index) {
        final podcast = _podcasts[index];
        return _buildPodcastItem(
          (podcast['title'] ?? 'Untitled').toString(),
          (podcast['description'] ?? 'No description').toString(),
          '${podcast['durationSec'] ?? 0}s',
          (podcast['coverUrl'] ?? '').toString(),
          isDark,
        );
      },
    );
  }

  Widget _buildPodcastItem(
    String title,
    String description,
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
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                    width: 60, height: 60, fit: BoxFit.cover)
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          isDark ? Colors.grey[300] : const Color(0xFF666666)),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          isDark ? Colors.grey[300] : const Color(0xFF999999)),
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
    if (_loadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mediaImageUrls.isEmpty) {
      return Center(child: Text(Provider.of<LanguageProvider>(context).t('connections.no_media')));
    }
    return GridView.count(
      primary: false,
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: _mediaImageUrls.map((imageUrl) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(imageUrl, fit: BoxFit.cover),
        );
      }).toList(),
    );
  }
}


// Iterable helper
extension IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
