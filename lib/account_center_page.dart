// File: lib/account_center_page.dart
// Lines: 1-420
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/firebase/firebase_kyc_repository.dart';
import 'repositories/interfaces/user_repository.dart';
import 'kyc_verification_page.dart';
import 'kyc_status_page.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'sign_in_page.dart';
import 'change_password_page.dart';
import 'change_email_page.dart';

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
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('account_center.confirm_password'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(hintText: Provider.of<LanguageProvider>(ctx, listen: false).t('account_center.enter_password')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.confirm'), style: GoogleFonts.inter(color: Color(0xFFBFAE01))),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMe() async {
    final u = fb.FirebaseAuth.instance.currentUser;
    if (u == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        );
      }
      return;
    }

    // Set email from FirebaseAuth
    if (mounted) {
      setState(() {
        _email = (u.email ?? '').toString();
      });
    }

    // Load profile details from Firebase
    try {
      final userRepo = context.read<UserRepository>();
      final profile = await userRepo.getCurrentUserProfile();
      
      if (profile != null && mounted) {
        final firstName = profile.firstName ?? '';
        final lastName = profile.lastName ?? '';
        final fullName = firstName.isNotEmpty || lastName.isNotEmpty
            ? '$firstName $lastName'.trim()
            : (profile.displayName ?? '');
        
        setState(() {
          _fullName = fullName;
          _username = profile.username ?? '';
          _avatarUrl = profile.avatarUrl ?? '';
          _status = profile.status ?? '';
        });
      }
    } catch (_) {
      // optional
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
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
          lang.t('account_center.title'),
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
                _sectionTitle(lang.t('account_center.section_profile')),
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
                    _fullName.isNotEmpty ? _fullName : lang.t('account_center.user'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _username.isNotEmpty ? '@$_username' : '',
                    style: GoogleFonts.inter(color: const Color(0xFF666666)),
                  ),
                ),
                const Divider(height: 1),
                if (_status.isNotEmpty) ...[
                  _infoRow(lang.t('account_center.info_status'), _status),
                  const Divider(height: 1),
                ],
                _infoRow(
                  lang.t('account_center.info_email'),
                  _email.isNotEmpty ? _email : 'user@example.com',
                ),
                _infoRow(lang.t('account_center.info_phone'), lang.t('account_center.no_phone')),
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
                _sectionTitle(lang.t('account_center.section_security')),
                const SizedBox(height: 8),
                _navTile(
                  icon: Icons.lock_outline,
                  title: lang.t('account_center.change_password'),
                  subtitle: lang.t('account_center.change_password_subtitle'),
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
                  title: lang.t('account_center.change_email'),
                  subtitle: lang.t('account_center.change_email_subtitle'),
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
                  title: lang.t('account_center.verify_kyc'),
                  subtitle: lang.t('account_center.verify_kyc_subtitle'),
                  onTap: () async {
                    final ctx = context;
                    final kycRepo = FirebaseKycRepository();
                    final kycModel = await kycRepo.getMyKyc();
                    if (kycModel != null) {
                      final status = kycModel.status;
                      if (status == 'rejected') {
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
                  title: lang.t('account_center.change_phone'),
                  subtitle: lang.t('account_center.change_phone_subtitle'),
                  onTap: () => _showSnack(lang.t('account_center.coming_soon')),
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
                _sectionTitle(lang.t('account_center.section_data')),
                const SizedBox(height: 8),
                _navTile(
                  icon: Icons.download_outlined,
                  title: lang.t('account_center.download_data'),
                  subtitle: lang.t('account_center.coming_soon'),
                  onTap: () => _showSnack(lang.t('account_center.coming_soon')),
                ),
                _navTile(
                  icon: Icons.receipt_long_outlined,
                  title: lang.t('account_center.ads_prefs'),
                  subtitle: lang.t('account_center.coming_soon'),
                  onTap: () => _showSnack(lang.t('account_center.coming_soon')),
                ),
                _navTile(
                  icon: Icons.person_off_outlined,
                  title: lang.t('account_center.deactivate'),
                  subtitle: lang.t('account_center.coming_soon'),
                  onTap: () => _showSnack(lang.t('account_center.coming_soon')),
                ),
                _navTile(
                  icon: Icons.delete_outline,
                  title: lang.t('account_center.delete'),
                  subtitle: lang.t('account_center.delete_subtitle'),
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
    final navContext = context;
    final confirmed = await _confirm(
      navContext,
      'Delete account permanently?',
      'This action will permanently delete your account and all associated data. This cannot be undone.',
      confirmText: 'Delete',
    );
    if (confirmed != true) return;

    try {
      if (!navContext.mounted) return;
      // Prompt for password to re-authenticate
      final pwd = await _promptPassword(navContext);
      if (!navContext.mounted) return;
      if (pwd == null || pwd.isEmpty) return;
      final repo = navContext.read<AuthRepository>();
      await repo.deleteAccount(password: pwd);
      if (!navContext.mounted) return;
      Navigator.of(navContext).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (_) => false,
      );
    } catch (_) {
      if (!navContext.mounted) return;
      final lang = Provider.of<LanguageProvider>(navContext, listen: false);
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(content: Text(lang.t('account_center.delete_failed'), style: GoogleFonts.inter())),
      );
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
            child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
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