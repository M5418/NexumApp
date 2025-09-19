import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/api_client.dart';
import 'core/auth_api.dart';
import 'sign_in_page.dart';

class AccountCenterPage extends StatefulWidget {
  const AccountCenterPage({super.key});

  @override
  State<AccountCenterPage> createState() => _AccountCenterPageState();
}

class _AccountCenterPageState extends State<AccountCenterPage> {
  bool _googleLinked = true;
  bool _appleLinked = false;
  bool _twitterLinked = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final store = TokenStore();
      final api = ApiClient(store);
      final auth = AuthApi(api, store);
      final me = await auth.me();
      final email = (me['email'] as String?) ?? '';
      if (mounted) {
        setState(() {
          _email = email;
        });
      }
    } catch (_) {
      final t = await TokenStore().read();
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
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Profile Information'),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
                    ),
                  ),
                  title: Text(
                    'Ludovic Carl',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '@ludovic.carl',
                    style: GoogleFonts.inter(color: const Color(0xFF666666)),
                  ),
                ),
                const Divider(height: 1),
                _infoRow(
                  'Email',
                  _email.isNotEmpty ? _email : 'user@example.com',
                ),
                _infoRow('Phone', '+1 (555) 123-4567'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Connected Accounts'),
                const SizedBox(height: 8),
                _switchTile(
                  icon: Icons.g_mobiledata,
                  title: 'Google',
                  value: _googleLinked,
                  onChanged: (v) => setState(() => _googleLinked = v),
                ),
                _switchTile(
                  icon: Icons.apple,
                  title: 'Apple',
                  value: _appleLinked,
                  onChanged: (v) => setState(() => _appleLinked = v),
                ),
                _switchTile(
                  icon: Icons.alternate_email,
                  title: 'Twitter (X)',
                  value: _twitterLinked,
                  onChanged: (v) => setState(() => _twitterLinked = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                  subtitle: 'Request a copy of your data',
                  onTap: () => _showSnack('Data download requested'),
                ),
                _navTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ads Preferences',
                  subtitle: 'Control personalized ads',
                  onTap: () => _showSnack('Ads preferences opened'),
                ),
                _navTile(
                  icon: Icons.person_off_outlined,
                  title: 'Deactivate Account',
                  subtitle: 'Temporarily disable your account',
                  onTap: () => _confirm(context, 'Deactivate account?'),
                ),
                _navTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  onTap: () => _confirm(context, 'Delete account permanently?'),
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

  Widget _switchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      activeTrackColor: const Color(0xFFBFAE01),
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

  Future<void> _confirm(BuildContext context, String title) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This is a placeholder action. Backend integration required.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(color: const Color(0xFFBFAE01)),
            ),
          ),
        ],
      ),
    );
  }
}
