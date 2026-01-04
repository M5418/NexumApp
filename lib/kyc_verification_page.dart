import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'repositories/firebase/firebase_kyc_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'kyc_status_page.dart';
import 'package:file_picker/file_picker.dart';
import 'core/files_api.dart';
import 'data/countries.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'core/i18n/language_provider.dart';

enum DocumentType { passport, nationalId, drivingLicense }

class KycVerificationPage extends StatefulWidget {
  const KycVerificationPage({super.key});

  @override
  State<KycVerificationPage> createState() => _KycVerificationPageState();
}

class _KycVerificationPageState extends State<KycVerificationPage> {
  DocumentType? _selectedDocumentType;
  CountryData? _selectedResidenceCountry;
  CountryData? _selectedIssuingCountry;

  // Document upload states
  bool _frontDocumentUploaded = false;
  bool _backDocumentUploaded = false;
  bool _selfieUploaded = false;

  // Uploaded URLs
  String? _frontUrl;
  String? _backUrl;
  String? _selfieUrl;

  // Input controllers
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityOfBirthController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();

  bool _submitting = false;
  bool _loadingUserData = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _loadingUserData = true);
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRepo = context.read<FirebaseUserRepository>();
      final userDoc = await userRepo.getUserProfile(user.uid);
      
      if (userDoc != null && mounted) {
        // Pre-fill with profile data if available
        final fullName = '${userDoc.firstName ?? ''} ${userDoc.lastName ?? ''}'.trim();
        if (fullName.isNotEmpty) {
          _fullNameController.text = fullName;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    } finally {
      if (mounted) setState(() => _loadingUserData = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _cityOfBirthController.dispose();
    _documentNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_loadingUserData) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFF0C0C0C)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
          ),
        ),
      );
    }

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
                    Provider.of<LanguageProvider>(context, listen: false).t('app.name'),
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
                          Provider.of<LanguageProvider>(context, listen: false).t('kyc.title'),
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtext
                        Text(
                          Provider.of<LanguageProvider>(context, listen: false).t('kyc.subtitle'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Document Type Selection
                        _buildSectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('kyc.document_type'), isDarkMode),
                        const SizedBox(height: 16),
                        _buildDocumentTypeSelector(isDarkMode),
                        const SizedBox(height: 24),

                        // Country of Residence
                        _buildSectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('kyc.country_residence'), isDarkMode),
                        const SizedBox(height: 16),
                        _buildCountryButton(
                          _selectedResidenceCountry,
                          () => _selectCountry(true),
                          isDarkMode,
                        ),
                        const SizedBox(height: 24),

                        // Document Issuing Country
                        _buildSectionTitle(
                          Provider.of<LanguageProvider>(context, listen: false).t('kyc.document_issuing'),
                          isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildCountryButton(
                          _selectedIssuingCountry,
                          () => _selectCountry(false),
                          isDarkMode,
                        ),
                        const SizedBox(height: 24),

                        // Personal Information
                        _buildSectionTitle('Personal Information', isDarkMode),
                        const SizedBox(height: 16),
                        _textField(isDarkMode, _fullNameController, 'Full Name'),
                        const SizedBox(height: 16),
                        _textField(isDarkMode, _addressController, 'Residential Address'),
                        const SizedBox(height: 16),
                        _textField(isDarkMode, _cityOfBirthController, 'City of Birth'),
                        const SizedBox(height: 24),

                        // Document Details
                        _buildSectionTitle('Document Details', isDarkMode),
                        const SizedBox(height: 16),
                        _textField(isDarkMode, _documentNumberController, Provider.of<LanguageProvider>(context, listen: false).t('kyc.document_number')),
                        const SizedBox(height: 16),
                        _textField(isDarkMode, _expiryDateController, Provider.of<LanguageProvider>(context, listen: false).t('kyc.expiry_date')),
                        const SizedBox(height: 32),

                        // Document Upload Section
                        if (_selectedDocumentType != null) ...[
                          _buildSectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('kyc.upload_documents'), isDarkMode),
                          const SizedBox(height: 16),
                          _buildDocumentUploadSection(isDarkMode),
                          const SizedBox(height: 32),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_canSubmit() && !_submitting)
                                ? _submit
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_canSubmit() && !_submitting)
                                  ? const Color(0xFFBFAE01)
                                  : const Color(0xFF666666),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('kyc.submit'),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Back to Account Center
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              Provider.of<LanguageProvider>(context, listen: false).t('kyc.back'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xFFBFAE01),
                                fontWeight: FontWeight.w500),
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

  Widget _textField(bool isDarkMode, TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: isDarkMode ? Colors.white : Colors.black, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: isDarkMode ? Colors.white : Colors.black, width: 1.5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
          borderSide: BorderSide(color: Color(0xFFBFAE01), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
    );
  }

  Widget _buildDocumentTypeSelector(bool isDarkMode) {
    return Column(
      children: [
        _buildDocumentOption(
          DocumentType.passport,
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.passport'),
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.passport_desc'),
          Icons.book,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildDocumentOption(
          DocumentType.nationalId,
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.national_id'),
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.national_id_desc'),
          Icons.credit_card,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildDocumentOption(
          DocumentType.drivingLicense,
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.driving_license'),
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.driving_license_desc'),
          Icons.directions_car,
          isDarkMode,
        ),
      ],
    );
  }
  // File: lib/kyc_verification_page.dart
// Lines: 431-820
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
          _frontUrl = null;
          _backUrl = null;
          _selfieUrl = null;
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

  Widget _buildCountryButton(
    CountryData? selectedCountry,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: onTap,
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
            Text(
              selectedCountry?.name ?? Provider.of<LanguageProvider>(context, listen: false).t('kyc.select_country'),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: selectedCountry == null
                    ? const Color(0xFF666666)
                    : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            Icon(
              Icons.search,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadSection(bool isDarkMode) {
    return Column(
      children: [
        // Front of document
        _buildUploadBox(
          '${Provider.of<LanguageProvider>(context, listen: false).t('kyc.front_doc')} ${_getDocumentName()}',
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.upload_front'),
          _frontDocumentUploaded,
          () => _handleUploadTap('front'),
          isDarkMode,
        ),
        const SizedBox(height: 16),

        // Back of document (only for National ID and Driving License)
        if (_selectedDocumentType != DocumentType.passport) ...[
          _buildUploadBox(
            '${Provider.of<LanguageProvider>(context, listen: false).t('kyc.back_doc')} ${_getDocumentName()}',
            Provider.of<LanguageProvider>(context, listen: false).t('kyc.upload_back'),
            _backDocumentUploaded,
            () => _handleUploadTap('back'),
            isDarkMode,
          ),
          const SizedBox(height: 16),
        ],

        // Selfie
        _buildUploadBox(
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.selfie'),
          Provider.of<LanguageProvider>(context, listen: false).t('kyc.upload_selfie'),
          _selfieUploaded,
          () => _handleUploadTap('selfie'),
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
              isUploaded ? Provider.of<LanguageProvider>(context, listen: false).t('kyc.uploaded') : subtitle,
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
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    switch (_selectedDocumentType) {
      case DocumentType.passport:
        return lang.t('kyc.passport');
      case DocumentType.nationalId:
        return lang.t('kyc.national_id');
      case DocumentType.drivingLicense:
        return lang.t('kyc.driving_license');
      default:
        return lang.t('kyc.document_type');
    }
  }

  bool _canSubmit() {
    if (_selectedDocumentType == null ||
        _selectedResidenceCountry == null ||
        _selectedIssuingCountry == null ||
        !_frontDocumentUploaded ||
        !_selfieUploaded ||
        _documentNumberController.text.trim().isEmpty) {
      return false;
    }

    // For National ID and Driving License, back photo is also required
    if (_selectedDocumentType != DocumentType.passport &&
        !_backDocumentUploaded) {
      return false;
    }

    return true;
  }

  Future<void> _selectCountry(bool isResidence) async {
    final selected = await showDialog<CountryData>(
      context: context,
      builder: (context) => const CountrySearchDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        if (isResidence) {
          _selectedResidenceCountry = selected;
        } else {
          _selectedIssuingCountry = selected;
        }
      });
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: GoogleFonts.inter())),
    );
  }

  Future<void> _handleUploadTap(String kind) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (result == null || result.files.isEmpty) return;

      final f = result.files.first;
      final bytes = f.bytes;
      final ext = (f.extension ?? '').toLowerCase();
      if (bytes == null) {
        _showSnack('Could not read file');
        return;
      }

      final filesApi = FilesApi();
      final res = await filesApi.uploadBytes(bytes, ext: ext.isEmpty ? 'bin' : ext);
      final uploadedUrl = (res['url'] ?? '').toString();

      if (uploadedUrl.isEmpty) {
        _showSnack('Upload failed');
        return;
      }

      setState(() {
        if (kind == 'front') {
          _frontUrl = uploadedUrl;
          _frontDocumentUploaded = true;
        } else if (kind == 'back') {
          _backUrl = uploadedUrl;
          _backDocumentUploaded = true;
        } else if (kind == 'selfie') {
          _selfieUrl = uploadedUrl;
          _selfieUploaded = true;
        }
      });
    } catch (_) {
      _showSnack('File selection/upload failed');
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit()) return;

    // Validate required user data
    if (_fullNameController.text.trim().isEmpty) {
      _showSnack('Please enter your full name.');
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnack('Please enter your address.');
      return;
    }
    if (_cityOfBirthController.text.trim().isEmpty) {
      _showSnack('Please enter your city of birth.');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Map selected type to a string value
      final String docType = () {
        switch (_selectedDocumentType) {
          case DocumentType.passport:
            return 'passport';
          case DocumentType.nationalId:
            return 'national_id';
          case DocumentType.drivingLicense:
            return 'driving_license';
          default:
            return 'unknown';
        }
      }();

      // Get current user ID
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('Please sign in first');
        return;
      }

      final kycRepo = FirebaseKycRepository();
      await kycRepo.submitKyc(
        userId: user.uid,
        fullName: _fullNameController.text.trim(),
        documentType: docType,
        documentNumber: _documentNumberController.text.trim(),
        issueCountry: _selectedIssuingCountry!.name,
        expiryDate: _expiryDateController.text.trim().isEmpty ? null : _expiryDateController.text.trim(),
        countryOfResidence: _selectedResidenceCountry!.name,
        address: _addressController.text.trim(),
        cityOfBirth: _cityOfBirthController.text.trim(),
        frontUrl: _frontUrl,
        backUrl: _backUrl,
        selfieUrl: _selfieUrl!,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(settings: const RouteSettings(name: 'kyc_status'), builder: (_) => const KycStatusPage()),
      );
    } catch (e) {
      _showSnack('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class CountrySearchDialog extends StatefulWidget {
  const CountrySearchDialog({super.key});

  @override
  State<CountrySearchDialog> createState() => _CountrySearchDialogState();
}

class _CountrySearchDialogState extends State<CountrySearchDialog> {
  final _searchController = TextEditingController();
  List<CountryData> _filteredCountries = allCountries;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = allCountries;
      } else {
        _filteredCountries = allCountries
            .where((country) =>
                country.name.toLowerCase().contains(query.toLowerCase()) ||
                country.code.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Country',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _filterCountries,
              decoration: InputDecoration(
                hintText: Provider.of<LanguageProvider>(context).t('kyc.search_countries'),
                hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFBFAE01)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCountries.length,
                itemBuilder: (context, index) {
                  final country = _filteredCountries[index];
                  return ListTile(
                    title: Text(
                      country.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      country.code,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    onTap: () => Navigator.pop(context, country),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}