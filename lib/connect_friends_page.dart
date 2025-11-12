import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';

import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/firebase/firebase_follow_repository.dart';
import 'responsive/responsive_breakpoints.dart';
import 'home_feed_page.dart';

class ConnectFriendsPage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ConnectFriendsPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ConnectFriendsPage> createState() => _ConnectFriendsPageState();
}

class _ConnectFriendsPageState extends State<ConnectFriendsPage> {
  // Track connection status for each friend
  final Map<String, bool> _connectionStatus = {};

  // Loaded from backend
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  Future<void> _loadUsers() async {
    debugPrint('🔍 ConnectFriendsPage: Starting to load users...');
    try {
      final userRepo = FirebaseUserRepository();
      final followRepo = FirebaseFollowRepository();
      
      // Get suggested users
      final userModels = await userRepo.getSuggestedUsers(limit: 50);
      final users = userModels.map((u) => {
        'id': u.uid,
        'name': u.displayName ?? u.username ?? 'User',
        'username': u.username,
        'profile_photo_url': u.avatarUrl,
        'bio': u.bio,
      }).toList();

      // Fetch current connections
      final connectionsStatus = await followRepo.getConnectionsStatus();
      final outbound = connectionsStatus.outbound;

      if (mounted) {
        setState(() {
          _friends = users;
          _connectionStatus.clear();
          for (final u in users) {
            final id = u['id'] as String;
            final isConnected = outbound.contains(id);
            _connectionStatus[id] = isConnected;
            debugPrint('🔍 ConnectFriendsPage: User ${u['name']} (ID: $id) - Connected: $isConnected');
          }
          _loading = false;
        });
        debugPrint('🔍 ConnectFriendsPage: Successfully loaded ${_friends.length} users');
      }
    } catch (e) {
      debugPrint('❌ ConnectFriendsPage: Error loading users: $e');
      if (mounted) {
        setState(() {
          _friends = [];
          _connectionStatus.clear();
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('connect_friends.load_failed')}: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: Provider.of<LanguageProvider>(context, listen: false).t('common.retry'),
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

  Future<void> _toggleConnection(String userId) async {
    final followRepo = FirebaseFollowRepository();
    final connected = _connectionStatus[userId] ?? false;
    final next = !connected;
    setState(() {
      _connectionStatus[userId] = next;
    });
    try {
      if (next) {
        await followRepo.followUser(userId);
      } else {
        await followRepo.unfollowUser(userId);
      }
    } catch (e) {
      setState(() {
        _connectionStatus[userId] = !next;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('connect_friends.action_failed')),
          ),
        );
      }
    }
  }

  void _completeAccountCreation() {
    final next = const HomeFeedPage();
    if (context.isMobile) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => next),
        (route) => false,
      );
    } else {
      _pushAndRemoveAllWithPopup(context, next);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: original full-screen layout
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Connect with Friends',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _contentBody(context, isDark),
          ),
        ),
      );
    }

    // DESKTOP/TABLET/LARGE DESKTOP: centered popup card
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: isDark ? const Color(0xFF000000) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header (replaces app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connect with Friends',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0x1A666666)),

                      const SizedBox(height: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _contentBody(context, isDark, desktop: true),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _completeAccountCreation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBFAE01),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contentBody(BuildContext context, bool isDark, {bool desktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!desktop) const SizedBox(height: 8),
        Text(
          'Find and connect with friends to see what they\'re up to.',
          style: GoogleFonts.inter(
            fontSize: desktop ? 15 : 16,
            color: const Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final user = _friends[index];
                    final String userId = user['id'] as String;
                    final bool isConnected = _connectionStatus[userId] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          // Profile Avatar
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: (user['avatarUrl'] != null && (user['avatarUrl'] as String).isNotEmpty)
                                ? NetworkImage(user['avatarUrl'] as String)
                                : null,
                            child: (user['avatarUrl'] == null || (user['avatarUrl'] as String).isEmpty)
                                ? Text(
                                    (user['avatarLetter'] ?? 'U').toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),

                          // Name and Username
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (user['name'] ?? 'User').toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (user['username'] ?? '').toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Connect/Connected Button
                          SizedBox(
                            width: 100,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => _toggleConnection(userId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected ? Colors.transparent : Colors.black,
                                foregroundColor: isConnected ? Colors.black : Colors.white,
                                elevation: 0,
                                side: isConnected ? const BorderSide(color: Color(0xFFE0E0E0), width: 1) : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              child: Text(
                                isConnected ? 'Connected' : 'Connect',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (!desktop) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _completeAccountCreation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBFAE01),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _pushAndRemoveAllWithPopup(BuildContext context, Widget page) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
      (route) => false,
    );
  }
}