import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'monetization_analytics_page.dart';
import 'payout_setup_page.dart';
import 'repositories/interfaces/monetization_repository.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'repositories/models/monetization_models.dart';

class MonetizationPage extends StatefulWidget {
  const MonetizationPage({super.key});

  @override
  State<MonetizationPage> createState() => _MonetizationPageState();
}

class _MonetizationPageState extends State<MonetizationPage> {
  MonetizationProfile? _profile;
  EarningsSummary? _summary;
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authRepo = context.read<AuthRepository>();
    final monetizationRepo = context.read<MonetizationRepository>();

    final user = authRepo.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _userId = user.uid;

    try {
      // Check eligibility requirements first
      await monetizationRepo.checkEligibilityRequirements(user.uid);

      // Get monetization profile
      var profile = await monetizationRepo.getMonetizationProfile(user.uid);
      
      // Create default profile if doesn't exist
      if (profile == null) {
        profile = MonetizationProfile(
          userId: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await monetizationRepo.updateMonetizationProfile(profile);
      }

      // Get earnings summary
      final summary = await monetizationRepo.getEarningsSummary(user.uid);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading monetization data: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateSettings({bool? contentMonetized, bool? adsEnabled, bool? sponsorshipsEnabled}) async {
    if (_profile == null || _userId == null) return;

    final monetizationRepo = context.read<MonetizationRepository>();
    
    final updatedProfile = MonetizationProfile(
      userId: _userId!,
      isEligible: _profile!.isEligible,
      isContentMonetized: contentMonetized ?? _profile!.isContentMonetized,
      isAdsEnabled: adsEnabled ?? _profile!.isAdsEnabled,
      isSponsorshipsEnabled: sponsorshipsEnabled ?? _profile!.isSponsorshipsEnabled,
      payoutMethod: _profile!.payoutMethod,
      payoutAccountId: _profile!.payoutAccountId,
      eligibleSince: _profile!.eligibleSince,
      createdAt: _profile!.createdAt,
      updatedAt: DateTime.now(),
      hasMinFollowers: _profile!.hasMinFollowers,
      hasMinPosts: _profile!.hasMinPosts,
      isKycVerified: _profile!.isKycVerified,
      has2FA: _profile!.has2FA,
    );

    try {
      await monetizationRepo.updateMonetizationProfile(updatedProfile);
      setState(() => _profile = updatedProfile);
    } catch (e) {
      debugPrint('❌ Error updating monetization settings: $e');
      _snack('Failed to update settings');
    }
  }

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
          Provider.of<LanguageProvider>(context, listen: false).t('monetization.page_title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : desktop ? _buildDesktop(card) : _buildMobile(card),
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
    if (_profile == null) return const SizedBox.shrink();
    
    final isEligible = _profile!.isEligible;
    return _card(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEligible ? Icons.verified_outlined : Icons.info_outline,
                color: isEligible ? const Color(0xFFBFAE01) : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                isEligible ? Provider.of<LanguageProvider>(context, listen: false).t('monetization.eligible') : Provider.of<LanguageProvider>(context, listen: false).t('monetization.review'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEligible
                ? Provider.of<LanguageProvider>(context, listen: false).t('monetization.eligible_desc')
                : Provider.of<LanguageProvider>(context, listen: false).t('monetization.review_desc'),
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
            Provider.of<LanguageProvider>(context, listen: false).t('monetization.earnings_summary'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metric(Provider.of<LanguageProvider>(context, listen: false).t('monetization.this_month'), '\$${(_summary?.thisMonth ?? 0.0).toStringAsFixed(2)}'),
              const SizedBox(width: 16),
              _metric(Provider.of<LanguageProvider>(context, listen: false).t('monetization.pending'), '\$${(_summary?.pending ?? 0.0).toStringAsFixed(2)}'),
              const SizedBox(width: 16),
              _metric(Provider.of<LanguageProvider>(context, listen: false).t('monetization.lifetime'), '\$${(_summary?.lifetime ?? 0.0).toStringAsFixed(2)}'),
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
                      Provider.of<LanguageProvider>(context, listen: false).t('monetization.view_analytics'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _profile?.payoutMethod == null
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
                          if (ok == true && mounted && _profile != null) {
                            final monetizationRepo = context.read<MonetizationRepository>();
                            final updatedProfile = MonetizationProfile(
                              userId: _profile!.userId,
                              isEligible: _profile!.isEligible,
                              isContentMonetized: _profile!.isContentMonetized,
                              isAdsEnabled: _profile!.isAdsEnabled,
                              isSponsorshipsEnabled: _profile!.isSponsorshipsEnabled,
                              payoutMethod: 'stripe',
                              payoutAccountId: 'stripe_account_id',
                              eligibleSince: _profile!.eligibleSince,
                              createdAt: _profile!.createdAt,
                              updatedAt: DateTime.now(),
                              hasMinFollowers: _profile!.hasMinFollowers,
                              hasMinPosts: _profile!.hasMinPosts,
                              isKycVerified: _profile!.isKycVerified,
                              has2FA: _profile!.has2FA,
                            );
                            await monetizationRepo.updateMonetizationProfile(updatedProfile);
                            setState(() => _profile = updatedProfile);
                            if (!mounted) return;
                            _snack(Provider.of<LanguageProvider>(context, listen: false).t('monetization.payout_connected'));
                          }
                        }
                      : () => _snack(Provider.of<LanguageProvider>(context, listen: false).t('monetization.manage_payout_placeholder')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    _profile?.payoutMethod == null ? Provider.of<LanguageProvider>(context, listen: false).t('monetization.setup_payout') : Provider.of<LanguageProvider>(context, listen: false).t('monetization.manage_payout'),
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
            Provider.of<LanguageProvider>(context, listen: false).t('monetization.monetized_content'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _switch(
            Provider.of<LanguageProvider>(context, listen: false).t('monetization.enable_new_posts'),
            _profile?.isContentMonetized ?? false,
            (v) => _updateSettings(contentMonetized: v),
          ),
          _switch(
            Provider.of<LanguageProvider>(context, listen: false).t('monetization.enable_ads'),
            _profile?.isAdsEnabled ?? false,
            (v) => _updateSettings(adsEnabled: v),
          ),
          _switch(
            Provider.of<LanguageProvider>(context, listen: false).t('monetization.allow_sponsorships'),
            _profile?.isSponsorshipsEnabled ?? false,
            (v) => _updateSettings(sponsorshipsEnabled: v),
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
            Provider.of<LanguageProvider>(context, listen: false).t('monetization.requirements'),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _req(Provider.of<LanguageProvider>(context, listen: false).t('monetization.req_followers'), _profile?.hasMinFollowers ?? false),
          _req(Provider.of<LanguageProvider>(context, listen: false).t('monetization.req_posts'), _profile?.hasMinPosts ?? false),
          _req(Provider.of<LanguageProvider>(context, listen: false).t('monetization.req_kyc'), _profile?.isKycVerified ?? false),
          _req(Provider.of<LanguageProvider>(context, listen: false).t('monetization.req_2fa'), _profile?.has2FA ?? false),
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
              onPressed: () => _snack('${Provider.of<LanguageProvider>(context, listen: false).t('monetization.action_required')}$text'),
              child: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('monetization.fix'),
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