import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_photo_page.dart';
import 'core/profile_api.dart';
import 'core/i18n/language_provider.dart';
import 'responsive/responsive_breakpoints.dart';

class ProfileAddressPage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ProfileAddressPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ProfileAddressPage> createState() => _ProfileAddressPageState();
}

class _ProfileAddressPageState extends State<ProfileAddressPage> {
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  String? _selectedCountry;
  bool _isSaving = false;

  final List<String> _countries = [
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'Brazil',
    'India',
    'China',
    'Mexico',
    'Italy',
    'Spain',
    'Netherlands',
    'Sweden',
    'Norway',
    'Denmark',
    'Finland',
    'Switzerland',
    'Austria',
    'Belgium',
    'Portugal',
    'Ireland',
    'New Zealand',
    'South Korea',
    'Singapore',
    'Hong Kong',
    'Taiwan',
    'Thailand',
    'Malaysia',
    'Philippines',
    'Indonesia',
    'Vietnam',
    'South Africa',
    'Egypt',
    'Nigeria',
    'Kenya',
    'Morocco',
    'Argentina',
    'Chile',
    'Colombia',
    'Peru',
    'Venezuela',
    'Ecuador',
    'Uruguay',
    'Paraguay',
    'Bolivia',
    'Costa Rica',
    'Panama',
    'Guatemala',
    'Honduras',
    'El Salvador',
    'Nicaragua',
    'Dominican Republic',
    'Jamaica',
    'Trinidad and Tobago',
    'Barbados',
    'Bahamas',
    'Cuba',
    'Haiti',
    'Puerto Rico',
    'Israel',
    'Saudi Arabia',
    'UAE',
    'Qatar',
    'Kuwait',
    'Bahrain',
    'Oman',
    'Jordan',
    'Lebanon',
    'Turkey',
    'Iran',
    'Iraq',
    'Pakistan',
    'Bangladesh',
    'Sri Lanka',
    'Nepal',
    'Myanmar',
    'Cambodia',
    'Laos',
    'Mongolia',
    'Kazakhstan',
    'Uzbekistan',
    'Kyrgyzstan',
    'Tajikistan',
    'Turkmenistan',
    'Afghanistan',
    'Russia',
    'Ukraine',
    'Belarus',
    'Poland',
    'Czech Republic',
    'Slovakia',
    'Hungary',
    'Romania',
    'Bulgaria',
    'Croatia',
    'Serbia',
    'Bosnia and Herzegovina',
    'Montenegro',
    'North Macedonia',
    'Albania',
    'Slovenia',
    'Estonia',
    'Latvia',
    'Lithuania',
    'Moldova',
    'Georgia',
    'Armenia',
    'Azerbaijan',
  ];

  bool get _isFormValid {
    return _streetController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _stateController.text.isNotEmpty &&
        _postalCodeController.text.isNotEmpty &&
        _selectedCountry != null;
  }

