import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'repositories/firebase/firebase_support_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'core/i18n/language_provider.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  String? _selectedCategory;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;
  bool _loadingUserData = true;
  String _userName = '';
  String _userEmail = '';
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _uploadingImages = false;

  final Map<String, String> _categoryKeys = {
    'general': 'support.category_general',
    'technical': 'support.category_technical',
    'billing': 'support.category_billing',
    'feature_request': 'support.category_feature',
    'bug_report': 'support.category_bug',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loadingUserData = true);
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRepo = context.read<FirebaseUserRepository>();
      final userDoc = await userRepo.getUserProfile(user.uid);
      
      if (userDoc != null && mounted) {
        _userName = '${userDoc.firstName ?? ''} ${userDoc.lastName ?? ''}'.trim();
        _userEmail = user.email ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _loadingUserData = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (images.isNotEmpty && mounted) {
        setState(() {
          _selectedImages.addAll(images);
          if (_selectedImages.length > 5) {
            _selectedImages.removeRange(5, _selectedImages.length);
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];
    
    setState(() => _uploadingImages = true);
    final List<String> urls = [];
    
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final ref = FirebaseStorage.instance
            .ref()
            .child('support_attachments')
            .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(image.path));
        }
        
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
    
    return urls;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  // NEXUM Title
                  Text(
                    lang.t('app.name'),
                    style: GoogleFonts.inika(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Support Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 500),
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
                        // Title
                        Text(
                          lang.t('support.title'),
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtitle
                        Text(
                          lang.t('support.subtitle'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Category Selection
                        _buildSectionTitle(lang.t('support.category'), isDarkMode),
                        const SizedBox(height: 16),
                        _buildCategoryDropdown(lang, isDarkMode),
                        const SizedBox(height: 24),

                        // Subject
                        _buildSectionTitle(lang.t('support.subject'), isDarkMode),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _subjectController,
                          hint: lang.t('support.subject_hint'),
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 24),

                        // Message
                        _buildSectionTitle(lang.t('support.message'), isDarkMode),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _messageController,
                          hint: lang.t('support.message_hint'),
                          isDarkMode: isDarkMode,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 24),

                        // Image Upload Section
                        _buildSectionTitle('Attachments (Optional)', isDarkMode),
                        const SizedBox(height: 16),
                        _buildImageUploadSection(isDarkMode),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_canSubmit() && !_submitting && !_uploadingImages)
                                ? _submit
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_canSubmit() && !_submitting && !_uploadingImages)
                                  ? const Color(0xFFBFAE01)
                                  : const Color(0xFF666666),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: _submitting || _uploadingImages ? 0 : 2,
                              shadowColor: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                            ),
                            child: _submitting || _uploadingImages
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _uploadingImages
                                            ? 'Uploading Images...'
                                            : lang.t('support.submitting'),
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        lang.t('support.submit'),
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Back to Profile
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              lang.t('support.back'),
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

  Widget _buildCategoryDropdown(LanguageProvider lang, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.white : Colors.black,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedCategory,
          hint: Text(
            lang.t('support.select_category'),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF666666),
            ),
          ),
          items: _categoryKeys.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                lang.t(entry.value),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
          dropdownColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDarkMode,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : Colors.black,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : Colors.black,
            width: 1.5,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
          borderSide: BorderSide(color: Color(0xFFBFAE01), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      style: GoogleFonts.inter(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildImageUploadSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Button
        InkWell(
          onTap: _selectedImages.length < 5 ? _pickImages : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedImages.length < 5
                    ? const Color(0xFFBFAE01).withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.3),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              borderRadius: BorderRadius.circular(16),
              color: _selectedImages.length < 5
                  ? const Color(0xFFBFAE01).withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _selectedImages.length < 5
                      ? const Color(0xFFBFAE01)
                      : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedImages.isEmpty
                      ? 'Add Screenshots or Images'
                      : 'Add More Images (${_selectedImages.length}/5)',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _selectedImages.length < 5
                        ? (isDarkMode ? Colors.white : Colors.black)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Selected Images Preview
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              _selectedImages.length,
              (index) => _buildImagePreview(index, isDarkMode),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(int index, bool isDarkMode) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
              width: 2,
            ),
            image: DecorationImage(
              image: kIsWeb
                  ? NetworkImage(_selectedImages[index].path) as ImageProvider
                  : FileImage(File(_selectedImages[index].path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _canSubmit() {
    return _selectedCategory != null &&
        _subjectController.text.trim().isNotEmpty &&
        _messageController.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    final lang = context.read<LanguageProvider>();
    
    if (!_canSubmit()) return;

    // Validate
    if (_selectedCategory == null) {
      _showSnack(lang.t('support.validation_category'));
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      _showSnack(lang.t('support.validation_subject'));
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showSnack(lang.t('support.validation_message'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('Please sign in first');
        return;
      }

      // Upload images first if any are selected
      List<String> attachmentUrls = [];
      if (_selectedImages.isNotEmpty) {
        attachmentUrls = await _uploadImages();
        if (!mounted) return;
      }

      final supportRepo = FirebaseSupportRepository();
      await supportRepo.submitTicket(
        userId: user.uid,
        userName: _userName.isNotEmpty ? _userName : user.email ?? 'User',
        userEmail: _userEmail.isNotEmpty ? _userEmail : user.email ?? '',
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        category: _selectedCategory!,
        attachmentUrls: attachmentUrls,
      );

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFFBFAE01),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lang.t('support.success_title'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            lang.t('support.success_message'),
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFBFAE01),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack(lang.t('support.error'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: GoogleFonts.inter())),
    );
  }
}
