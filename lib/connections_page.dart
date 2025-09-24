import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/outlined_icon_button.dart';
import 'widgets/connection_card.dart';
import 'widgets/message_invite_card.dart';
import 'search_page.dart';
import 'notification_page.dart';
import 'core/users_api.dart';
import 'core/connections_api.dart';

class User {
  final String id;
  final String fullName;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final bool isConnected;
  final bool theyConnectToYou;

  User({
    required this.id,
    required this.fullName,
    required this.bio,
    required this.avatarUrl,
    required this.coverUrl,
    this.isConnected = false,
    this.theyConnectToYou = false,
  });
}

class ConnectionsPage extends StatefulWidget {
  final bool? isDarkMode;
  final VoidCallback? onThemeToggle;

  const ConnectionsPage({super.key, this.isDarkMode, this.onThemeToggle});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  List<User> users = [];
  User? activeInviteUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    debugPrint('🔍 ConnectionsPage: Starting to load users...');
    try {
      final usersData = await UsersApi().list();
      debugPrint(
        '🔍 ConnectionsPage: Received ${usersData.length} users from API',
      );

      final status = await ConnectionsApi().status();
      debugPrint(
        '🔍 ConnectionsPage: Connection status - Outbound: ${status.outbound.length}, Inbound: ${status.inbound.length}',
      );

      final mapped = usersData.map((m) {
        final id = (m['id'] as String?)?.trim();
        final name = (m['name'] as String?)?.trim();
        final username = (m['username'] as String?)?.trim();
        final email = (m['email'] as String?)?.trim();

        // Improved name fallback logic
        String fullName = 'User';
        if (name != null && name.isNotEmpty) {
          fullName = name;
        } else if (username != null && username.isNotEmpty) {
          fullName = username.replaceAll('@', '');
        } else if (email != null && email.isNotEmpty) {
          fullName = email.split('@')[0];
        }

        final user = User(
          id: id ?? '',
          fullName: fullName,
          bio: (m['bio'] as String?) ?? '',
          avatarUrl: (m['avatarUrl'] as String?)?.trim() ?? '',
          coverUrl: (m['coverUrl'] as String?)?.trim() ?? '',
          isConnected: status.outbound.contains(id),
          theyConnectToYou: status.inbound.contains(id),
        );

        debugPrint(
          '🔍 ConnectionsPage: Mapped user - ID: ${user.id}, Name: ${user.fullName}, Connected: ${user.isConnected}, They Connect To You: ${user.theyConnectToYou}',
        );
        return user;
      }).toList();

      if (mounted) {
        setState(() {
          users = List<User>.from(mapped);
          _loading = false;
        });
        debugPrint(
          '🔍 ConnectionsPage: Successfully loaded ${users.length} users',
        );
      }
    } catch (e) {
      debugPrint('❌ ConnectionsPage: Error loading users: $e');
      if (mounted) {
        setState(() {
          users = []; // Ensure users list is empty on error
          _loading = false;
        });

        // Show more detailed error message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load users: ${e.toString()}'),
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

  void _showInviteCard(User user) {
    setState(() {
      activeInviteUser = user;
    });
  }

  void _closeInviteCard() {
    setState(() {
      activeInviteUser = null;
    });
  }

  Future<void> _refreshData() async {
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationPage(),
                            ),
                          );
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
          // Main content
          RefreshIndicator(
            onRefresh: _refreshData,
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
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 155 / 240,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ConnectionCard(
                          userId: user.id,
                          coverUrl: user.coverUrl,
                          avatarUrl: user.avatarUrl,
                          fullName: user.fullName,
                          bio: user.bio,
                          initialConnectionStatus: user.isConnected,
                          theyConnectToYou: user.theyConnectToYou,
                          onMessage: () => _showInviteCard(user),
                        );
                      },
                    ),
                  ),
          ),

          // Blur overlay when invite card is active
          if (activeInviteUser != null) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeInviteCard,
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
                onClose: _closeInviteCard,
                onInvitationSent: (invitation) {
                  debugPrint('Invitation sent: ${invitation.id}');
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