  @override
  void initState() {
    super.initState();
    _streetController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _postalCodeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: original layout unchanged
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          Provider.of<LanguageProvider>(context).t('profile_setup.title'),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  Provider.of<LanguageProvider>(context).t('profile_setup.location_question'),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Provider.of<LanguageProvider>(context).t('profile_setup.location_help'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 32),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Street Address
                        TextField(
                          controller: _streetController,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: Provider.of<LanguageProvider>(context).t('profile_setup.street'),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF666666),
                            ),
                            hintText: Provider.of<LanguageProvider>(context).t('profile_setup.street_hint'),
                            hintStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF999999),
                            ),
                            border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF666666)),
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF666666)),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFFBFAE01),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // City and State/Province Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cityController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: Provider.of<LanguageProvider>(context).t('profile_setup.city'),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  hintText: Provider.of<LanguageProvider>(context).t('profile_setup.city_hint'),
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF999999),
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFFBFAE01),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _stateController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: Provider.of<LanguageProvider>(context).t('profile_setup.state'),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  hintText: Provider.of<LanguageProvider>(context).t('profile_setup.state_hint'),
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF999999),
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFFBFAE01),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Postal Code and Country Row
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _postalCodeController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: Provider.of<LanguageProvider>(context).t('profile_setup.postal'),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  hintText: Provider.of<LanguageProvider>(context).t('profile_setup.postal_hint'),
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF999999),
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFFBFAE01),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCountry,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: Provider.of<LanguageProvider>(context).t('profile_setup.country'),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFFBFAE01),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                dropdownColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                                items: _countries.map((String country) {
                                  return DropdownMenuItem<String>(
                                    value: country,
                                    child: Text(
                                      country,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedCountry = newValue;
                                  });
                                },
                                hint: Text(
                                  Provider.of<LanguageProvider>(context).t('profile_setup.select_country'),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF999999),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Next Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isFormValid && !_isSaving ? _saveAndNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isFormValid && !_isSaving)
                          ? const Color(0xFFBFAE01)
                          : const Color(0xFFCCCCCC),
                      foregroundColor: (_isFormValid && !_isSaving)
                          ? Colors.black
                          : const Color(0xFF666666),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _isSaving ? Provider.of<LanguageProvider>(context).t('profile_setup.saving') : Provider.of<LanguageProvider>(context).t('profile_setup.next'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // DESKTOP: centered popup card
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: isDarkMode ? const Color(0xFF000000) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header row (replaces app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile Setup',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0x1A666666)),

                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Where are you located?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Help others find and connect with you by sharing your location.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Same form fields as mobile
                              TextField(
                                controller: _streetController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: Provider.of<LanguageProvider>(context).t('profile_setup.street'),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  hintText: Provider.of<LanguageProvider>(context).t('profile_setup.street_hint'),
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF999999),
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF666666)),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF666666)),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _cityController,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: Provider.of<LanguageProvider>(context).t('profile_setup.city'),
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF666666),
                                        ),
                                        hintText: Provider.of<LanguageProvider>(context).t('profile_setup.city_hint'),
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF999999),
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        enabledBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: _stateController,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: Provider.of<LanguageProvider>(context).t('profile_setup.state'),
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF666666),
                                        ),
                                        hintText: Provider.of<LanguageProvider>(context).t('profile_setup.state_hint'),
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF999999),
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        enabledBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: _postalCodeController,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: Provider.of<LanguageProvider>(context).t('profile_setup.postal'),
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF666666),
                                        ),
                                        hintText: Provider.of<LanguageProvider>(context).t('profile_setup.postal_hint'),
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF999999),
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        enabledBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedCountry,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white : Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: Provider.of<LanguageProvider>(context).t('profile_setup.country'),
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF666666),
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        enabledBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF666666)),
                                        ),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      dropdownColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                                      items: _countries.map((String country) {
                                        return DropdownMenuItem<String>(
                                          value: country,
                                          child: Text(
                                            country,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: isDarkMode ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedCountry = newValue;
                                        });
                                      },
                                      hint: Text(
                                        Provider.of<LanguageProvider>(context).t('profile_setup.select_country'),
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF999999),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isFormValid && !_isSaving ? _saveAndNext : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_isFormValid && !_isSaving)
                                ? const Color(0xFFBFAE01)
                                : const Color(0xFFCCCCCC),
                            foregroundColor: (_isFormValid && !_isSaving)
                                ? Colors.black
                                : const Color(0xFF666666),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            _isSaving ? Provider.of<LanguageProvider>(context).t('profile_setup.saving') : Provider.of<LanguageProvider>(context).t('profile_setup.next'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pushWithPopupTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ));
  }

  Future<void> _saveAndNext() async {
    setState(() => _isSaving = true);
    try {
      await ProfileApi().update({
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'country': _selectedCountry,
      });

      if (!mounted) return;

      final next = ProfilePhotoPage(
        firstName: widget.firstName,
        lastName: widget.lastName,
      );

      if (!context.isMobile) {
        _pushWithPopupTransition(context, next);
      } else {
        Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'profile_bio'), builder: (_) => next));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('profile_setup.save_failed'),
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}