import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart';
import '../core/files_api.dart';
import '../repositories/interfaces/book_repository.dart';
import '../services/media_compression_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../core/admin_config.dart';
import '../data/interest_domains.dart';

class CreateBookPage extends StatefulWidget {
  const CreateBookPage({super.key});

  static Future<T?> showPopup<T>(BuildContext context) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create Book',
      barrierColor: Colors.black.withValues (alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 950),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: const CreateBookPage(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
  
  @override
  State<CreateBookPage> createState() => _CreateBookPageState();
}

class _CreateBookPageState extends State<CreateBookPage> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _language = 'English';
  List<String> _selectedCategories = [];

  // Native (mobile/desktop)
  File? _coverFile;
  File? _pdfFile;
  File? _audioFile;

  // Web (bytes)
  Uint8List? _coverBytes;
  Uint8List? _pdfBytes;
  Uint8List? _audioBytes;

  // Friendly names + extensions (used across platforms)
  String? _pdfName;
  String? _audioName;
  String? _coverExt;
  String? _pdfExt;
  String? _audioExt;

  // Uploaded URLs
  String? _coverUrl;
  String? _coverThumbUrl; // Small thumbnail for fast list loading
  String? _pdfUrl;
  String? _audioUrl;

  bool _saving = false;
  
  final MediaCompressionService _compressionService = MediaCompressionService();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    setState(() {
      _coverExt = (f.extension ?? 'jpg').toLowerCase();
      if (kIsWeb) {
        _coverBytes = f.bytes;
        _coverFile = null;
      } else if (f.path != null) {
        _coverFile = File(f.path!);
        _coverBytes = null;
      }
    });
  }

  Future<void> _pickPdf() async{
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    setState(() {
      _pdfName = f.name;
      _pdfExt = (f.extension ?? 'pdf').toLowerCase();
      if (kIsWeb) {
        _pdfBytes = f.bytes;
        _pdfFile = null;
      } else if (f.path != null) {
        _pdfFile = File(f.path!);
        _pdfBytes = null;
      }
    });
  }

  Future<void> _pickAudio() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac', 'webm'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    setState(() {
      _audioName = f.name;
      _audioExt = (f.extension ?? 'mp3').toLowerCase();
      if (kIsWeb) {
        _audioBytes = f.bytes;
        _audioFile = null;
      } else if (f.path != null) {
        _audioFile = File(f.path!);
        _audioBytes = null;
      }
    });
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
                            decoration: const InputDecoration(
                              hintText: 'Search categories',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
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
                          child: Text('Done (${tempSelected.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  if (tempSelected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '${tempSelected.length} selected',
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

  Future<void> _showPdfPreviewDialog() async {
    if (!kIsWeb && _pdfFile == null && _pdfBytes == null) return;
    if (kIsWeb && _pdfBytes == null) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 720,
            height: 920,
            child: FutureBuilder<PdfDocument>(
              future: kIsWeb
                  ? PdfDocument.openData(_pdfBytes!)
                  : PdfDocument.openFile(_pdfFile!.path),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading PDF',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                  );
                }
                return PdfView(
                  controller: PdfController(document: Future.value(snapshot.data!)),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    // Validate all required fields
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title is required', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_authorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Author is required', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Description is required', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('At least one category is required', style: GoogleFonts.inter())),
      );
      return;
    }
    if (_coverFile == null && _coverBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover image is required', style: GoogleFonts.inter())),
      );
      return;
    }
    final hasPdf = _pdfFile != null || _pdfBytes != null;
    final hasAudio = _audioFile != null || _audioBytes != null;
    if (!hasPdf && !hasAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attach at least a PDF or audio file', style: GoogleFonts.inter())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final navContext = context;
      final filesApi = FilesApi();

      // FASTFEED: Cover upload with compression + thumbnail generation in parallel
      if (_coverFile != null || _coverBytes != null) {
        final originalBytes = _coverFile != null 
            ? await _coverFile!.readAsBytes()
            : _coverBytes!;
        
        // Compress cover + generate thumbnail in parallel
        final compressFuture = _compressionService.compressImageBytes(
          bytes: originalBytes,
          filename: 'cover.${_coverExt ?? 'jpg'}',
          quality: 85,
          minWidth: 1200,
          minHeight: 1600,
        );
        
        final thumbFuture = _compressionService.generateFeedThumbnailFromBytes(
          bytes: originalBytes,
          filename: 'cover.${_coverExt ?? 'jpg'}',
          maxSize: 300,
          quality: 60,
        );
        
        final results = await Future.wait([compressFuture, thumbFuture]);
        final compressedBytes = results[0] ?? originalBytes;
        final thumbBytes = results[1];
        
        // Upload cover + thumbnail in parallel
        final coverUpload = filesApi.uploadBytes(compressedBytes, ext: _coverExt ?? 'jpg');
        final thumbUpload = thumbBytes != null 
            ? filesApi.uploadBytes(thumbBytes, ext: 'jpg')
            : Future.value(<String, dynamic>{'url': ''});
        
        final uploadResults = await Future.wait([coverUpload, thumbUpload]);
        _coverUrl = uploadResults[0]['url'];
        if ((uploadResults[1]['url'] ?? '').toString().isNotEmpty) {
          _coverThumbUrl = uploadResults[1]['url'];
        }
      }

      // PDF upload
      if (_pdfFile != null) {
        final up = await filesApi.uploadFile(_pdfFile!);
        _pdfUrl = up['url'];
      } else if (_pdfBytes != null) {
        final up = await filesApi.uploadBytes(_pdfBytes!, ext: _pdfExt ?? 'pdf');
        _pdfUrl = up['url'];
      }

      // Audio upload
      if (_audioFile != null) {
        final up = await filesApi.uploadFile(_audioFile!);
        _audioUrl = up['url'];
      } else if (_audioBytes != null) {
        final up = await filesApi.uploadBytes(_audioBytes!, ext: _audioExt ?? 'mp3');
        _audioUrl = up['url'];
      }

      if (!navContext.mounted) return;
      final bookRepo = navContext.read<BookRepository>();
      await bookRepo.createBook(
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        coverUrl: _coverUrl!,
        coverThumbUrl: _coverThumbUrl,
        pdfUrl: (_pdfUrl ?? '').isEmpty ? null : _pdfUrl,
        audioUrl: (_audioUrl ?? '').isEmpty ? null : _audioUrl,
        language: _language,
        category: _selectedCategories.join(', '),
        tags: const [],
        price: null,
        isPublished: true,
      );
      if (!navContext.mounted) return;
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          content: Text('Book created', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFBFAE01),
        ),
      );
      Navigator.of(navContext).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create book: $e', style: GoogleFonts.inter())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    
    // Only admins can create books
    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (!AdminConfig.isAdmin(currentUserId)) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outlined,
                  size: 64,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(height: 24),
                Text(
                  'Admin Only',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only administrators can create books.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                  ),
                  Text(
                    'Add a Book',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InputCard(
            child: TextField(
              controller: _titleCtrl,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InputCard(
            child: TextField(
              controller: _authorCtrl,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                hintText: 'Author',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InputCard(
            height: 160,
            child: TextField(
              controller: _descCtrl,
              maxLines: null,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                hintText: 'Description',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cover + reading time (Wrap to avoid overflow)
          _InputCard(
            child: Row(
              children: [
                _SquareButton(icon: Icons.image_outlined, label: 'Cover', onTap: _pickCover),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      if (kIsWeb && _coverBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_coverBytes!, width: 64, height: 64, fit: BoxFit.cover),
                          ),
                        )
                      else if (_coverFile != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_coverFile!, width: 64, height: 64, fit: BoxFit.cover),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          (_coverFile != null || _coverBytes != null) ? 'Cover selected' : 'No cover selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Upload Book PDF section with preview button (web-friendly)
          _InputCard(
            child: Row(
              children: [
                _SquareButton(icon: Icons.picture_as_pdf, label: 'PDF', onTap: _pickPdf),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kIsWeb
                        ? (_pdfName ?? 'No PDF selected')
                        : (_pdfFile != null
                            ? _pdfFile!.path.split(Platform.pathSeparator).last
                            : 'No PDF selected'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(),
                  ),
                ),
                const SizedBox(width: 8),
                if ((kIsWeb && _pdfBytes != null) || (!kIsWeb && _pdfFile != null))
                  IconButton(
                    tooltip: 'Preview',
                    onPressed: _showPdfPreviewDialog,
                    icon: const Icon(Icons.visibility),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Upload Audio section with play/pause preview
          _InputCard(
            child: Row(
              children: [
                _SquareButton(icon: Icons.audiotrack, label: 'Audio', onTap: _pickAudio),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kIsWeb
                        ? (_audioName ?? 'No audio selected')
                        : (_audioFile != null
                            ? _audioFile!.path.split(Platform.pathSeparator).last
                            : 'No audio selected'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _InputCard(
            child: Row(
              children: [
                Text('Language:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _language,
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'French', child: Text('French')),
                      DropdownMenuItem(value: 'Arabic', child: Text('Arabic')),
                      DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                    ],
                    onChanged: (v) => setState(() => _language = v ?? 'English'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickCategory,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.category_outlined, color: Color(0xFFBFAE01), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedCategories.isEmpty
                                ? 'Select categories (tap to choose)'
                                : '${_selectedCategories.length} categor${_selectedCategories.length == 1 ? 'y' : 'ies'} selected',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _selectedCategories.isEmpty
                                  ? const Color(0xFF999999)
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF666666)),
                      ],
                    ),
                  ),
                ),
                if (_selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;
  final double? height;
  const _InputCard({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SquareButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}