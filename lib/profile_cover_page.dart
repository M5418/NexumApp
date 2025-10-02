import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_completion_welcome.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'core/profile_api.dart';
import 'responsive/responsive_breakpoints.dart';

class ProfileCoverPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;

  const ProfileCoverPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
    this.hasProfilePhoto = false,
  });

  @override
  State<ProfileCoverPage> createState() => _ProfileCoverPageState();
}

class _ProfileCoverPageState extends State<ProfileCoverPage> {
  bool _hasSelectedCover = false;
  Uint8List? _coverBytes;
  String? _coverExt;
  final ImagePicker _picker = ImagePicker();

  void _selectCover() {
    _showCoverSourceSheet();
  }

  void _showCoverSourceSheet() {
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
                title: Text('Take Photo', style: GoogleFonts.inter()),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickCover(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Choose from Gallery', style: GoogleFonts.inter()),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickCover(ImageSource.gallery);
                },
              ),
              if (_coverBytes != null || _hasSelectedCover)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Remove Cover',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _coverBytes = null;
                      _coverExt = null;
                      _hasSelectedCover = false;
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

  Future<void> _pickCover(ImageSource source) async {
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
              const SnackBar(
                content: Text('Permission denied. Please allow access to continue.'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (permissionStatus.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Access permanently denied. Please enable in settings.'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Settings',
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
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!mounted) return;
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _coverBytes = bytes;
          _coverExt = _guessExt(picked);
          _hasSelectedCover = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cover photo selected successfully!',
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
        const SnackBar(
          content: Text('Unexpected error occurred.'),
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
    if (!_hasSelectedCover || _coverBytes == null) return;
    final ctx = context;
    try {
      final url = await ProfileApi().uploadBytes(
        _coverBytes!,
        ext: _coverExt ?? 'jpg',
      );
      await ProfileApi().update({'cover_photo_url': url});
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload cover photo. You can try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToWelcome() async {
    await _uploadIfNeeded();
    if (!mounted) return;

    final next = ProfileCompletionWelcome(
      firstName: widget.firstName,
      lastName: widget.lastName,
    );

    if (!context.isMobile) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => next,
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
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => next),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: original gradient card layout unchanged
      return Scaffold(
        body: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [const Color(0xFF0C0C0C), const Color(0xFF0C0C0C)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)],
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
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 60),
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
                          Text(
                            'Add Cover Photo',
                            style: GoogleFonts.inter(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Choose a cover that represents your personality',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 32),
                          GestureDetector(
                            onTap: _selectCover,
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFBFAE01),
                                  width: 2,
                                ),
                                color: isDarkMode
                                    ? const Color(0xFF1A1A1A)
                                    : const Color(0xFFF5F5F5),
                              ),
                              child: _coverBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.memory(
                                        _coverBytes!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 200,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 48,
                                          color: isDarkMode
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add Cover Photo',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            color: isDarkMode
                                                ? Colors.white54
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _navigateToWelcome,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBFAE01),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _hasSelectedCover ? 'Complete Setup' : 'Skip for Now',
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
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
                            'Profil details',
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
                                'Add Cover Photo',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Choose a cover that represents your personality',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: _selectCover,
                                child: Container(
                                  width: double.infinity,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFBFAE01),
                                      width: 2,
                                    ),
                                    color: isDarkMode
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFFF5F5F5),
                                  ),
                                  child: _coverBytes != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.memory(
                                            _coverBytes!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 220,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate,
                                              size: 48,
                                              color: isDarkMode ? Colors.white54 : Colors.black54,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Cover Photo',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                color: isDarkMode ? Colors.white54 : Colors.black54,
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
                          onPressed: _navigateToWelcome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBFAE01),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Text(
                            _hasSelectedCover ? 'Complete Setup' : 'Skip for Now',
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
}