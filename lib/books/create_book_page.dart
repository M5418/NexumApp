import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/files_api.dart';
import 'books_api.dart';

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

  int? _readingMinutes;
  int? _audioDurationSec;
  String _language = 'English';

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
  String? _pdfUrl;
  String? _audioUrl;

  // Audio preview
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingPreview = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isPlayingPreview = false);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    _audioPlayer.dispose();
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

  Future<void> _pickPdf() async {
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

  Future<void> _toggleAudioPreview() async {
    try {
      if (_isPlayingPreview) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingPreview = false);
        return;
      }

      if (kIsWeb && _audioBytes != null) {
        await _audioPlayer.play(BytesSource(_audioBytes!));
      } else if (_audioFile != null) {
        await _audioPlayer.play(DeviceFileSource(_audioFile!.path));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No audio selected', style: GoogleFonts.inter())),
        );
        return;
      }

      if (mounted) setState(() => _isPlayingPreview = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio preview failed: $e', style: GoogleFonts.inter())),
      );
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
            child: kIsWeb
                ? SfPdfViewer.memory(_pdfBytes!)
                : SfPdfViewer.file(_pdfFile!),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title is required', style: GoogleFonts.inter())),
      );
      return;
    }
    final hasPdf = _pdfFile != null || _pdfBytes != null;
    final hasAudio = _audioFile != null || _audioBytes != null;
    if (!hasPdf && !hasAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attach at least a PDF or an audio file', style: GoogleFonts.inter())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final filesApi = FilesApi();

      // Cover upload
      if (_coverFile != null) {
        final up = await filesApi.uploadFile(_coverFile!);
        _coverUrl = up['url'];
      } else if (_coverBytes != null) {
        final up = await filesApi.uploadBytes(_coverBytes!, ext: _coverExt ?? 'jpg');
        _coverUrl = up['url'];
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

      final api = BooksApi.create();
      await api.createBook(
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        coverUrl: (_coverUrl ?? '').isEmpty ? null : _coverUrl,
        pdfUrl: (_pdfUrl ?? '').isEmpty ? null : _pdfUrl,
        audioUrl: (_audioUrl ?? '').isEmpty ? null : _audioUrl,
        language: _language,
        category: null,
        tags: const [],
        price: null,
        isPublished: true,
        readingMinutes: _readingMinutes,
        audioDurationSec: _audioDurationSec,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Book created', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFBFAE01),
        ),
      );
      Navigator.of(context).pop(true);
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
                hintText: 'Description (optional)',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cover + reading time (Wrap to avoid overflow)
          _InputCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SquareButton(icon: Icons.image_outlined, label: 'Cover', onTap: _pickCover),
                if (kIsWeb && _coverBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_coverBytes!, width: 64, height: 64, fit: BoxFit.cover),
                  )
                else if (_coverFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_coverFile!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Color(0xFFBFAE01)),
                      const SizedBox(width: 6),
                      Text(
                        _readingMinutes == null
                            ? 'Reading hrs/min'
                            : '${_readingMinutes! ~/ 60} hr, ${_readingMinutes! % 60} min',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'mins', isDense: true),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      setState(() => _readingMinutes = n);
                    },
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
                if ((kIsWeb && _audioBytes != null) || (!kIsWeb && _audioFile != null))
                  IconButton(
                    tooltip: _isPlayingPreview ? 'Pause' : 'Play preview',
                    onPressed: _toggleAudioPreview,
                    icon: Icon(_isPlayingPreview ? Icons.pause_circle : Icons.play_circle),
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'sec', isDense: true),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      setState(() => _audioDurationSec = n);
                    },
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