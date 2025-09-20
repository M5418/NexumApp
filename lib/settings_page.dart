import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'feed_preferences_page.dart';
import 'content_controls_page.dart';
import 'language_region_page.dart';
import 'account_center_page.dart';
import 'privacy_visibility_page.dart';
import 'blocked_muted_accounts_page.dart';
import 'security_login_page.dart';
import 'notification_preferences_page.dart';
import 'core/auth_api.dart';
import 'core/token_store.dart';
import 'sign_in_page.dart';

class SettingsPage extends StatelessWidget {
  final bool? isDarkMode;

  const SettingsPage({super.key, this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final isDark =
        isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
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
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 20,
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

            // Personalization & Preferences Section
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
                      'Personalization & Preferences',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildSettingsItem(
                    icon: Icons.account_circle_outlined,
                    title: 'Account Center',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountCenterPage(),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.feed_outlined,
                    title: 'Feed Preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeedPreferencesPage(),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.tune,
                    title: 'Content Controls',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContentControlsPage(),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notification Preferences',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationPreferencesPage(),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.language,
                    title: 'Language & Region',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageRegionPage(),
                        ),
                      );
                    },
                    isLast: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account & Security Section
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
                      'Account & Security',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildSettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Visibility',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyVisibilityPage(),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.block_outlined,
                    title: 'Blocked & Muted Accounts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BlockedMutedAccountsPage(),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.security,
                    title: 'Security & Login',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityLoginPage(),
                        ),
                      );
                    },
                    isLast: false,
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.exit_to_app,
                    title: 'Logout',
                    onTap: () async {
                      try {
                        final authApi = AuthApi();
                        await authApi.logout();
                        await TokenStore.clear();

                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SignInPage(),
                            ),
                          );
                        }
                      } catch (e) {
                        // Even if logout fails, clear local token and redirect
                        await TokenStore.clear();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SignInPage(),
                            ),
                          );
                        }
                      }
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

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
    bool? isDark,
  }) {
    final textColor = isDark ?? false ? Colors.white : Colors.black87;
    final dividerColor = isDark ?? false
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
