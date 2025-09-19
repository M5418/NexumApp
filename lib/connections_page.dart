import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/outlined_icon_button.dart';
import 'widgets/connection_card.dart';
import 'widgets/message_invite_card.dart';
import 'search_page.dart';
import 'notification_page.dart';

class User {
  final String fullName;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final bool isConnected;

  User({
    required this.fullName,
    required this.bio,
    required this.avatarUrl,
    required this.coverUrl,
    this.isConnected = false,
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

  @override
  void initState() {
    super.initState();
    _generateSampleData();
  }

  void _generateSampleData() {
    final random = Random();

    final firstNames = [
      'Alex',
      'Sarah',
      'Michael',
      'Emma',
      'David',
      'Jessica',
      'James',
      'Ashley',
      'Robert',
      'Amanda',
      'John',
      'Jennifer',
      'William',
      'Lisa',
      'Richard',
      'Michelle',
      'Thomas',
      'Kimberly',
      'Christopher',
      'Amy',
      'Daniel',
      'Angela',
      'Matthew',
      'Brenda',
    ];

    final lastNames = [
      'Johnson',
      'Williams',
      'Brown',
      'Jones',
      'Garcia',
      'Miller',
      'Davis',
      'Rodriguez',
      'Martinez',
      'Hernandez',
      'Lopez',
      'Gonzalez',
      'Wilson',
      'Anderson',
      'Thomas',
      'Taylor',
      'Moore',
      'Jackson',
      'Martin',
      'Lee',
      'Perez',
      'Thompson',
      'White',
      'Harris',
    ];

    final bios = [
      'Co-Founder Nexum',
      'Product Designer',
      'Software Engineer',
      'Photographer',
      'Aviation Enthusiast',
      'Marketing Director',
      'Data Scientist',
      'UX Researcher',
      'Investment Analyst',
      'Startup Mentor',
      'Tech Entrepreneur',
      'Creative Director',
      'Business Strategist',
      'Mobile Developer',
      'Growth Hacker',
      'Content Creator',
      'Digital Nomad',
      'Innovation Lead',
      'Brand Manager',
      'Full Stack Developer',
    ];

    users = List.generate(20, (index) {
      final firstName = firstNames[random.nextInt(firstNames.length)];
      final lastName = lastNames[random.nextInt(lastNames.length)];
      final bio = bios[random.nextInt(bios.length)];

      return User(
        fullName: '$firstName $lastName',
        bio: bio,
        avatarUrl: 'https://picsum.photos/200/200?random=${index + 100}',
        coverUrl: 'https://picsum.photos/400/200?random=${index + 200}',
        isConnected: random.nextBool(),
      );
    });

    // Shuffle the list
    users.shuffle();
  }

  void _refreshData() {
    setState(() {
      _generateSampleData();
    });
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

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
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
            onRefresh: () async {
              _refreshData();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 155 / 240,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ConnectionCard(
                    coverUrl: user.coverUrl,
                    avatarUrl: user.avatarUrl,
                    fullName: user.fullName,
                    bio: user.bio,
                    initialConnectionStatus: user.isConnected,
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
                fullName: activeInviteUser!.fullName,
                bio: activeInviteUser!.bio,
                avatarUrl: activeInviteUser!.avatarUrl,
                coverUrl: activeInviteUser!.coverUrl,
                onClose: _closeInviteCard,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
