import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/i18n/language_provider.dart';

class SecurityLoginPage extends StatefulWidget {
  const SecurityLoginPage({super.key});

  @override
  State<SecurityLoginPage> createState() => _SecurityLoginPageState();
}

class _SecurityLoginPageState extends State<SecurityLoginPage> {
  bool _loginAlerts = true;
  bool _twoFactor = false;
  final List<String> _rememberedDevices = [
    'iPhone 14 Pro · Abidjan',
    'Pixel 7 · Paris',
  ];
  final List<String> _activeSessions = [
    'Windows · Chrome · Abidjan',
    'Mac · Safari · Paris',
  ];

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
          lang.t('security.title'),
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
                _sectionTitle(lang.t('security.alerts_2fa')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('security.login_alerts'),
                  subtitle:
                      Provider.of<LanguageProvider>(context, listen: false).t('security.notification_subtitle'),
                  value: _loginAlerts,
                  onChanged: (v) => setState(() => _loginAlerts = v),
                ),
                _switchTile(
                  title: lang.t('security.two_factor'),
                  subtitle: Provider.of<LanguageProvider>(context, listen: false).t('security.subtitle'),
                  value: _twoFactor,
                  onChanged: (v) => setState(() => _twoFactor = v),
                ),
                if (_twoFactor)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: ListTile(
                      leading: const Icon(Icons.qr_code),
                      title: Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('security.setup_authenticator'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('security.scan_qr'),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () =>
                          _showSnack(Provider.of<LanguageProvider>(context, listen: false).t('security.authenticator_placeholder')),
                    ),
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
                _sectionTitle(lang.t('security.remembered_devices')),
                const SizedBox(height: 8),
                ..._rememberedDevices.map(
                  (d) => ListTile(
                    leading: const Icon(Icons.devices_other_outlined),
                    title: Text(
                      d,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          setState(() => _rememberedDevices.remove(d)),
                      child: Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('security.remove'),
                        style: GoogleFonts.inter(
                          color: const Color(0xFFBFAE01),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_rememberedDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      Provider.of<LanguageProvider>(context, listen: false).t('security.no_devices'),
                      style: GoogleFonts.inter(color: const Color(0xFF666666)),
                    ),
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
                _sectionTitle(lang.t('security.active_sessions')),
                const SizedBox(height: 8),
                ..._activeSessions.map(
                  (s) => ListTile(
                    leading: const Icon(Icons.login),
                    title: Text(
                      s,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          setState(() => _activeSessions.remove(s)),
                      child: Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('security.sign_out'),
                        style: GoogleFonts.inter(
                          color: const Color(0xFFBFAE01),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_activeSessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      lang.t('security.no_active_sessions'),
                      style: GoogleFonts.inter(color: const Color(0xFF666666)),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _activeSessions.clear());
                      _showSnack(lang.t('security.signed_out_all_sessions'));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFBFAE01),
                      side: const BorderSide(
                        color: Color(0xFFBFAE01),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      Provider.of<LanguageProvider>(context, listen: false).t('security.sign_out_all'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
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

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: const Color(0xFF666666), fontSize: 12),
      ),
      activeTrackColor: const Color(0xFFBFAE01),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text, style: GoogleFonts.inter())));
  }
}
