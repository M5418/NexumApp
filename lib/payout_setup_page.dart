import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          'Set up payout',
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
              MaterialPageRoute(builder: (_) => const PayoutSetupSuccessPage()),
            );
            if (!context.mounted) return;
            Navigator.pop(context, ok == true);
            return;
          }
          setState(() => _currentStep += 1);
        },
        steps: [
          Step(
            title: const Text('Country'),
            isActive: _currentStep >= 0,
            content: DropdownButtonFormField<String>(
              initialValue: _country,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: const [
                'Canada',
                'United States',
                'France',
                'Germany',
                'United Kingdom',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _country = v),
            ),
          ),
          Step(
            title: const Text('Account Type'),
            isActive: _currentStep >= 1,
            content: DropdownButtonFormField<String>(
              initialValue: _accountType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: const [
                'Individual',
                'Business',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _accountType = v),
            ),
          ),
          Step(
            title: const Text('Personal Details'),
            isActive: _currentStep >= 2,
            content: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dobCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth (YYYY-MM-DD)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Payout Method'),
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
                  items: const ['Stripe', 'Bank transfer']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _payoutProvider = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => _iban = v,
                  decoration: const InputDecoration(
                    labelText: 'IBAN / Account number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Tax & Verification'),
            isActive: _currentStep >= 4,
            content: Column(
              children: [
                CheckboxListTile(
                  value: _taxConfirmed,
                  onChanged: (v) => setState(() => _taxConfirmed = v ?? false),
                  title: Text(
                    'I confirm tax information will be submitted',
                    style: GoogleFonts.inter(),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _kycConfirmed,
                  onChanged: (v) => setState(() => _kycConfirmed = v ?? false),
                  title: Text(
                    'I will complete KYC verification if required',
                    style: GoogleFonts.inter(),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Review & Submit'),
            isActive: _currentStep >= 5,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Country', _country ?? ''),
                _row('Account type', _accountType ?? ''),
                _row('Full name', _nameCtrl.text),
                _row('Payout provider', _payoutProvider ?? ''),
                _row('Account', _iban ?? ''),
                const SizedBox(height: 12),
                Text(
                  'By submitting you agree to the payout terms.',
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
