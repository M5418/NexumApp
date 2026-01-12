import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../core/files_api.dart';
import '../services/media_compression_service.dart';
import '../data/interest_domains.dart';
import '../repositories/interfaces/draft_repository.dart';
import '../repositories/interfaces/podcast_repository.dart';
import '../repositories/interfaces/user_repository.dart';
import '../repositories/models/draft_model.dart';
import '../core/i18n/language_provider.dart';

class CreatePodcastPage extends StatefulWidget {
  final DraftModel? draft;
  
  const CreatePodcastPage({super.key, this.draft});

  @override
  State<CreatePodcastPage> createState() => _CreatePodcastPageState();
}

class _CreatePodcastPageState extends State<CreatePodcastPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _coverUrl;
  String? _coverThumbUrl; // Small thumbnail for fast list loading
  String? _audioUrl;
  List<String> _selectedCategories = [];

  bool _creating = false;
  bool _uploadingCover = false;
  bool _uploadingAudio = false;
  
  final MediaCompressionService _compressionService = MediaCompressionService();
  bool _isEditingDraft = false;
  String? _draftId;
  
  // User's full name - fetched on init
  String _authorName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    if (widget.draft != null) {
      _loadDraft(widget.draft!);
    }
  }
  
  Future<void> _loadUserName() async {
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userRepo = context.read<UserRepository>();
      final profile = await userRepo.getUserProfile(uid);
      if (profile != null && mounted) {
        final firstName = profile.firstName?.trim() ?? '';
        final lastName = profile.lastName?.trim() ?? '';
        setState(() {
          _authorName = '$firstName $lastName'.trim();
          if (_authorName.isEmpty) {
            _authorName = profile.displayName ?? profile.username ?? 'Unknown';
          }
        });
      }
    } catch (_) {}
  }

  void _loadDraft(DraftModel draft) {
    _isEditingDraft = true;
    _draftId = draft.id;
    _titleCtrl.text = draft.title;
    _descCtrl.text = draft.body;
    _coverUrl = draft.coverUrl;
    _audioUrl = draft.audioUrl;
    if (draft.category != null && draft.category!.isNotEmpty) {
      _selectedCategories = [draft.category!];
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _languageCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  String _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i == -1 || i == name.length - 1) return 'bin';
    return name.substring(i + 1).toLowerCase();
  }


  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      setState(() => _uploadingCover = true);
      
      final originalBytes = await file.readAsBytes();
      final filesApi = FilesApi();
      
      // FASTFEED: Compress cover + generate thumbnail in parallel
      final compressFuture = _compressionService.compressImageBytes(
        bytes: originalBytes,
        filename: file.name,
        quality: 85,
        minWidth: 1200,
        minHeight: 1200,
      );
      
      final thumbFuture = _compressionService.generateFeedThumbnailFromBytes(
        bytes: originalBytes,
        filename: file.name,
        maxSize: 300,
        quality: 60,
      );
      
      final results = await Future.wait([compressFuture, thumbFuture]);
      final compressedBytes = results[0] ?? originalBytes;
      final thumbBytes = results[1];
      
      // Upload cover + thumbnail in parallel
      final coverUpload = filesApi.uploadBytes(compressedBytes, ext: _ext(file.name));
      final thumbUpload = thumbBytes != null 
          ? filesApi.uploadBytes(thumbBytes, ext: 'jpg')
          : Future.value(<String, dynamic>{'url': ''});
      
      final uploadResults = await Future.wait([coverUpload, thumbUpload]);
      
      setState(() {
        _coverUrl = uploadResults[0]['url'];
        if ((uploadResults[1]['url'] ?? '').toString().isNotEmpty) {
          _coverThumbUrl = uploadResults[1]['url'];
        }
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.cover_uploaded'), style: GoogleFonts.inter())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.cover_upload_failed')}: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'webm', 'mp4'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final Uint8List? bytes = f.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.could_not_read_file'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() => _uploadingAudio = true);
      final res = await FilesApi().uploadBytes(bytes, ext: _ext(f.name));
      setState(() => _audioUrl = res['url']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.audio_uploaded_msg'), style: GoogleFonts.inter())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.audio_upload_failed')}: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploadingAudio = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.title_required'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final draftRepo = context.read<DraftRepository>();
      
      if (_isEditingDraft && _draftId != null) {
        // Update existing draft
        await draftRepo.updatePodcastDraft(
          draftId: _draftId!,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          coverUrl: _coverUrl,
          audioUrl: _audioUrl,
          category: _selectedCategories.isEmpty ? null : _selectedCategories.first,
        );
      } else {
        // Create new draft
        await draftRepo.savePodcastDraft(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          coverUrl: _coverUrl,
          audioUrl: _audioUrl,
          category: _selectedCategories.isEmpty ? null : _selectedCategories.first,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.saved_drafts'), style: GoogleFonts.inter()), backgroundColor: const Color(0xFF4CAF50)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.save_draft_failed')}: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _publish() async {
    // Validate required fields
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.title_required'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (_authorName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.author_required'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.description_required'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (_languageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.language_required'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.category_required'), style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final podcastRepo = context.read<PodcastRepository>();
      
      final tags = _tagsCtrl.text.trim().isEmpty 
          ? <String>[]
          : _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await podcastRepo.createPodcast(
        title: _titleCtrl.text.trim(),
        author: _authorName,
        description: _descCtrl.text.trim(),
        coverUrl: _coverUrl,
        coverThumbUrl: _coverThumbUrl,
        audioUrl: _audioUrl,
        language: _languageCtrl.text.trim(),
        category: _selectedCategories.join(', '),
        tags: tags.isEmpty ? null : tags,
        isPublished: true,
      );

      // Delete draft if editing an existing one
      if (_isEditingDraft && _draftId != null) {
        try {
          if (!mounted) return;
          final draftRepo = context.read<DraftRepository>();
          await draftRepo.deleteDraft(_draftId!);
        } catch (e) {
          // Non-critical error, continue
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.podcast_published'), style: GoogleFonts.inter()), backgroundColor: const Color(0xFF4CAF50)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.publish_failed')}: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        final tempSelected = List<String>.from(_selectedCategories);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = interestDomains
                .where((d) => d.toLowerCase().contains(query.toLowerCase()))
                .toList();
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12)],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.search_categories'),
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (val) => setModal(() => query = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, tempSelected),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBFAE01),
                            foregroundColor: Colors.black,
                          ),
                          child: Text('${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.done')} (${tempSelected.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  if (tempSelected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '${tempSelected.length} ${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.selected')}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFBFAE01), fontWeight: FontWeight.w600),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final v = filtered[i];
                        final isSelected = tempSelected.contains(v);
                        return CheckboxListTile(
                          title: Text(v, style: GoogleFonts.inter()),
                          value: isSelected,
                          activeColor: const Color(0xFFBFAE01),
                          onChanged: (checked) {
                            setModal(() {
                              if (checked == true) {
                                tempSelected.add(v);
                              } else {
                                tempSelected.remove(v);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategories = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  ),
                  Expanded(
                    child: Text(
                      Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.title'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFAE01).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.podcasts, size: 16, color: Color(0xFFBFAE01)),
                        const SizedBox(width: 4),
                        Text(
                          'PODCAST',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBFAE01),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.cover_image'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _uploadingCover ? null : _pickCoverImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_coverUrl ?? '').isEmpty
                            ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1))
                            : Colors.transparent,
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: (_coverUrl ?? '').isNotEmpty
                                ? Image.network(_coverUrl!, fit: BoxFit.cover)
                                : Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFBFAE01), size: 48),
                                        const SizedBox(height: 8),
                                        Text(
                                          Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.tap_upload_cover'),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: const Color(0xFF999999),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        if (_uploadingCover)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Audio
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.audio_file'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_audioUrl ?? '').isEmpty
                          ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                          : const Color(0xFFBFAE01).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          (_audioUrl ?? '').isEmpty ? Icons.audiotrack : Icons.check_circle,
                          color: const Color(0xFFBFAE01),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (_audioUrl ?? '').isEmpty ? Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.no_audio_selected') : Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.audio_uploaded'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: (_audioUrl ?? '').isEmpty ? const Color(0xFF666666) : const Color(0xFFBFAE01),
                            fontWeight: (_audioUrl ?? '').isEmpty ? FontWeight.w500 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _uploadingAudio ? null : _pickAudioFile,
                        icon: const Icon(Icons.upload_file, color: Colors.black, size: 18),
                        label: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.upload'), style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFAE01),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_uploadingAudio) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      color: Color(0xFFBFAE01),
                      backgroundColor: Color(0xFFEEEEEE),
                      minHeight: 6,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Details Section Header
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.podcast_details'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.inter(),
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    labelStyle: GoogleFonts.inter(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFBFAE01), width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  minLines: 3,
                  style: GoogleFonts.inter(),
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    labelStyle: GoogleFonts.inter(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFBFAE01), width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Language + Category (Both are dropdowns)
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<String>(
                        initialSelection: _languageCtrl.text.isEmpty ? null : _languageCtrl.text,
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(value: 'English', label: 'English'),
                          DropdownMenuEntry(value: 'French', label: 'Français'),
                        ],
                        onSelected: (value) {
                          setState(() {
                            _languageCtrl.text = value ?? '';
                          });
                        },
                        textStyle: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
                        menuStyle: MenuStyle(
                          backgroundColor: WidgetStateProperty.all(isDark ? const Color(0xFF1A1A1A) : Colors.white),
                        ),
                        inputDecorationTheme: InputDecorationTheme(
                          labelStyle: GoogleFonts.inter(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFBFAE01), width: 2),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
                        ),
                        label: Text('Language *', style: GoogleFonts.inter()),
                        expandedInsets: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: _pickCategory,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCategories.isEmpty 
                                          ? Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.select_categories') 
                                          : '${_selectedCategories.length} ${Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.selected')}',
                                      style: GoogleFonts.inter(
                                        color: _selectedCategories.isEmpty 
                                            ? const Color(0xFF999999)
                                            : (isDark ? Colors.white : Colors.black),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFFBFAE01)),
                                ],
                              ),
                            ),
                          ),
                          if (_selectedCategories.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _selectedCategories.map((category) {
                                return Chip(
                                  label: Text(
                                    category,
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.black),
                                  ),
                                  backgroundColor: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                                  deleteIconColor: const Color(0xFFBFAE01),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedCategories.remove(category);
                                    });
                                  },
                                  side: const BorderSide(color: Color(0xFFBFAE01), width: 1),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tags
                TextField(
                  controller: _tagsCtrl,
                  style: GoogleFonts.inter(),
                  decoration: InputDecoration(
                    labelText: 'Tags (comma separated, optional)',
                    labelStyle: GoogleFonts.inter(),
                    hintText: 'technology, education, business',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFBFAE01), width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _creating
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFD4C100), Color(0xFFBFAE01)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    child: ElevatedButton(
                      onPressed: _creating ? null : _publish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _creating ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)) : Colors.transparent,
                        foregroundColor: _creating ? (isDark ? Colors.grey : Colors.black45) : Colors.black,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_creating)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBFAE01)),
                            )
                          else
                            const Icon(Icons.publish, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _creating ? Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.publishing') : Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.publish_podcast'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _creating ? null : _saveDraft,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFBFAE01), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.drafts_outlined, size: 20, color: Color(0xFFBFAE01)),
                        const SizedBox(width: 10),
                        Text(
                          Provider.of<LanguageProvider>(context, listen: false).t('create_podcast.save_draft'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFBFAE01),
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
      ),
    );
  }
}