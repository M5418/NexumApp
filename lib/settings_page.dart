import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'feed_preferences_page.dart';
import 'content_controls_page.dart';
import 'language_region_page.dart';
import 'account_center_page.dart';
import 'privacy_visibility_page.dart';
import 'blocked_muted_accounts_page.dart';
import 'security_login_page.dart';
import 'notification_preferences_page.dart';

import 'services/auth_service.dart';
import 'app_wrapper.dart';
import 'responsive/responsive_breakpoints.dart';
import 'core/i18n/language_provider.dart';
import 'theme_provider.dart';

class SettingsPage extends StatefulWidget {
  final bool? isDarkMode;

  const SettingsPage({super.key, this.isDarkMode});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlobalKey<NavigatorState> _panelNavigatorKey = GlobalKey<NavigatorState>();

  int _selectedIndex = 0;

  late final List<_NavItem> _items = [
    _NavItem(
      icon: Icons.account_circle_outlined,
      titleKey: 'settings.nav.account_center',
      builder: () => const AccountCenterPage(),
    ),
    _NavItem(
      icon: Icons.feed_outlined,
      titleKey: 'settings.nav.feed_preferences',
      builder: () => const FeedPreferencesPage(),
    ),
    _NavItem(
      icon: Icons.tune,
      titleKey: 'settings.nav.content_controls',
      builder: () => const ContentControlsPage(),
    ),
    _NavItem(
      icon: Icons.notifications_outlined,
      titleKey: 'settings.nav.notification_preferences',
      builder: () => const NotificationPreferencesPage(),
    ),
    _NavItem(
      icon: Icons.language,
      titleKey: 'settings.nav.language_region',
      builder: () => const LanguageRegionPage(),
    ),
    _NavItem(
      icon: Icons.privacy_tip_outlined,
      titleKey: 'settings.nav.privacy_visibility',
      builder: () => const PrivacyVisibilityPage(),
    ),
    _NavItem(
      icon: Icons.block_outlined,
      titleKey: 'settings.nav.blocked_muted',
      builder: () => const BlockedMutedAccountsPage(),
    ),
    _NavItem(
      icon: Icons.security,
      titleKey: 'settings.nav.security_login',
      builder: () => const SecurityLoginPage(),
    ),
    _NavItem(
      icon: Icons.exit_to_app,
      titleKey: 'settings.nav.logout',
      builder: null,
      isLogout: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final lang = context.watch<LanguageProvider>();

    final isDesktop = context.isDesktop || context.isLargeDesktop;
    return isDesktop
        ? _buildDesktop(context, isDark, lang)
        : _buildMobile(context, isDark, lang);
  }

  // Desktop header: back button + "NEXUM"
  Widget _buildDesktopHeader(bool isDark, LanguageProvider lang) {
    final barColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    return Material(
      color: barColor,
      elevation: isDark ? 0 : 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
              tooltip: lang.t('common.back'),
            ),
            const SizedBox(width: 8),
            Text(
              lang.t('app.name'),
              style: GoogleFonts.inika(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== Desktop/Web two-column layout ==============
  Widget _buildDesktop(BuildContext context, bool isDark, LanguageProvider lang) {
    final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDesktopHeader(isDark, lang),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left nav: small width
                        Container(
                          width: 280,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left panel header
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  lang.t('settings.title'),
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    final selected = index == _selectedIndex && !item.isLogout;
                                    return _leftTile(
                                      isDark: isDark,
                                      selected: selected,
                                      icon: item.icon,
                                      title: lang.t(item.titleKey),
                                      onTap: () => _handleLeftTap(index),
                                      isLogout: item.isLogout,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right panel: displays the selected settings page
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: isDark ? Colors.black : Colors.white,
                              child: Navigator(
                                key: _panelNavigatorKey,
                                onGenerateInitialRoutes: (_, __) {
                                  final initial = _items[_selectedIndex];
                                  final builder = initial.builder ?? () => const SizedBox.shrink();
                                  return [
                                    MaterialPageRoute(settings: const RouteSettings(name: 'settings_panel'), builder: (_) => builder()),
                                  ];
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftTile({
    required bool isDark,
    required bool selected,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final baseColor = isDark ? Colors.white : Colors.black87;
    final selectedBg = const Color(0xFFBFAE01).withValues(alpha: 0.12);
    final selectedColor = const Color(0xFFBFAE01);

    return Material(
      color: selected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isLogout
                    ? Colors.red
                    : (selected ? selectedColor : baseColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: isLogout
                        ? Colors.red
                        : (selected ? selectedColor : baseColor),
                  ),
                ),
              ),
              if (!isLogout)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLeftTap(int index) async {
    final item = _items[index];
    if (item.isLogout) {
      final confirmed = await _confirmLogout(context);
      if (confirmed == true) {
        await _performLogout();
      }
      return;
    }

    setState(() => _selectedIndex = index);
    final builder = item.builder!;
    // Replace right-panel route with the selected page
    _panelNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(settings: const RouteSettings(name: 'settings_panel'), builder: (_) => builder()),
      (route) => false,
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang.t('dialogs.logout.title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          lang.t('dialogs.logout.message'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('common.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.t('common.logout'),
              style: GoogleFonts.inter(color: const Color(0xFFBFAE01)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Clear local state
      await AuthService().signOut();

      // Reset navigation to AppWrapper
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(settings: const RouteSettings(name: 'app_wrapper'), builder: (_) => const AppWrapper()),
          (_) => false,
        );
      }
    } catch (_) {
      // Best-effort logout; ignore failures
    }
  }

  // ============== Mobile (existing list layout, with logout confirm) ==============
  Widget _buildMobile(BuildContext context, bool isDark, LanguageProvider lang) {
    final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
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
          tooltip: lang.t('common.back'),
        ),
        title: Text(
          lang.t('settings.title'),
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

            // Personalization & Preferences
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
                      lang.t('settings.section.personalization'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildSettingsItem(
                    icon: Icons.account_circle_outlined,
                    title: lang.t('settings.nav.account_center'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'account_center'), builder: (_) => const AccountCenterPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.feed_outlined,
                    title: lang.t('settings.nav.feed_preferences'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'feed_preferences'), builder: (_) => const FeedPreferencesPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.tune,
                    title: lang.t('settings.nav.content_controls'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'content_controls'), builder: (_) => const ContentControlsPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.notifications_outlined,
                    title: lang.t('settings.nav.notification_preferences'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'notification_preferences'), builder: (_) => const NotificationPreferencesPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.language,
                    title: lang.t('settings.nav.language_region'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'language_region'), builder: (_) => const LanguageRegionPage()),
                      );
                    },
                    isLast: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account & Security
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
                      lang.t('settings.section.account_security'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  _buildSettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    title: lang.t('settings.nav.privacy_visibility'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'privacy_visibility'), builder: (_) => const PrivacyVisibilityPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.block_outlined,
                    title: lang.t('settings.nav.blocked_muted'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'blocked_muted_accounts'), builder: (_) => const BlockedMutedAccountsPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.security,
                    title: lang.t('settings.nav.security_login'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'security_login'), builder: (_) => const SecurityLoginPage()),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildSettingsItem(
                    icon: Icons.exit_to_app,
                    title: lang.t('settings.nav.logout'),
                    onTap: () async {
                      final confirmed = await _confirmLogout(context);
                      if (confirmed == true) {
                        await _performLogout();
                      }
                    },
                    isLast: true,
                    isDark: isDark,
                    logoutDanger: true,
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
    bool logoutDanger = false,
  }) {
    final textColor = isDark ?? false ? Colors.white : Colors.black87;
    final dividerColor = Colors.grey.withValues(alpha: 0.2);

    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: logoutDanger ? Colors.red : textColor,
            size: 24,
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: logoutDanger ? Colors.red : textColor,
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

class _NavItem {
  final IconData icon;
  final String titleKey;
  final Widget Function()? builder;
  final bool isLogout;

  _NavItem({
    required this.icon,
    required this.titleKey,
    required this.builder,
    this.isLogout = false,
  });
}