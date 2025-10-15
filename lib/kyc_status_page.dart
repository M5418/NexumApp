// File: lib/kyc_status_page.dart
// Lines: 1-350
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/kyc_api.dart';
import 'core/profile_api.dart';
import 'core/auth_api.dart';

class KycStatusPage extends StatefulWidget {
  const KycStatusPage({super.key});

  @override
  State<KycStatusPage> createState() => _KycStatusPageState();
}

class _KycStatusPageState extends State<KycStatusPage> {
  Map<String, dynamic>? _kyc;
  bool _loading = true;
  String _accountDisplay = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await KycApi().getMine();
    if (res['ok'] == true) {
      final data = res['data'];
      if (mounted) _kyc = data == null ? null : Map<String, dynamic>.from(data);
    }
    await _loadAccountDisplay();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAccountDisplay() async {
    try {
      final profApi = ProfileApi();
      final profRes = await profApi.me();
      final body = Map<String, dynamic>.from(profRes);
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      final fullName = (data['full_name'] ?? '').toString();
      if (fullName.isNotEmpty) {
        _accountDisplay = fullName;
        return;
      }
    } catch (_) {}
    try {
      final authRes = await AuthApi().me();
      if (authRes['ok'] == true && authRes['data'] != null) {
        _accountDisplay = (authRes['data']['email'] ?? '-').toString();
      }
    } catch (_) {}
  }

  String _statusText(Map<String, dynamic>? kyc) {
    final s = (kyc?['status'] ?? 'pending').toString();
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    return 'Pending';
  }

  Color _statusColor(Map<String, dynamic>? kyc) {
    final s = (kyc?['status'] ?? 'pending').toString();
    if (s == 'approved') return const Color(0xFF22C55E);
    if (s == 'rejected') return const Color(0xFFEF4444);
    return const Color(0xFFBFAE01);
  }

  String _fmt(dynamic v) => (v == null || (v is String && v.isEmpty)) ? '-' : v.toString();

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
                    'NEXUM',
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
                              tooltip: 'Back',
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                            ),
                            Text(
                              'KYC Status',
                              style: GoogleFonts.inter(
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh',
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
                            status == 'Pending' ? 'Pending — answer within 24h' : status,
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
                          _buildDataTable(isDarkMode),
                        const SizedBox(height: 8),
                        Text(
                          'Note: Approval or rejection will be decided by an administrator.',
                          style: GoogleFonts.inter(color: const Color(0xFF666666), fontSize: 12),
                        ),
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

  Widget _buildDataTable(bool isDarkMode) {
    final files = _kyc?['uploaded_file_names'];
    final filesText = files == null
        ? '-'
        : (files is List ? files.map((e) => e.toString()).join(', ') : files.toString());

    final columns = <DataColumn>[
      DataColumn(label: _colLabel('Account')),
      DataColumn(label: _colLabel('Document Type')),
      DataColumn(label: _colLabel('Document Number')),
      DataColumn(label: _colLabel('Issue Place')),
      DataColumn(label: _colLabel('Issue Date')),
      DataColumn(label: _colLabel('Expiry Date')),
      DataColumn(label: _colLabel('Country')),
      DataColumn(label: _colLabel('City of Birth')),
      DataColumn(label: _colLabel('Address')),
      DataColumn(label: _colLabel('Uploaded File Names')),
      DataColumn(label: _colLabel('Front URL')),
      DataColumn(label: _colLabel('Back URL')),
      DataColumn(label: _colLabel('Selfie URL')),
      DataColumn(label: _colLabel('Status')),
      DataColumn(label: _colLabel('Approved')),
      DataColumn(label: _colLabel('Rejected')),
      DataColumn(label: _colLabel('Reviewed By')),
      DataColumn(label: _colLabel('Reviewed At')),
      DataColumn(label: _colLabel('Created At')),
      DataColumn(label: _colLabel('Updated At')),
    ];

    final cells = <DataCell>[
      DataCell(_cellText(_accountDisplay)),
      DataCell(_cellText(_fmt(_kyc?['document_type']))),
      DataCell(_cellText(_fmt(_kyc?['document_number']))),
      DataCell(_cellText(_fmt(_kyc?['issue_place']))),
      DataCell(_cellText(_fmt(_kyc?['issue_date']))),
      DataCell(_cellText(_fmt(_kyc?['expiry_date']))),
      DataCell(_cellText(_fmt(_kyc?['country']))),
      DataCell(_cellText(_fmt(_kyc?['city_of_birth']))),
      DataCell(_cellText(_fmt(_kyc?['address']))),
      DataCell(_cellText(filesText)),
      DataCell(_cellText(_fmt(_kyc?['front_url']))),
      DataCell(_cellText(_fmt(_kyc?['back_url']))),
      DataCell(_cellText(_fmt(_kyc?['selfie_url']))),
      DataCell(_cellText(_fmt(_kyc?['status']))),
      DataCell(_cellText(_fmt(_kyc?['is_approved']))),
      DataCell(_cellText(_fmt(_kyc?['is_rejected']))),
      DataCell(_cellText(_fmt(_kyc?['reviewed_by']))),
      DataCell(_cellText(_fmt(_kyc?['reviewed_at']))),
      DataCell(_cellText(_fmt(_kyc?['created_at']))),
      DataCell(_cellText(_fmt(_kyc?['updated_at']))),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 13,
        ),
        columns: columns,
        rows: [DataRow(cells: cells)],
      ),
    );
  }

  Widget _colLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text),
      );

  Widget _cellText(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text),
      );
}