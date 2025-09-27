import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../core/files_api.dart';
import 'podcasts_api.dart';

class CreatePodcastPage extends StatefulWidget {
  const CreatePodcastPage({super.key});

  @override
  State<CreatePodcastPage> createState() => _CreatePodcastPageState();
}

class _CreatePodcastPageState extends State<CreatePodcastPage> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _coverUrl;
  String? _audioUrl;

  bool _creating = false;
  bool _uploadingCover = false;
  bool _uploadingAudio = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    _languageCtrl.dispose();
    _categoryCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  String _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i == -1 || i == name.length - 1) return 'bin';
    return name.substring(i + 1).toLowerCase();
  }

  List<String> _parseTags() {
    final raw = _tagsCtrl.text.trim();
    if (raw.isEmpty) return [];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(25).toList();
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048);
      if (file == null) return;
      setState(() => _uploadingCover = true);
      final bytes = await file.readAsBytes();
      final res = await FilesApi().uploadBytes(bytes, ext: _ext(file.name));
      setState(() => _coverUrl = res['url']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover uploaded', style: GoogleFonts.inter())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover upload failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
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
          SnackBar(content: Text('Could not read file bytes', style: GoogleFonts.inter()), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() => _uploadingAudio = true);
      final res = await FilesApi().uploadBytes(bytes, ext: _ext(f.name));
      setState(() => _audioUrl = res['url']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio uploaded', style: GoogleFonts.inter())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio upload failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploadingAudio = false);
    }
  }

  Future<void> _submit({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title is required', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final api = PodcastsApi.create();
      final res = await api.createPodcast(
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        coverUrl: _coverUrl,
        audioUrl: _audioUrl,
        language: _languageCtrl.text.trim().isEmpty ? null : _languageCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        tags: _parseTags(),
        isPublished: publish,
      );
      final ok = (res['ok'] ?? false) == true;
      if (!ok) throw 'Server returned error';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publish ? 'Podcast published' : 'Draft saved', style: GoogleFonts.inter())),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create podcast: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text('Create Podcast',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                Text('Cover', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _uploadingCover ? null : _pickCoverImage,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (_coverUrl ?? '').isNotEmpty
                                ? Image.network(_coverUrl!, fit: BoxFit.cover)
                                : Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.image, color: Color(0xFFBFAE01), size: 36),
                                    ),
                                  ),
                          ),
                        ),
                        if (_uploadingCover)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Audio
                Text('Audio file', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_audioUrl ?? '').isEmpty ? 'No file selected' : 'Audio uploaded',
                        style: GoogleFonts.inter(color: const Color(0xFF666666)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _uploadingAudio ? null : _pickAudioFile,
                      icon: const Icon(Icons.upload_file, color: Colors.black, size: 18),
                      label: Text('Upload', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFAE01),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                if (_uploadingAudio) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(color: Color(0xFFBFAE01), minHeight: 4),
                ],
                const SizedBox(height: 16),

                // Title
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Author
                TextField(
                  controller: _authorCtrl,
                  decoration: const InputDecoration(labelText: 'Author (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: _descCtrl,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Language + Category
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _languageCtrl,
                        decoration: const InputDecoration(labelText: 'Language (optional)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _categoryCtrl,
                        decoration: const InputDecoration(labelText: 'Category (optional)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tags
                TextField(
                  controller: _tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated, optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _creating ? null : () => _submit(publish: false),
                        child: Text('Save as Draft', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _creating ? null : () => _submit(publish: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFAE01),
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                        child: Text('Publish', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}