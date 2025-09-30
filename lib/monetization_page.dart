import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'monetization_analytics_page.dart';
import 'payout_setup_page.dart';

class MonetizationPage extends StatefulWidget {
  const MonetizationPage({super.key});

  @override
  State<MonetizationPage> createState() => _MonetizationPageState();
}

class _MonetizationPageState extends State<MonetizationPage> {
  final bool _eligible = true;
  bool _contentMonetized = true;
  bool _adsEnabled = true;
  bool _sponsorshipsEnabled = false;

  final bool _reqFollowers = true;
  final bool _reqPosts = true;
  final bool _reqKyc = false;
  final bool _req2FA = true;

  String? _payoutMethod; // e.g., 'Stripe'

  bool _isDesktopLayout(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.of(context).size.width >= 1000;
    }
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final card = isDark ? const Color(0xFF000000) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final desktop = _isDesktopLayout(context);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Monetization',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
        centerTitle: true,
      ),
      body: desktop ? _buildDesktop(card) : _buildMobile(card),
    );
  }

  // ============= Layouts =============

  Widget _buildMobile(Color card) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _eligibilityCard(card),
        const SizedBox(height: 16),
        _earningsCard(card, showAnalyticsButton: true),
        const SizedBox(height: 16),
        _monetizedContentCard(card),
        const SizedBox(height: 16),
        _requirementsCard(card),
      ],
    );
  }

  Widget _buildDesktop(Color card) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Monetization settings
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                _eligibilityCard(card),
                const SizedBox(height: 16),
                _earningsCard(card, showAnalyticsButton: false), // analytics visible on right
                const SizedBox(height: 16),
                _monetizedContentCard(card),
                const SizedBox(height: 16),
                _requirementsCard(card),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Analytics panel
          const Expanded(
            flex: 5,
            child: MonetizationAnalyticsView(),
          ),
        ],
      ),
    );
  }

  // ============= Cards (Left column) =============

  Widget _eligibilityCard(Color card) {
    return _card(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _eligible ? Icons.verified_outlined : Icons.info_outline,
                color: _eligible ? const Color(0xFFBFAE01) : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _eligible ? 'You are eligible' : 'Eligibility in review',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _eligible
                ? 'Great! You meet the current requirements to monetize your content.'
                : 'We are reviewing your account. You will be notified once you are eligible.',
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsCard(Color card, {required bool showAnalyticsButton}) {
    return _card(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings summary',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metric('This month', '\$482.40'),
              const SizedBox(width: 16),
              _metric('Pending', '\$127.10'),
              const SizedBox(width: 16),
              _metric('Lifetime', '\$6,921.75'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (showAnalyticsButton) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonetizationAnalyticsPage(),
                        ),
                      );
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
                      'View analytics',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                                    onPressed: _payoutMethod == null
                      ? () async {
                          final desktop = _isDesktopLayout(context);
                          bool? ok;
                          if (desktop) {
                            ok = await showDialog<bool>(
                              context: context,
                              barrierDismissible: true,
                              builder: (_) {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Material(
                                          color: isDark ? const Color(0xFF000000) : Colors.white,
                                          child: const PayoutSetupPage(),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PayoutSetupPage(),
                              ),
                            );
                          }
                          if (ok == true && mounted) {
                            setState(() => _payoutMethod = 'Stripe');
                            _snack('Payout method connected');
                          }
                        }
                      : () => _snack('Manage payout (placeholder)'),
                      
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    _payoutMethod == null ? 'Set up payout' : 'Manage payout',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monetizedContentCard(Color card) {
    return _card(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monetized content',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _switch(
            'Enable monetization on new posts',
            _contentMonetized,
            (v) => setState(() => _contentMonetized = v),
          ),
          _switch(
            'Enable ads on eligible content',
            _adsEnabled,
            (v) => setState(() => _adsEnabled = v),
          ),
          _switch(
            'Allow sponsorship placements',
            _sponsorshipsEnabled,
            (v) => setState(() => _sponsorshipsEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _requirementsCard(Color card) {
    return _card(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requirements',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _req('5,000+ followers', _reqFollowers),
          _req('30+ posts in last 90 days', _reqPosts),
          _req('KYC verification', _reqKyc),
          _req('Two-factor authentication enabled', _req2FA),
        ],
      ),
    );
  }

  // ============= Shared helpers =============

  Widget _card({required Color color, required Widget child}) {
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

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF666666),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      activeTrackColor: const Color(0xFFBFAE01),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _req(String text, bool ok) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        ok ? Icons.check_circle : Icons.radio_button_unchecked,
        color: ok ? const Color(0xFFBFAE01) : const Color(0xFFBDBDBD),
      ),
      title: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      trailing: ok
          ? const SizedBox.shrink()
          : TextButton(
              onPressed: () => _snack('Action required: $text'),
              child: Text(
                'Fix',
                style: GoogleFonts.inter(
                  color: const Color(0xFFBFAE01),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.inter())));
  }
}