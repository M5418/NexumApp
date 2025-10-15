// File: lib/account_center_page.dart
// Lines: 1-420
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth_api.dart';
import 'core/token_store.dart';
import 'core/profile_api.dart';
import 'sign_in_page.dart';
import 'change_password_page.dart';
import 'change_email_page.dart';
import 'kyc_verification_page.dart';
import 'kyc_status_page.dart';
import 'core/kyc_api.dart';

class AccountCenterPage extends StatefulWidget {
  const AccountCenterPage({super.key});

  @override
  State<AccountCenterPage> createState() => _AccountCenterPageState();
}

class _AccountCenterPageState extends State<AccountCenterPage> {
  // Profile Data
  String _email = '';
  String _fullName = '';
  String _username = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      // Email from auth
      final authApi = AuthApi();
      final response = await authApi.me();

      if (response['ok'] == true && response['data'] != null) {
        final email = (response['data']['email'] ?? '').toString();
        if (mounted) {
          setState(() {
            _email = email;
          });
        }
      } else {
        throw Exception('Failed to load auth user');
      }

      // Profile details (avatar, full name, username)
      try {
        final profApi = ProfileApi();
        final profRes = await profApi.me();
        final body = Map<String, dynamic>.from(profRes);
        final data = Map<String, dynamic>.from(body['data'] ?? {});
        final fullName = (data['full_name'] ?? '').toString();
        final username = (data['username'] ?? '').toString();
        final avatarUrl = (data['profile_photo_url'] ?? '').toString();

        if (mounted) {
          setState(() {
            _fullName = fullName;
            _username = username;
            _avatarUrl = avatarUrl;
          });
        }
      } catch (_) {
        // profile optional; keep defaults
      }
    } catch (_) {
      // Not authenticated: redirect to sign in if no token
      final t = await TokenStore.read();
      if (t == null || t.isEmpty) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SignInPage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Center',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Profile Information
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Profile Information'),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    backgroundImage: _avatarUrl.isNotEmpty
                        ? NetworkImage(_avatarUrl)
                        : null,
                    child: _avatarUrl.isEmpty
                        ? Text(
                            (_fullName.isNotEmpty ? _fullName[0] : 'U').toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    _fullName.isNotEmpty ? _fullName : 'User',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _username.isNotEmpty ? '@$_username' : '',
                    style: GoogleFonts.inter(color: const Color(0xFF666666)),
                  ),
                ),
                const Divider(height: 1),
                _infoRow(
                  'Email',
                  _email.isNotEmpty ? _email : 'user@example.com',
                ),
                _infoRow('Phone', 'No phone number added yet'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account / Security (replaces Connected Accounts)
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Account & Security'),
                const SizedBox(height: 8),
                _navTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePasswordPage(currentEmail: _email),
                      ),
                    );
                  },
                ),
                _navTile(
                  icon: Icons.email_outlined,
                  title: 'Change Email',
                  subtitle: 'Update your email address',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeEmailPage(currentEmail: _email),
                      ),
                    );
                  },
                ),
                _navTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Verify KYC',
                  subtitle: 'Verify your identity',
                  onTap: () async {
                    final ctx = context;
                    final res = await KycApi().getMine();
                    if (res['ok'] == true) {
                      final data = res['data'];
                      final status = (data == null) ? null : (data['status'] ?? '').toString();
                      if (data == null || status == 'rejected') {
                        if (!ctx.mounted) return;
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(builder: (_) => const KycVerificationPage()),
                        );
                      } else {
                        if (!ctx.mounted) return;
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(builder: (_) => const KycStatusPage()),
                        );
                      }
                    } else {
                      if (!ctx.mounted) return;
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(builder: (_) => const KycVerificationPage()),
                      );
                    }
                  },
                ),
                _navTile(
                  icon: Icons.phone_outlined,
                  title: 'Change Phone Number',
                  subtitle: 'Add or update your phone',
                  onTap: () => _showSnack('Change phone number coming soon'),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data & Permissions
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Data & Permissions'),
                const SizedBox(height: 8),
                _navTile(
                  icon: Icons.download_outlined,
                  title: 'Download Your Data',
                  subtitle: 'Coming soon',
                  onTap: () => _showSnack('Coming soon'),
                ),
                _navTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ads Preferences',
                  subtitle: 'Coming soon',
                  onTap: () => _showSnack('Coming soon'),
                ),
                _navTile(
                  icon: Icons.person_off_outlined,
                  title: 'Deactivate Account',
                  subtitle: 'Coming soon',
                  onTap: () => _showSnack('Coming soon'),
                ),
                _navTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  onTap: _handleDeleteAccount,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
  );

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(color: const Color(0xFF666666)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              fontSize: 12,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
            color: Colors.grey,
          ),
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text, style: GoogleFonts.inter())));
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await _confirm(
      context,
      'Delete account permanently?',
      'This action will permanently delete your account and all associated data. This cannot be undone.',
      confirmText: 'Delete',
    );
    if (confirmed != true) return;

    try {
      final api = AuthApi();
      final res = await api.deleteAccount();
      final ok = (res['ok'] == true);
      if (!ok) {
        final err = (res['error'] ?? 'delete_failed').toString();
        _showSnack('Failed to delete account: $err');
        return;
      }

      // Clear local token and navigate to sign-in
      await TokenStore.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (_) => false,
      );
    } catch (_) {
      _showSnack('Failed to delete account');
    }
  }

  Future<bool?> _confirm(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Continue',
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmText,
              style: GoogleFonts.inter(color: const Color(0xFFBFAE01)),
            ),
          ),
        ],
      ),
    );
  }
}