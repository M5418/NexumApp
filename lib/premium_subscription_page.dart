import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/monetization_repository.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'repositories/models/monetization_models.dart';

class PremiumSubscriptionPage extends StatelessWidget {
  const PremiumSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final text = isDark ? Colors.white : Colors.black;

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
          Provider.of<LanguageProvider>(context, listen: false).t('premium.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
        centerTitle: true,
      ),
      body: const PremiumSubscriptionView(),
    );
  }
}

/// Reusable premium panel (no AppBar/Scaffold) to embed in dialogs.
class PremiumSubscriptionView extends StatefulWidget {
  const PremiumSubscriptionView({super.key});

  @override
  State<PremiumSubscriptionView> createState() => _PremiumSubscriptionViewState();
}

class _PremiumSubscriptionViewState extends State<PremiumSubscriptionView> {
  bool _yearly = true;
  PremiumSubscription? _activeSubscription;
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
      final subscription = await monetizationRepo.getActiveSubscription(user.uid);
      if (!mounted) return;
      setState(() {
        _activeSubscription = subscription;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading subscription: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribe() async {
    if (_userId == null) {
      _snack('Please sign in to subscribe');
      return;
    }

    final monetizationRepo = context.read<MonetizationRepository>();
    final amount = _yearly ? 76.99 : 7.99;
    final planType = _yearly ? 'yearly' : 'monthly';

    try {
      final nextBillingDate = DateTime.now().add(_yearly ? const Duration(days: 365) : const Duration(days: 30));
      
      final subscription = PremiumSubscription(
        id: '', // Will be set by repo
        userId: _userId!,
        planType: planType,
        amount: amount,
        status: 'active',
        startDate: DateTime.now(),
        nextBillingDate: nextBillingDate,
        paymentMethod: 'stripe',
        subscriptionId: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        autoRenew: true,
      );

      await monetizationRepo.createSubscription(subscription);
      
      if (!mounted) return;
      _snack('Successfully subscribed to \$$amount ${_yearly ? 'yearly' : 'monthly'} plan!');
      _loadData();
    } catch (e) {
      debugPrint('❌ Error subscribing: $e');
      if (!mounted) return;
      _snack('Failed to subscribe. Please try again.');
    }
  }

  Future<void> _cancelSubscription() async {
    if (_activeSubscription == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Subscription', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to cancel your premium subscription? Your access will continue until the end of your billing period.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Subscription', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final monetizationRepo = context.read<MonetizationRepository>();
    
    try {
      await monetizationRepo.cancelSubscription(_activeSubscription!.id);
      if (!mounted) return;
      _snack('Subscription cancelled successfully');
      _loadData();
    } catch (e) {
      debugPrint('❌ Error cancelling subscription: $e');
      if (!mounted) return;
      _snack('Failed to cancel subscription. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF000000) : Colors.white;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    if (_loading) {
      return Container(
        color: background,
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _heroCard(card),
        const SizedBox(height: 16),
        _featuresCard(card),
        const SizedBox(height: 16),
        _plansCard(card),
        const SizedBox(height: 16),
        _manageCard(card),
      ],
    );
  }

  Widget _heroCard(Color card) {
    final hasSubscription = _activeSubscription != null && _activeSubscription!.isActive;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: Color(0xFFBFAE01),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                Provider.of<LanguageProvider>(context, listen: false).t('premium.nexum_premium'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasSubscription) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFAE01),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasSubscription
                ? 'Plan: ${_activeSubscription!.planType.toUpperCase()} • Next billing: ${_formatDate(_activeSubscription!.nextBillingDate)}'
                : Provider.of<LanguageProvider>(context, listen: false).t('premium.subtitle'),
            style: GoogleFonts.inter(
              color: const Color(0xFF666666),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _featuresCard(Color card) => Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Provider.of<LanguageProvider>(context, listen: false).t('premium.what_you_get'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _feature('Ad-free experience'),
            _feature('Priority support'),
            _feature('Advanced analytics'),
            _feature('Creator tools & scheduling'),
            _feature('Premium badges'),
            _feature('Access to podcasts'),
          ],
        ),
      );

  Widget _feature(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFBFAE01), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  Widget _plansCard(Color card) => Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Provider.of<LanguageProvider>(context, listen: false).t('premium.choose_plan'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ToggleButtons(
              borderRadius: BorderRadius.circular(20),
              isSelected: [_yearly == false, _yearly == true],
              onPressed: (i) => setState(() => _yearly = i == 1),
              selectedColor: Colors.black,
              fillColor: const Color(0xFFBFAE01),
              color: const Color(0xFF666666),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Text(Provider.of<LanguageProvider>(context, listen: false).t('premium.monthly'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      Text(
                        '\$7.99',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Text(Provider.of<LanguageProvider>(context, listen: false).t('premium.yearly'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      Text(
                        '${Provider.of<LanguageProvider>(context, listen: false).t('premium.yearly_save')} · \$76.99',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _activeSubscription != null && _activeSubscription!.isActive ? null : () => _subscribe(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(Provider.of<LanguageProvider>(context, listen: false).t('premium.subscribe'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );

  Widget _manageCard(Color card) {
    final hasSubscription = _activeSubscription != null && _activeSubscription!.isActive;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Provider.of<LanguageProvider>(context, listen: false).t('premium.manage_subscription'),
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('premium.billing_history'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            onTap: () => _snack('Open billing history'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('premium.manage_badge'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            onTap: () => _snack('Manage badge'),
          ),
          if (hasSubscription)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('premium.cancel_subscription'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.red),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              onTap: _cancelSubscription,
            ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter())),
    );
  }
}
