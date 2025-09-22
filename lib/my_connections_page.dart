import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/badge_icon.dart';
import 'widgets/segmented_tabs.dart';
import 'widgets/animated_navbar.dart';
import 'core/users_api.dart';
import 'core/connections_api.dart';
import 'other_user_profile_page.dart';

class MyConnectionUser {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? coverUrl;
  final String avatarLetter;
  final String bio;
  final String status;
  bool youConnectTo; // outbound: you connected to them
  bool theyConnectToYou; // inbound: they connected to you

  MyConnectionUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.coverUrl,
    required this.avatarLetter,
    required this.bio,
    required this.status,
    required this.youConnectTo,
    required this.theyConnectToYou,
  });

  factory MyConnectionUser.fromJson(Map<String, dynamic> json) {
    return MyConnectionUser(
      id: (json['id'] as String?)?.trim() ?? '',
      name: json['name'] ?? 'User',
      username: json['username'] ?? '@user',
      avatarUrl: json['avatarUrl'],
      coverUrl: json['coverUrl'],
      avatarLetter: json['avatarLetter'] ?? 'U',
      bio: json['bio'] ?? '',
      status: json['status'] ?? '',
      youConnectTo:
          false, // Default - can be updated later with connection status
      theyConnectToYou:
          false, // Default - can be updated later with connection status
    );
  }
}

class MyConnectionsPage extends StatefulWidget {
  const MyConnectionsPage({super.key});

  @override
  State<MyConnectionsPage> createState() => _MyConnectionsPageState();
}

class _MyConnectionsPageState extends State<MyConnectionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  List<MyConnectionUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    debugPrint('🔍 MyConnectionsPage: Starting to load users...');
    try {
      final users = await UsersApi().list();
      debugPrint(
        '🔍 MyConnectionsPage: Received ${users.length} users from API',
      );

      final status = await ConnectionsApi().status();
      debugPrint(
        '🔍 MyConnectionsPage: Connection status - Outbound: ${status.outbound.length}, Inbound: ${status.inbound.length}',
      );

      final mapped = users.map((u) => MyConnectionUser.fromJson(u)).toList();

      for (final u in mapped) {
        u.youConnectTo = status.outbound.contains(u.id);
        u.theyConnectToYou = status.inbound.contains(u.id);
        debugPrint(
          '🔍 MyConnectionsPage: User ${u.name} (ID: ${u.id}) - YouConnect: ${u.youConnectTo}, TheyConnect: ${u.theyConnectToYou}',
        );
      }

      if (mounted) {
        setState(() {
          _users = mapped;
          _loading = false;
        });
        debugPrint(
          '🔍 MyConnectionsPage: Successfully loaded ${_users.length} users',
        );
      }
    } catch (e) {
      debugPrint('❌ MyConnectionsPage: Error loading users: $e');
      if (mounted) {
        setState(() {
          _users = []; // Ensure users list is empty on error
          _loading = false;
        });

        // Show error message with retry option
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load connections: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _loadUsers(),
                ),
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInboundList(isDark), // Connected to me
                        _buildOutboundList(isDark), // I Connect
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedNavbar(
        selectedIndex: 0, // mirrors PostPage example
        onTabChange: (index) {
          Navigator.pop(context);
        },
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back button
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
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'My Connections',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
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
                const BadgeIcon(
                  icon: Icons.notifications_outlined,
                  badgeCount: 6,
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
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            // Centered segmented tabs
            Align(
              alignment: Alignment.center,
              child: SegmentedTabs(
                tabs: const ['Connected to me', 'I Connect'],
                selectedIndex: _selectedTabIndex,
                onTabSelected: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                    _tabController.animateTo(index);
                  });
                },
              ),
            ),
            // Back button inside the tab bar area (left)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
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
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Inbound: users who connected to the current user
  Widget _buildInboundList(bool isDark) {
    final inbound = _users.where((u) => u.theyConnectToYou).toList();
    return _listContainer(
      isDark: isDark,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: inbound.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          color: const Color(0xFF666666).withValues(alpha: 26),
          indent: 64,
        ),
        itemBuilder: (context, index) {
          final user = inbound[index];
          return _connectionTile(user, isDark);
        },
      ),
    );
  }

  // Outbound: users the current user connected to
  Widget _buildOutboundList(bool isDark) {
    final outbound = _users.where((u) => u.youConnectTo).toList();
    return _listContainer(
      isDark: isDark,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: outbound.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          color: const Color(0xFF666666).withValues(alpha: 26),
          indent: 64,
        ),
        itemBuilder: (context, index) {
          final user = outbound[index];
          return _connectionTile(user, isDark);
        },
      ),
    );
  }

  Widget _listContainer({required bool isDark, required Widget child}) {
    return Padding(
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
        child: child,
      ),
    );
  }

  Widget _connectionTile(MyConnectionUser user, bool isDark) {
    final secondaryText = const Color(0xFF666666);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherUserProfilePage(
              userId: user.id,
              userName: user.name,
              userAvatarUrl: user.avatarUrl ?? '',
              userBio: user.bio,
              userCoverUrl: user.coverUrl ?? '',
              isConnected: user.youConnectTo,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                  ? Text(
                      user.avatarLetter,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    )
                  : null,
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
                    user.username,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _actionButton(user, isDark),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(MyConnectionUser user, bool isDark) {
    if (user.youConnectTo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Connected',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        final api = ConnectionsApi();
        final next = !user.youConnectTo;
        setState(() {
          user.youConnectTo = next;
        });
        try {
          if (next) {
            await api.connect(user.id);
          } else {
            await api.disconnect(user.id);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              user.youConnectTo = !next;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to ${next ? 'connect' : 'disconnect'}'),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Connect',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
