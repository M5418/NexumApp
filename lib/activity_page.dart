import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityPage extends StatefulWidget {
  final bool? isDarkMode;

  const ActivityPage({super.key, this.isDarkMode});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Interactions Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Interactions',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildActivityItem(
                    icon: Icons.favorite_border,
                    title: 'Likes',
                    onTap: () {
                      // Navigate to likes
                    },
                    isDark: isDark,
                  ),
                  _buildActivityItem(
                    icon: Icons.chat_bubble_outline,
                    title: 'Comments',
                    onTap: () {
                      // Navigate to comments
                    },
                    isDark: isDark,
                  ),
                  _buildActivityItem(
                    icon: Icons.repeat,
                    title: 'Repost',
                    onTap: () {
                      // Navigate to reposts
                    },
                    isLast: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Removed & Archived Content Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Removed & Archived Content',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildActivityItem(
                    icon: Icons.delete_outline,
                    title: 'Recently deleted',
                    onTap: () {
                      // Navigate to recently deleted
                    },
                    isDark: isDark,
                  ),
                  _buildActivityItem(
                    icon: Icons.archive_outlined,
                    title: 'Archived',
                    onTap: () {
                      // Navigate to archived content
                    },
                    isLast: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // How You Use Communi Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'How You Use Communi',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildActivityItem(
                    icon: Icons.history,
                    title: 'Account History',
                    onTap: () {
                      // Navigate to account history
                    },
                    isDark: isDark,
                  ),
                  _buildActivityItem(
                    icon: Icons.search,
                    title: 'Recent Searches',
                    onTap: () {
                      // Navigate to recent searches
                    },
                    isLast: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Information you shared Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Information you shared',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildActivityItem(
                    icon: Icons.swap_horiz,
                    title: 'Transfer your information',
                    onTap: () {
                      // Navigate to transfer information
                    },
                    isDark: isDark,
                  ),
                  _buildActivityItem(
                    icon: Icons.download_outlined,
                    title: 'Download your information',
                    onTap: () {
                      // Navigate to download information
                    },
                    isLast: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark
        ? Colors.grey.withValues(alpha: 51)
        : Colors.grey.withValues(alpha: 51);

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: textColor, size: 24),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: 20,
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 56,
            endIndent: 16,
          ),
      ],
    );
  }
}
