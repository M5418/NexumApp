import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'payout_setup_success_page.dart';

class PayoutSetupPage extends StatefulWidget {
  const PayoutSetupPage({super.key});

  @override
  State<PayoutSetupPage> createState() => _PayoutSetupPageState();
}

class _PayoutSetupPageState extends State<PayoutSetupPage> {
  int _currentStep = 0;

  String? _country = 'Canada';
  String? _accountType = 'Individual';

  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _payoutProvider; // e.g., Stripe
  String? _iban; // or bank account number

  bool _taxConfirmed = false;
  bool _kycConfirmed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('payout.title'),
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepCancel: _currentStep == 0
            ? null
            : () => setState(() => _currentStep -= 1),
        onStepContinue: () async {
          if (_currentStep == 5) {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(settings: const RouteSettings(name: 'monetization'), builder: (_) => const PayoutSetupSuccessPage()),
            );
            if (!context.mounted) return;
            Navigator.pop(context, ok == true);
            return;
          }
          setState(() => _currentStep += 1);
        },
        steps: [
          Step(
            title: Text(Provider.of<LanguageProvider>(context, listen: false).t('payout.step_country')),
            isActive: _currentStep >= 0,
            content: DropdownButtonFormField<String>(
              initialValue: _country,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: [
                Provider.of<LanguageProvider>(context, listen: false).t('payout.country_canada'),
                Provider.of<LanguageProvider>(context, listen: false).t('payout.country_us'),
                Provider.of<LanguageProvider>(context, listen: false).t('payout.country_france'),
                Provider.of<LanguageProvider>(context, listen: false).t('payout.country_germany'),
                Provider.of<LanguageProvider>(context, listen: false).t('payout.country_uk'),
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _country = v),
            ),
          ),
          Step(
            title: Text(Provider.of<LanguageProvider>(context, listen: false).t('payout.step_account_type')),
            isActive: _currentStep >= 1,
            content: DropdownButtonFormField<String>(
              initialValue: _accountType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: [
                Provider.of<LanguageProvider>(context, listen: false).t('payout.individual'),
                Provider.of<LanguageProvider>(context, listen: false).t('payout.business'),
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _accountType = v),
            ),
          ),
          Step(
            title: Text(Provider.of<LanguageProvider>(context, listen: false).t('payout.step_personal')),
            isActive: _currentStep >= 2,
            content: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).t('payout.full_name'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dobCtrl,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).t('payout.date_birth'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).t('payout.address'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: Text(Provider.of<LanguageProvider>(context, listen: false).t('payout.step_method')),
            isActive: _currentStep >= 3,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _payoutProvider,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  items: [
                    Provider.of<LanguageProvider>(context, listen: false).t('payout.stripe'),
                    Provider.of<LanguageProvider>(context, listen: false).t('payout.bank_transfer'),
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _payoutProvider = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => _iban = v,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).t('payout.iban'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: Text(Provider.of<LanguageProvider>(context, listen: false).t('payout.step_tax')),
            isActive: _currentStep >= 4,
            content: Column(
              children: [
                CheckboxListTile(
                  value: _taxConfirmed,
                  onChanged: (v) => setState(() => _taxConfirmed = v ?? false),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('payout.confirm_tax'),
                    style: GoogleFonts.inter(),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _kycConfirmed,
                  onChanged: (v) => setState(() => _kycConfirmed = v ?? false),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('payout.confirm_kyc'),
                    style: GoogleFonts.inter(),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          Step(
            title: Text(Provider.of<LanguageProvider>(context, listen: false).t('payout.step_review')),
            isActive: _currentStep >= 5,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Provider.of<LanguageProvider>(context, listen: false).t('payout.review_country'), _country ?? ''),
                _row(Provider.of<LanguageProvider>(context, listen: false).t('payout.review_account_type'), _accountType ?? ''),
                _row(Provider.of<LanguageProvider>(context, listen: false).t('payout.review_full_name'), _nameCtrl.text),
                _row(Provider.of<LanguageProvider>(context, listen: false).t('payout.payout_provider'), _payoutProvider ?? ''),
                _row(Provider.of<LanguageProvider>(context, listen: false).t('payout.account'), _iban ?? ''),
                const SizedBox(height: 12),
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('payout.agree_terms'),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            k,
            style: GoogleFonts.inter(color: const Color(0xFF666666)),
          ),
        ),
        Expanded(
          child: Text(v, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
