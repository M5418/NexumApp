import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'widgets/post_card.dart';
import 'widgets/home_post_card.dart';
import 'models/post.dart';
import 'settings_page.dart';
import 'insights_page.dart';
import 'theme_provider.dart';
import 'my_connections_page.dart';
import 'edit_profil.dart';
import 'monetization_page.dart';
import 'premium_subscription_page.dart';
import 'core/auth_api.dart';
import 'core/token_store.dart';
import 'sign_in_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.isDarkMode;
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: isDark
                ? const Color(0xFF0C0C0C)
                : const Color(0xFFF1F4F8),
            endDrawer: _buildDrawer(),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header with Cover Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=400&fit=crop',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () =>
                                  scaffoldKey.currentState?.openEndDrawer(),
                              child: Icon(
                                Icons.more_horiz,
                                color: isDark ? Colors.white70 : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              : Colors.black.withValues(alpha: 10),
                          blurRadius: 25,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile Avatar and Stats
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar positioned to overlap cover
                              Transform.translate(
                                offset: const Offset(0, -50),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF1F1F1F)
                                          : Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: const CircleAvatar(
                                    radius: 58,
                                    backgroundImage: NetworkImage(
                                      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
                                    ),
                                  ),
                                ),
                              ),

                              // Stats Row
                              Transform.translate(
                                offset: const Offset(0, -30),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatColumn('2,8K', 'Connections'),
                                    const SizedBox(width: 40),
                                    _buildStatColumn('892', 'Connected'),
                                  ],
                                ),
                              ),

                              // Name and Bio
                              Transform.translate(
                                offset: const Offset(0, -20),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Ludovic Carl',
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.verified,
                                          color: Color(0xFFBFAE01),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Wellness enthusiast 💪 Lover of clean living, mindful habits, and healthy vibes ✨🌱',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Action Buttons
                              Transform.translate(
                                offset: const Offset(0, -10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditProfilPage(
                                                fullName: 'Ludovic Carl',
                                                username: 'ludovic.carl',
                                                bio:
                                                    'Wellness enthusiast 💪 Lover of clean living, mindful habits, and healthy vibes ✨🌱',
                                                profilePhotoUrl:
                                                    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
                                                coverPhotoUrl:
                                                    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=400&fit=crop',
                                                experiences: [
                                                  ExperienceItem(
                                                    title:
                                                        'Doctor In Physiopine',
                                                  ),
                                                  ExperienceItem(
                                                    title: 'Coach Football',
                                                  ),
                                                ],
                                                trainings: [
                                                  TrainingItem(
                                                    title: 'University of Pens',
                                                    subtitle: 'Professor',
                                                  ),
                                                ],
                                                interests: [
                                                  'Aerospace',
                                                  'Engineering',
                                                  'Environment',
                                                  'Technology',
                                                  'Health & Wellness',
                                                  'Sports',
                                                  'Photography',
                                                  'Travel',
                                                  'Music',
                                                  'Cooking',
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFBFAE01,
                                          ),
                                          foregroundColor: isDark
                                              ? Colors.black
                                              : Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Edit Profile',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const MyConnectionsPage(),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          'My Connections',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white70
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
                                              ? Colors.white70
                                              : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                      child: Icon(
                                        Icons.person_add_outlined,
                                        size: 20,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Professional Experiences Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.work,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Professional Experiences',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Doctor In Physiopine',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Coach Football',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Trainings Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Trainings',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'University of Pens',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Professor',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Interest Section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Interest',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildInterestChip('Aerospace'),
                                  _buildInterestChip('Engineering'),
                                  _buildInterestChip('Environment'),
                                  _buildInterestChip('Technology'),
                                  _buildInterestChip('Health & Wellness'),
                                  _buildInterestChip('Sports'),
                                  _buildInterestChip('Photography'),
                                  _buildInterestChip('Travel'),
                                  _buildInterestChip('Music'),
                                  _buildInterestChip('Cooking'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab Section
                  _buildTabSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Drawer(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.monetization_on_outlined,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Monetization',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MonetizationPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.workspace_premium_outlined,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Premium',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PremiumSubscriptionPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.bar_chart,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Insights',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InsightsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.brightness_6,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                        activeThumbColor: const Color(0xFFBFAE01),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Help Center',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Help Center',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Support',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Support',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Terms & Conditions',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 22,
                  ),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () async {
                    // Close drawer first for better UX
                    Navigator.pop(context);

                    // Clear local auth state
                    await TokenStore.clear();

                    // Best-effort server-side logout (non-blocking if it fails)
                    try {
                      await AuthApi().logout();
                    } catch (_) {}

                    // Guard against using context after async gap
                    if (!mounted) return;

                    // Navigate to sign-in and clear back stack
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SignInPage()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildInterestChip(String label) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white70 : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }

  Widget _buildTabSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1F1F1F)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF000000) : Colors.black,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white70 : Colors.white,
                  unselectedLabelColor: isDark
                      ? Colors.white70
                      : const Color(0xFF666666),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(text: 'Activity'),
                    Tab(text: 'Posts'),
                    Tab(text: 'Podcasts'),
                    Tab(text: 'Media'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 650,
                child: TabBarView(
                  children: [
                    _buildActivityTab(),
                    _buildPostsTab(),
                    _buildPodcastsTab(),
                    _buildMediaTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    final activities = [
      Post(
        id: '1',
        userName: 'Wellness Weekly',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            '5 Simple habits that changed my life completely. Small changes, big impact! 🌟',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 156,
          comments: 34,
          shares: 22,
          reposts: 0,
          bookmarks: 67,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: 'You',
          userAvatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
          actionType: 'reposted this',
        ),
      ),
      Post(
        id: '2',
        userName: 'Mindful Living',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'Morning meditation changed everything for me. Starting each day with intention 🧘‍♀️',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 89,
          comments: 12,
          shares: 8,
          reposts: 0,
          bookmarks: 23,
        ),
        userReaction: ReactionType.like,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: 'You',
          userAvatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
          actionType: 'liked this',
        ),
      ),
      Post(
        id: '3',
        userName: 'Fitness Journey',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'Consistency beats perfection every single time. Keep showing up! 💪',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 234,
          comments: 45,
          shares: 18,
          reposts: 0,
          bookmarks: 89,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: 'You',
          userAvatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
          actionType: 'commented on this',
        ),
      ),
      Post(
        id: '4',
        userName: 'Healthy Habits',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'The power of small daily actions. Transform your life one habit at a time ✨',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 167,
          comments: 28,
          shares: 31,
          reposts: 0,
          bookmarks: 54,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: 'You',
          userAvatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
          actionType: 'shared this',
        ),
      ),
      Post(
        id: '5',
        userName: 'Nature Therapy',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text: 'Spending time in nature is the best medicine for the soul 🌿',
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 198,
          comments: 67,
          shares: 25,
          reposts: 0,
          bookmarks: 78,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: true,
        repostedBy: RepostedBy(
          userName: 'You',
          userAvatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
          actionType: 'reposted this',
        ),
      ),
    ];

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return PostCard(
          post: activities[index],
          onReactionChanged: (postId, reaction) {
            // Handle reaction change
          },
          onBookmarkToggle: (postId) {
            // Handle bookmark toggle
          },
          onShare: (postId) {
            // Handle share
          },
          onComment: (postId) {
            // Handle comment
          },
          onRepost: (postId) {
            // Handle repost
          },
        );
      },
    );
  }

  Widget _buildPostsTab() {
    final posts = [
      Post(
        id: '6',
        userName: 'Ludovic Carl',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text: 'Beautiful morning meditation session! 🧘‍♀️ #mindfulness',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 89,
          comments: 12,
          shares: 5,
          reposts: 0,
          bookmarks: 23,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
        repostedBy: null,
      ),
      Post(
        id: '7',
        userName: 'Ludovic Carl',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'Just finished an amazing workout! Feeling energized and ready for the day 💪',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 156,
          comments: 28,
          shares: 12,
          reposts: 0,
          bookmarks: 45,
        ),
        userReaction: ReactionType.like,
        isBookmarked: true,
        isRepost: false,
        repostedBy: null,
      ),
      Post(
        id: '8',
        userName: 'Ludovic Carl',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'Healthy breakfast to start the week right! 🥗✨ What\'s your go-to morning meal?',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 234,
          comments: 67,
          shares: 18,
          reposts: 0,
          bookmarks: 89,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
        repostedBy: null,
      ),
      Post(
        id: '9',
        userName: 'Ludovic Carl',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'Nature walk therapy session complete 🌿 Sometimes the best medicine is fresh air',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 178,
          comments: 34,
          shares: 22,
          reposts: 0,
          bookmarks: 56,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
        repostedBy: null,
      ),
      Post(
        id: '10',
        userName: 'Ludovic Carl',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text: 'Yoga flow complete! Finding balance in both body and mind 🕉️',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1506629905607-d9c297d3d04b?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 145,
          comments: 19,
          shares: 8,
          reposts: 0,
          bookmarks: 32,
        ),
        userReaction: ReactionType.heart,
        isBookmarked: true,
        isRepost: false,
        repostedBy: null,
      ),
      Post(
        id: '11',
        userName: 'Ludovic Carl',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
        text:
            'Grateful for another day to grow and learn. What are you grateful for today? 🙏',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=600&h=400&fit=crop',
        ],
        videoUrl: null,
        counts: PostCounts(
          likes: 267,
          comments: 89,
          shares: 35,
          reposts: 0,
          bookmarks: 78,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
        repostedBy: null,
      ),
    ];

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return HomePostCard(
          post: posts[index],
          onReactionChanged: (postId, reaction) {
            // Handle reaction change
          },
          onBookmarkToggle: (postId) {
            // Handle bookmark toggle
          },
          onShare: (postId) {
            // Handle share
          },
          onComment: (postId) {
            // Handle comment
          },
          onRepost: (postId) {
            // Handle repost
          },
        );
      },
    );
  }

  Widget _buildPodcastsTab() {
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        _buildPodcastItem(
          'Wellness Wednesday',
          'Episode 12: Finding Balance in Busy Life',
          '45 min',
          'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=300&h=300&fit=crop',
        ),
        _buildPodcastItem(
          'Mindful Moments',
          'Episode 8: The Power of Gratitude',
          '32 min',
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=300&fit=crop',
        ),
      ],
    );
  }

  Widget _buildPodcastItem(
    String title,
    String episode,
    String duration,
    String imageUrl,
  ) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1F1F1F)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, size: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaTab() {
    final mediaItems = [
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1506629905607-d9c297d3d04b?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1493770348161-369560ae357d?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1540206395-68808572332f?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=300&h=300&fit=crop',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&h=300&fit=crop',
    ];

    return GridView.count(
      primary: false,
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: mediaItems.map((imageUrl) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(imageUrl, fit: BoxFit.cover),
        );
      }).toList(),
    );
  }
}
