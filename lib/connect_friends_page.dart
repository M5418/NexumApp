import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'core/i18n/language_provider.dart';
import 'providers/follow_state.dart';

import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'responsive/responsive_breakpoints.dart';
import 'other_user_profile_page.dart';
import 'profile_page.dart';
import 'home_feed_page.dart';
import 'core/admin_config.dart';

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

  // Loaded from backend
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  Future<void> _loadUsers() async {
    debugPrint('🔍 ConnectFriendsPage: Starting to load users...');
    try {
      final userRepo = FirebaseUserRepository();
      
      // Get suggested users
      final userModels = await userRepo.getSuggestedUsers(limit: 50);
      final users = userModels.map((u) => {
        'id': u.uid,
        'name': u.displayName ?? u.username ?? 'User',
        'username': u.username,
        'profile_photo_url': u.avatarUrl,
        'bio': u.bio,
      }).toList();

      if (mounted) {
        setState(() {
          _friends = users;
          _loading = false;
        });
        debugPrint('🔍 ConnectFriendsPage: Successfully loaded ${_friends.length} users');
      }
    } catch (e) {
      debugPrint('❌ ConnectFriendsPage: Error loading users: $e');
      if (mounted) {
        setState(() {
          _friends = [];
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
    try {
      await context.read<FollowState>().toggle(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('connect_friends.action_failed')),
          ),
        );
      }
    }
  }

  Future<void> _sendWelcomeMessage() async {
    try {
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final conversationRepo = context.read<ConversationRepository>();
      final userRepo = FirebaseUserRepository();
      final db = FirebaseFirestore.instance;

      // Check if official account exists
      final officialAccount = await userRepo.getUserProfile(AdminConfig.adminUserId);
      if (officialAccount == null) {
        debugPrint('⚠️ Nexum official account not found, skipping welcome message');
        return;
      }

      // Create or get conversation with Nexum official account
      final conversationId = await conversationRepo.createOrGet(AdminConfig.adminUserId);
      debugPrint('📝 Conversation created/retrieved: $conversationId');

      // Get user's first name for personalized greeting
      final userName = widget.firstName.isNotEmpty ? widget.firstName : 'there';

      // Get official account details for the message
      final officialName = officialAccount.displayName ?? 'Nexum';
      final officialAvatar = officialAccount.avatarUrl ?? '';

      // Send welcome message
      final welcomeText = '''👋 Hi $userName!

Welcome to Nexum! We're thrilled to have you here.

🎉 Your account is all set up and ready to go. Here's what you can do:

• 📝 Share your thoughts and connect with others
• 📚 Explore books and podcasts
• 💬 Start conversations and build your network
• 🎯 Discover content tailored to your interests

If you have any questions or need help, feel free to reach out to us anytime.

Happy connecting! 🚀''';

      // Create message document directly in Firestore (sent by official account)
      final messageData = {
        'conversationId': conversationId,
        'senderId': AdminConfig.adminUserId,
        'senderName': officialName,
        'senderAvatarUrl': officialAvatar,
        'content': welcomeText,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': [],
        'attachments': [],
        'isStarred': false,
      };

      await db.collection('messages').add(messageData);

      // Update conversation summary
      await db.collection('conversations').doc(conversationId).set({
        'lastMessageType': 'text',
        'lastMessageText': welcomeText.length > 100 
            ? '${welcomeText.substring(0, 100)}...' 
            : welcomeText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastFromUserId': AdminConfig.adminUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unread.${currentUser.uid}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      debugPrint('✅ Welcome message sent successfully to $userName');
    } catch (e) {
      debugPrint('❌ Error sending welcome message: $e');
      // Don't block account creation if welcome message fails
    }
  }

  Future<void> _completeAccountCreation() async {
    // Send welcome message from Nexum official account
    await _sendWelcomeMessage();

    // Navigate to home feed
    if (!mounted) return;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FollowState>().initialize();
    });
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
                          Provider.of<LanguageProvider>(context).t('connect_friends.title'),
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
                            Provider.of<LanguageProvider>(context).t('connect_friends.title'),
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
                    final bool isConnected = context.watch<FollowState>().isConnected(userId);

                    return GestureDetector(
                      onTap: () {
                        final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
                        if (currentUserId == userId) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfilePage()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtherUserProfilePage(
                                userId: userId,
                                userName: user['name'] as String? ?? 'Unknown',
                                userAvatarUrl: user['avatarUrl'] as String? ?? '',
                                userBio: '',
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
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
                                isConnected ? Provider.of<LanguageProvider>(context).t('connections.connected') : Provider.of<LanguageProvider>(context).t('connections.connect'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          ],
                        ),
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