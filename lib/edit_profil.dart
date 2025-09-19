import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'interest_selection_page.dart';

class ExperienceItem {
  final String title;
  final String? subtitle;

  const ExperienceItem({required this.title, this.subtitle});
}

class TrainingItem {
  final String title;
  final String? subtitle;

  const TrainingItem({required this.title, this.subtitle});
}

class ProfileEditResult {
  final String? profileImagePath; // local path if picked
  final String? coverImagePath; // local path if picked
  final String? profileImageUrl; // keep original if not changed
  final String? coverImageUrl; // keep original if not changed
  final String username;
  final String bio;
  final List<ExperienceItem> experiences;
  final List<TrainingItem> trainings;
  final List<String> interests;

  const ProfileEditResult({
    this.profileImagePath,
    this.coverImagePath,
    this.profileImageUrl,
    this.coverImageUrl,
    required this.username,
    required this.bio,
    required this.experiences,
    required this.trainings,
    required this.interests,
  });
}

class EditProfilPage extends StatefulWidget {
  final String fullName; // immutable (not editable)
  final String username;
  final String bio;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final List<ExperienceItem> experiences;
  final List<TrainingItem> trainings;
  final List<String> interests;

  const EditProfilPage({
    super.key,
    required this.fullName,
    required this.username,
    required this.bio,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    required this.experiences,
    required this.trainings,
    required this.interests,
  });

  @override
  State<EditProfilPage> createState() => _EditProfilPageState();
}

class _EditProfilPageState extends State<EditProfilPage> {
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  // Images
  String? _localProfilePath;
  String? _localCoverPath;
  String? _remoteProfileUrl;
  String? _remoteCoverUrl;

  // Lists
  late List<ExperienceItem> _experiences;
  late List<TrainingItem> _trainings;
  late List<String> _interests;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _bioController = TextEditingController(text: widget.bio);

    _remoteProfileUrl = widget.profilePhotoUrl;
    _remoteCoverUrl = widget.coverPhotoUrl;

