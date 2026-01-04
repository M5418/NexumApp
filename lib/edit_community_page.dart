import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'repositories/interfaces/community_repository.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'services/media_compression_service.dart';

class EditCommunityPage extends StatefulWidget {
  final CommunityModel community;

  const EditCommunityPage({
    super.key,
    required this.community,
  });

  @override
  State<EditCommunityPage> createState() => _EditCommunityPageState();
}

class _EditCommunityPageState extends State<EditCommunityPage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  
  // Multilingual name controllers
  late TextEditingController _nameFrController;
  late TextEditingController _namePtController;
  late TextEditingController _nameEsController;
  late TextEditingController _nameDeController;
  
  // Multilingual bio controllers
  late TextEditingController _bioFrController;
  late TextEditingController _bioPtController;
  late TextEditingController _bioEsController;
  late TextEditingController _bioDeController;
  
  String? _avatarUrl;
  String? _coverUrl;
  
  XFile? _newAvatar;
  XFile? _newCover;
  
  bool _saving = false;
  bool _showTranslations = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.community.name);
    _bioController = TextEditingController(text: widget.community.bio);
    _avatarUrl = widget.community.avatarUrl;
    _coverUrl = widget.community.coverUrl;
    
    // Initialize multilingual controllers from existing translations
    final nameT = widget.community.nameTranslations ?? {};
    final bioT = widget.community.bioTranslations ?? {};
    
    _nameFrController = TextEditingController(text: nameT['fr'] ?? '');
    _namePtController = TextEditingController(text: nameT['pt'] ?? '');
    _nameEsController = TextEditingController(text: nameT['es'] ?? '');
    _nameDeController = TextEditingController(text: nameT['de'] ?? '');
    
    _bioFrController = TextEditingController(text: bioT['fr'] ?? '');
    _bioPtController = TextEditingController(text: bioT['pt'] ?? '');
    _bioEsController = TextEditingController(text: bioT['es'] ?? '');
    _bioDeController = TextEditingController(text: bioT['de'] ?? '');
    
    // Show translations section if any translations exist
    _showTranslations = nameT.isNotEmpty || bioT.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _nameFrController.dispose();
    _namePtController.dispose();
    _nameEsController.dispose();
    _nameDeController.dispose();
    _bioFrController.dispose();
    _bioPtController.dispose();
    _bioEsController.dispose();
    _bioDeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _newAvatar = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _pickCover() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _newCover = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking cover: $e');
    }
  }

  Future<String?> _uploadImage(XFile file, String path, {bool isCover = false}) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final compressionService = MediaCompressionService();
      Uint8List bytesToUpload;
      
      if (kIsWeb) {
        // Web upload with compression
        final originalBytes = await file.readAsBytes();
        final compressed = await compressionService.compressImageBytes(
          bytes: originalBytes,
          filename: file.name,
          quality: 85,
          minWidth: isCover ? 1920 : 500,
          minHeight: isCover ? 1080 : 500,
        );
        bytesToUpload = compressed ?? originalBytes;
      } else {
        // Mobile upload with compression
        final compressed = await compressionService.compressImage(
          filePath: file.path,
          quality: 85,
          minWidth: isCover ? 1920 : 500,
          minHeight: isCover ? 1080 : 500,
        );
        bytesToUpload = compressed ?? await File(file.path).readAsBytes();
      }
      
      await ref.putData(bytesToUpload);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('edit_community.name_empty'), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Get repository before any async operations
    final repo = context.read<CommunityRepository>();

    try {
      String? newAvatarUrl;
      String? newCoverUrl;

      // Upload new avatar if selected
      if (_newAvatar != null) {
        final url = await _uploadImage(
          _newAvatar!,
          'communities/${widget.community.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (url != null) newAvatarUrl = url;
      }

      // Upload new cover if selected
      if (_newCover != null) {
        final url = await _uploadImage(
          _newCover!,
          'communities/${widget.community.id}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
          isCover: true,
        );
        if (url != null) newCoverUrl = url;
      }

      // Build translations maps (only include non-empty values)
      final nameTranslations = <String, String>{};
      if (_nameFrController.text.trim().isNotEmpty) nameTranslations['fr'] = _nameFrController.text.trim();
      if (_namePtController.text.trim().isNotEmpty) nameTranslations['pt'] = _namePtController.text.trim();
      if (_nameEsController.text.trim().isNotEmpty) nameTranslations['es'] = _nameEsController.text.trim();
      if (_nameDeController.text.trim().isNotEmpty) nameTranslations['de'] = _nameDeController.text.trim();
      
      final bioTranslations = <String, String>{};
      if (_bioFrController.text.trim().isNotEmpty) bioTranslations['fr'] = _bioFrController.text.trim();
      if (_bioPtController.text.trim().isNotEmpty) bioTranslations['pt'] = _bioPtController.text.trim();
      if (_bioEsController.text.trim().isNotEmpty) bioTranslations['es'] = _bioEsController.text.trim();
      if (_bioDeController.text.trim().isNotEmpty) bioTranslations['de'] = _bioDeController.text.trim();

      // Update community
      await repo.updateCommunity(
        communityId: widget.community.id,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: newAvatarUrl ?? _avatarUrl,
        coverUrl: newCoverUrl ?? _coverUrl,
        nameTranslations: nameTranslations.isNotEmpty ? nameTranslations : null,
        bioTranslations: bioTranslations.isNotEmpty ? bioTranslations : null,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('edit_community.updated'), style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('edit_community.update_failed')}: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
        final cardColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            foregroundColor: textColor,
            elevation: 0,
            centerTitle: true,
            title: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('edit_community.title'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            actions: [
              if (_saving)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                      ),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _save,
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBFAE01),
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                Text(
                  'Cover Image',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickCover,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: _newCover != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? Image.network(
                                    _newCover!.path,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_newCover!.path),
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : _coverUrl != null && _coverUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: _coverUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to add cover image',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 24),

                // Avatar
                Text(
                  'Community Avatar',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                        border: Border.all(
                          color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _newAvatar != null
                            ? kIsWeb
                                ? Image.network(
                                    _newAvatar!.path,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_newAvatar!.path),
                                    fit: BoxFit.cover,
                                  )
                            : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _avatarUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                Text(
                  'Community Name',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: Provider.of<LanguageProvider>(context, listen: false).t('edit_community.name_hint'),
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Bio
                Text(
                  'Bio',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: textColor,
                  ),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: Provider.of<LanguageProvider>(context, listen: false).t('edit_community.description_hint'),
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Translations Section Toggle
                GestureDetector(
                  onTap: () => setState(() => _showTranslations = !_showTranslations),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBFAE01).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.translate,
                          color: const Color(0xFFBFAE01),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            Provider.of<LanguageProvider>(context, listen: false).t('edit_community.translations'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        Icon(
                          _showTranslations ? Icons.expand_less : Icons.expand_more,
                          color: textColor,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Translations Fields (expandable)
                if (_showTranslations) ...[
                  const SizedBox(height: 16),
                  _buildTranslationSection(
                    'Français (French)',
                    _nameFrController,
                    _bioFrController,
                    isDark,
                    textColor,
                  ),
                  const SizedBox(height: 16),
                  _buildTranslationSection(
                    'Português (Portuguese)',
                    _namePtController,
                    _bioPtController,
                    isDark,
                    textColor,
                  ),
                  const SizedBox(height: 16),
                  _buildTranslationSection(
                    'Español (Spanish)',
                    _nameEsController,
                    _bioEsController,
                    isDark,
                    textColor,
                  ),
                  const SizedBox(height: 16),
                  _buildTranslationSection(
                    'Deutsch (German)',
                    _nameDeController,
                    _bioDeController,
                    isDark,
                    textColor,
                  ),
                ],
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTranslationSection(
    String languageLabel,
    TextEditingController nameController,
    TextEditingController bioController,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageLabel,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFBFAE01),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textColor,
            ),
            decoration: InputDecoration(
              labelText: Provider.of<LanguageProvider>(context, listen: false).t('edit_community.name_label'),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              hintText: Provider.of<LanguageProvider>(context, listen: false).t('edit_community.name_hint'),
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioController,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textColor,
            ),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: Provider.of<LanguageProvider>(context, listen: false).t('edit_community.bio_label'),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              hintText: Provider.of<LanguageProvider>(context, listen: false).t('edit_community.description_hint'),
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFEFEFEF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
