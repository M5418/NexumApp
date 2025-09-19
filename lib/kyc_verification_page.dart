import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sign_in_page.dart';

enum DocumentType { passport, nationalId, drivingLicense }

class KycVerificationPage extends StatefulWidget {
  const KycVerificationPage({super.key});

  @override
  State<KycVerificationPage> createState() => _KycVerificationPageState();
}

class _KycVerificationPageState extends State<KycVerificationPage> {
  DocumentType? _selectedDocumentType;
  String _selectedResidenceCountry = 'Select Country';
  String _selectedIssuingCountry = 'Select Country';
  bool _showResidenceDropdown = false;
  bool _showIssuingDropdown = false;

  // Document upload states
  bool _frontDocumentUploaded = false;
  bool _backDocumentUploaded = false;
  bool _selfieUploaded = false;

  final List<Map<String, String>> _countries = [
    {'name': 'United States', 'flag': '🇺🇸', 'code': 'US'},
    {'name': 'Canada', 'flag': '🇨🇦', 'code': 'CA'},
    {'name': 'United Kingdom', 'flag': '🇬🇧', 'code': 'GB'},
    {'name': 'France', 'flag': '🇫🇷', 'code': 'FR'},
    {'name': 'Germany', 'flag': '🇩🇪', 'code': 'DE'},
    {'name': 'Australia', 'flag': '🇦🇺', 'code': 'AU'},
    {'name': 'Japan', 'flag': '🇯🇵', 'code': 'JP'},
    {'name': 'South Korea', 'flag': '🇰🇷', 'code': 'KR'},
    {'name': 'Brazil', 'flag': '🇧🇷', 'code': 'BR'},
    {'name': 'Mexico', 'flag': '🇲🇽', 'code': 'MX'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                  // NEXUM Title
                  Text(
                    'NEXUM',
                    style: GoogleFonts.inika(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // KYC Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF000000)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // KYC Verification Headline
                        Text(
                          'Identity Verification',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtext
                        Text(
                          'Please provide your identification documents to verify your identity',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Document Type Selection
                        _buildSectionTitle('Document Type', isDarkMode),
                        const SizedBox(height: 16),
                        _buildDocumentTypeSelector(isDarkMode),
                        const SizedBox(height: 24),

                        // Country of Residence
                        _buildSectionTitle('Country of Residence', isDarkMode),
                        const SizedBox(height: 16),
                        _buildCountrySelector(
                          _selectedResidenceCountry,
                          _showResidenceDropdown,
                          (value) => setState(() {
                            _showResidenceDropdown = value;
                            _showIssuingDropdown = false;
                          }),
                          (country) => setState(() {
                            _selectedResidenceCountry = country;
                            _showResidenceDropdown = false;
                          }),
                          isDarkMode,
                        ),
                        const SizedBox(height: 24),

                        // Document Issuing Country
                        _buildSectionTitle(
                          'Document Issuing Country',
                          isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildCountrySelector(
                          _selectedIssuingCountry,
                          _showIssuingDropdown,
                          (value) => setState(() {
                            _showIssuingDropdown = value;
                            _showResidenceDropdown = false;
                          }),
                          (country) => setState(() {
                            _selectedIssuingCountry = country;
                            _showIssuingDropdown = false;
                          }),
                          isDarkMode,
                        ),
                        const SizedBox(height: 32),

                        // Document Upload Section
                        if (_selectedDocumentType != null) ...[
                          _buildSectionTitle('Upload Documents', isDarkMode),
                          const SizedBox(height: 16),
                          _buildDocumentUploadSection(isDarkMode),
                          const SizedBox(height: 32),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canSubmit()
                                ? () {
                                    // KYC submission logic - UI only
                                    _showSubmissionDialog(context);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canSubmit()
                                  ? const Color(0xFFBFAE01)
                                  : const Color(0xFF666666),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Submit for Verification',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Back to Sign In
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignInPage(),
                                ),
                                (route) => false,
                              );
                            },
                            child: Text(
                              'Back to Sign In',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xFFBFAE01),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
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

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildDocumentTypeSelector(bool isDarkMode) {
    return Column(
      children: [
        _buildDocumentOption(
          DocumentType.passport,
          'Passport',
          'International travel document',
          Icons.book,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildDocumentOption(
          DocumentType.nationalId,
          'National ID',
          'Government-issued ID card',
          Icons.credit_card,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildDocumentOption(
          DocumentType.drivingLicense,
          'Driving License',
          'Valid driver\'s license',
          Icons.directions_car,
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildDocumentOption(
    DocumentType type,
    String title,
    String subtitle,
    IconData icon,
    bool isDarkMode,
  ) {
    final isSelected = _selectedDocumentType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDocumentType = type;
          // Reset upload states when changing document type
          _frontDocumentUploaded = false;
          _backDocumentUploaded = false;
          _selfieUploaded = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBFAE01)
                : (isDarkMode ? Colors.white : Colors.black),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? const Color(0xFFBFAE01).withAlpha(25)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFBFAE01)
                  : const Color(0xFF666666),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFBFAE01),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountrySelector(
    String selectedCountry,
    bool showDropdown,
    Function(bool) onToggle,
    Function(String) onSelect,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => onToggle(!showDropdown),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkMode ? Colors.white : Colors.black,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (selectedCountry != 'Select Country')
                      Text(
                        _countries.firstWhere(
                          (country) => country['name'] == selectedCountry,
                          orElse: () => {'flag': '🌍'},
                        )['flag']!,
                        style: const TextStyle(fontSize: 18),
                      ),
                    if (selectedCountry != 'Select Country')
                      const SizedBox(width: 8),
                    Text(
                      selectedCountry,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: selectedCountry == 'Select Country'
                            ? const Color(0xFF666666)
                            : (isDarkMode ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
                Icon(
                  showDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ],
            ),
          ),
        ),
        if (showDropdown) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF0C0C0C)
                  : const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.white : Colors.black,
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: _countries.map((country) {
                  return GestureDetector(
                    onTap: () => onSelect(country['name']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _countries.last == country
                                ? Colors.transparent
                                : (isDarkMode ? Colors.white : Colors.black),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            country['flag']!,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            country['name']!,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentUploadSection(bool isDarkMode) {
    return Column(
      children: [
        // Front of document
        _buildUploadBox(
          'Front of ${_getDocumentName()}',
          'Upload a clear photo of the front',
          _frontDocumentUploaded,
          () =>
              setState(() => _frontDocumentUploaded = !_frontDocumentUploaded),
          isDarkMode,
        ),
        const SizedBox(height: 16),

        // Back of document (only for National ID and Driving License)
        if (_selectedDocumentType != DocumentType.passport) ...[
          _buildUploadBox(
            'Back of ${_getDocumentName()}',
            'Upload a clear photo of the back',
            _backDocumentUploaded,
            () =>
                setState(() => _backDocumentUploaded = !_backDocumentUploaded),
            isDarkMode,
          ),
          const SizedBox(height: 16),
        ],

        // Selfie
        _buildUploadBox(
          'Selfie with Document',
          'Take a selfie holding your document',
          _selfieUploaded,
          () => setState(() => _selfieUploaded = !_selfieUploaded),
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildUploadBox(
    String title,
    String subtitle,
    bool isUploaded,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isUploaded
                ? const Color(0xFFBFAE01)
                : const Color(0xFF666666),
            width: 2,
            style: isUploaded ? BorderStyle.solid : BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isUploaded
              ? const Color(0xFFBFAE01).withAlpha(25)
              : (isDarkMode
                    ? const Color(0xFF0C0C0C)
                    : const Color(0xFFF1F4F8)),
        ),
        child: Column(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.cloud_upload_outlined,
              size: 40,
              color: isUploaded
                  ? const Color(0xFFBFAE01)
                  : const Color(0xFF666666),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isUploaded ? 'Uploaded successfully' : subtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDocumentName() {
    switch (_selectedDocumentType) {
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.nationalId:
        return 'National ID';
      case DocumentType.drivingLicense:
        return 'Driving License';
      default:
        return 'Document';
    }
  }

  bool _canSubmit() {
    if (_selectedDocumentType == null ||
        _selectedResidenceCountry == 'Select Country' ||
        _selectedIssuingCountry == 'Select Country' ||
        !_frontDocumentUploaded ||
        !_selfieUploaded) {
      return false;
    }

    // For National ID and Driving License, back photo is also required
    if (_selectedDocumentType != DocumentType.passport &&
        !_backDocumentUploaded) {
      return false;
    }

    return true;
  }

  void _showSubmissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Verification Submitted',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Your documents have been submitted for verification. You will receive an email notification once the review is complete.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF666666),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInPage()),
                  (route) => false,
                );
              },
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFBFAE01),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