    _experiences = [...widget.experiences];
    _trainings = [...widget.trainings];
    _interests = [...widget.interests];
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isCover}) async {
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
                onTap: () {
                  Navigator.pop(context);
                  _handlePick(source: ImageSource.camera, isCover: isCover);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Choose from Gallery', style: GoogleFonts.inter()),
                onTap: () {
                  Navigator.pop(context);
                  _handlePick(source: ImageSource.gallery, isCover: isCover);
                },
              ),
              if ((isCover &&
                      (_localCoverPath != null || _remoteCoverUrl != null)) ||
                  (!isCover &&
                      (_localProfilePath != null || _remoteProfileUrl != null)))
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Remove Photo',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      if (isCover) {
                        _localCoverPath = null;
                        _remoteCoverUrl = null;
                      } else {
                        _localProfilePath = null;
                        _remoteProfileUrl = null;
                      }
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

  Future<void> _handlePick({
    required ImageSource source,
    required bool isCover,
  }) async {
    PermissionStatus status;
    try {
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        status = await Permission.photos.request();
      }
    } catch (_) {
      status = source == ImageSource.camera
          ? await Permission.camera.request()
          : await Permission.storage.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      try {
        final XFile? picked = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        if (!mounted) return;
        if (picked != null) {
          setState(() {
            if (isCover) {
              _localCoverPath = picked.path;
              _remoteCoverUrl = null;
            } else {
              _localProfilePath = picked.path;
              _remoteProfileUrl = null;
            }
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
          const SnackBar(
            content: Text('Unexpected error occurred.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied. Please allow access to continue.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Access permanently denied. Please enable in settings.',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  ImageProvider? _coverProvider() {
    final p = _localCoverPath;
    if (p != null && p.isNotEmpty) {
      return FileImage(File(p));
    }
    final u = _remoteCoverUrl;
    if (u != null && u.isNotEmpty) {
      return NetworkImage(u);
    }
    return null;
  }

  ImageProvider? _profileProvider() {
    final p = _localProfilePath;
    if (p != null && p.isNotEmpty) {
      return FileImage(File(p));
    }
    final u = _remoteProfileUrl;
    if (u != null && u.isNotEmpty) {
      return NetworkImage(u);
    }
    return null;
  }

  void _addExperience() {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          title: Text('Add Experience', style: GoogleFonts.inter()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subtitle (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            TextButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final sub = subtitleCtrl.text.trim();
                if (title.isNotEmpty) {
                  setState(() {
                    _experiences = [
                      ..._experiences,
                      ExperienceItem(
                        title: title,
                        subtitle: sub.isEmpty ? null : sub,
                      ),
                    ];
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text(
                'Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addTraining() {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          title: Text('Add Training', style: GoogleFonts.inter()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'School / Program',
                ),
              ),
              TextField(
                controller: subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            TextButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final sub = subtitleCtrl.text.trim();
                if (title.isNotEmpty) {
                  setState(() {
                    _trainings = [
                      ..._trainings,
                      TrainingItem(
                        title: title,
                        subtitle: sub.isEmpty ? null : sub,
                      ),
                    ];
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text(
                'Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _save() {
    final result = ProfileEditResult(
      profileImagePath: _localProfilePath,
      coverImagePath: _localCoverPath,
      profileImageUrl: _remoteProfileUrl,
      coverImageUrl: _remoteCoverUrl,
      username: _usernameController.text.trim(),
      bio: _bioController.text.trim(),
      experiences: _experiences,
      trainings: _trainings,
      interests: _interests,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0),
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
                        'Edit Profile',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      // Removed per request: top-right Save button (use bottom bar only)
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
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Cover + Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                      image: _coverProvider() != null
                          ? DecorationImage(
                              image: _coverProvider()!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF000000)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.photo_camera_outlined),
                      color: isDarkMode ? Colors.white : Colors.black,
                      onPressed: () => _pickImage(isCover: true),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF1F1F1F)
                                  : Colors.white,
                              width: 4,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 58,
                            backgroundColor: isDarkMode
                                ? const Color(0xFF1A1A1A)
                                : Colors.white,
                            backgroundImage: _profileProvider(),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _pickImage(isCover: false),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFBFAE01),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Full name (read-only)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full name',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: widget.fullName),
                    enabled: false,
                    decoration: const InputDecoration(
                      hintText: 'Full name is immutable after verification',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Username
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Username',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bio
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bio',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Tell something about you',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Experiences
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.work,
                    size: 20,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Professional Experiences',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _addExperience,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _experiences.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final e = entry.value;
                  return Card(
                    color: isDarkMode ? const Color(0xFF000000) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: ListTile(
                      title: Text(
                        e.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: (e.subtitle != null && e.subtitle!.isNotEmpty)
                          ? Text(
                              e.subtitle ?? '',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF666666),
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _experiences = List.of(_experiences)..removeAt(idx);
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Trainings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    size: 20,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trainings',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _addTraining,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _trainings.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  return Card(
                    color: isDarkMode ? const Color(0xFF000000) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListTile(
                      title: Text(
                        t.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: (t.subtitle != null && t.subtitle!.isNotEmpty)
                          ? Text(
                              t.subtitle ?? '',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF666666),
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _trainings = List.of(_trainings)..removeAt(idx);
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Interests
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 20,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openInterestPicker,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Interests',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _openInterestPicker,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFBFAE01),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFFBFAE01),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interests.map((i) {
                  return InputChip(
                    label: Text(i, style: GoogleFonts.inter()),
                    onDeleted: null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBFAE01),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'Save Changes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInterestPicker() async {
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => InterestSelectionPage(
          initialSelected: _interests,
          returnSelectedOnPop: true,
        ),
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() => _interests = selected);
    }
  }
}
