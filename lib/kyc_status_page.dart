import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';

import 'repositories/firebase/firebase_kyc_repository.dart';
import 'repositories/interfaces/kyc_repository.dart';

class KycStatusPage extends StatefulWidget {
  const KycStatusPage({super.key});

  @override
  State<KycStatusPage> createState() => _KycStatusPageState();
}

class _KycStatusPageState extends State<KycStatusPage> {
  KycModel? _kyc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final kycRepo = FirebaseKycRepository();
    final kyc = await kycRepo.getMyKyc();
    if (mounted) {
      setState(() {
        _kyc = kyc;
        _loading = false;
      });
    }
  }

  String _statusText(KycModel? kyc) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final s = kyc?.status ?? 'pending';
    if (s == 'approved') return lang.t('kyc_status.approved');
    if (s == 'rejected') return lang.t('kyc_status.rejected');
    return lang.t('kyc_status.pending');
  }

  Color _statusColor(KycModel? kyc) {
    final s = kyc?.status ?? 'pending';
    if (s == 'approved') return const Color(0xFF22C55E);
    if (s == 'rejected') return const Color(0xFFEF4444);
    return const Color(0xFFBFAE01);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final status = _statusText(_kyc);
    final statusColor = _statusColor(_kyc);

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFF0C0C0C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('app.name'),
                    style: GoogleFonts.inika(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 900),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.back'),
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                            ),
                            Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.title'),
                              style: GoogleFonts.inter(
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            IconButton(
                              tooltip: Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.refresh'),
                              onPressed: _loading ? null : _load,
                              icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            status == Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.pending') ? Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.pending_answer') : status,
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else
                          _buildStatusMessage(isDarkMode),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage(bool isDarkMode) {
    final status = _kyc?.status ?? 'pending';
    
    // Icon and color based on status
    IconData icon;
    Color iconColor;
    String title;
    String message;
    
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    if (status == 'approved') {
      icon = Icons.check_circle;
      iconColor = const Color(0xFF22C55E);
      title = lang.t('kyc_status.approved_title');
      message = lang.t('kyc_status.approved_msg');
    } else if (status == 'rejected') {
      icon = Icons.cancel;
      iconColor = const Color(0xFFEF4444);
      title = lang.t('kyc_status.rejected_title');
      message = lang.t('kyc_status.rejected_msg');
    } else {
      icon = Icons.schedule;
      iconColor = const Color(0xFFBFAE01);
      title = lang.t('kyc_status.pending_title');
      message = lang.t('kyc_status.pending_msg');
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          // Icon
          Icon(
            icon,
            size: 80,
            color: iconColor,
          ),
          const SizedBox(height: 24),
          
          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Message
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.6,
              color: const Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Additional info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: const Color(0xFF666666),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status == 'pending'
                        ? Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.email_pending')
                        : status == 'approved'
                        ? Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.email_approved')
                        : Provider.of<LanguageProvider>(context, listen: false).t('kyc_status.email_rejected'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF666666),
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
}