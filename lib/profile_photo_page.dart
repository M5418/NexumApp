import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'profile_cover_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'core/profile_api.dart';
import 'responsive/responsive_breakpoints.dart';
import 'services/onboarding_service.dart';
import 'widgets/onboarding_app_bar_actions.dart';

class ProfilePhotoPage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ProfilePhotoPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ProfilePhotoPage> createState() => _ProfilePhotoPageState();
}

class _ProfilePhotoPageState extends State<ProfilePhotoPage> {
  bool _hasSelectedPhoto = false;
  Uint8List? _photoBytes;
  String? _photoExt;
  final ImagePicker _picker = ImagePicker();

  void _selectPhoto() {
    _showPhotoSourceSheet();
  }

  void _showPhotoSourceSheet() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(lang.t('profile_photo.take_photo'), style: GoogleFonts.inter()),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(lang.t('profile_photo.choose_gallery'), style: GoogleFonts.inter()),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_photoBytes != null || _hasSelectedPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    lang.t('common.delete'),
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _photoBytes = null;
                      _photoExt = null;
                      _hasSelectedPhoto = false;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      if (!kIsWeb) {
        PermissionStatus permissionStatus;
        try {
          if (source == ImageSource.camera) {
            permissionStatus = await Permission.camera.request();
          } else {
            permissionStatus = await Permission.photos.request();
          }
        } catch (_) {
          permissionStatus = source == ImageSource.camera
              ? await Permission.camera.request()
              : await Permission.storage.request();
        }
        if (!mounted) return;
        if (!permissionStatus.isGranted) {
          if (permissionStatus.isDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.permission_denied')),
                backgroundColor: Colors.red,
              ),
            );
          } else if (permissionStatus.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.permission_denied_settings')),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: Provider.of<LanguageProvider>(context, listen: false).t('common.settings'),
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (!mounted) return;
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _photoBytes = bytes;
          _photoExt = _guessExt(picked);
          _hasSelectedPhoto = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo selected successfully!',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFFBFAE01),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.unexpected_error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _guessExt(XFile f) {
    final nameOrPath = (f.name.isNotEmpty ? f.name : f.path);
    final idx = nameOrPath.lastIndexOf('.');
    if (idx != -1 && idx < nameOrPath.length - 1) {
      return nameOrPath.substring(idx + 1).toLowerCase();
    }
    return 'jpg';
  }

  Future<void> _uploadIfNeeded() async {
    if (!_hasSelectedPhoto || _photoBytes == null) return;
    final ctx = context;
    try {
      final url = await ProfileApi().uploadBytes(
        _photoBytes!,
        ext: _photoExt ?? 'jpg',
      );
      await ProfileApi().update({'profile_photo_url': url});
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.upload_photo_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToNextPage() async {
    await _uploadIfNeeded();
    
    // Update onboarding step
    await OnboardingService().setStep(OnboardingStep.cover);
    
    if (!mounted) return;

    final next = ProfileCoverPage(
      firstName: widget.firstName,
      lastName: widget.lastName,
      hasProfilePhoto: _hasSelectedPhoto,
    );

    if (!context.isMobile) {
      _pushWithPopupTransition(context, next);
    } else {
      Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'profile_cover'), builder: (_) => next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: app bar pattern like other steps (no gradient)
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
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
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            lang.t('profile_photo.title'),
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        OnboardingAppBarActions(isDark: isDark),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                lang.t('profile_photo.add_photo'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.t('profile_photo.choose_represents'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _selectPhoto,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFBFAE01),
                      width: 3,
                    ),
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  ),
                  child: _photoBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _photoBytes!,
                            fit: BoxFit.cover,
                            width: 200,
                            height: 200,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.t('profile_photo.add_button'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _navigateToNextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _hasSelectedPhoto ? lang.t('profile_photo.continue') : lang.t('profile_photo.skip'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    // DESKTOP: centered popup card
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: isDark ? const Color(0xFF000000) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header row (replaces app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profil details',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
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
                                'Add Profile Photo',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Choose a photo that represents you',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: _selectPhoto,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFBFAE01),
                                      width: 3,
                                    ),
                                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                                  ),
                                  child: _photoBytes != null
                                      ? ClipOval(
                                          child: Image.memory(
                                            _photoBytes!,
                                            fit: BoxFit.cover,
                                            width: 200,
                                            height: 200,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              size: 48,
                                              color: isDark ? Colors.white54 : Colors.black54,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Photo',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                color: isDark ? Colors.white54 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _navigateToNextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBFAE01),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Text(
                            _hasSelectedPhoto ? 'Continue' : 'Skip for Now',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
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
}