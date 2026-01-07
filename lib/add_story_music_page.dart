import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';

import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/firebase/firebase_story_music_repository.dart';

class AddStoryMusicPage extends StatefulWidget {
  const AddStoryMusicPage({super.key});

  @override
  State<AddStoryMusicPage> createState() => _AddStoryMusicPageState();
}

class _AddStoryMusicPageState extends State<AddStoryMusicPage> {
  final FirebaseStoryMusicRepository _musicRepo = FirebaseStoryMusicRepository();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _genreController = TextEditingController();
  
  Uint8List? _audioBytes;
  String? _audioFileName;
  Uint8List? _coverBytes;
  String? _coverFileName;
  
  int _durationSec = 0;
  bool _isUploading = false;
  bool _isPlayingPreview = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingPreview = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _previewPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _previewDuration = duration;
        _durationSec = duration.inSeconds;
      });
    });
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _audioBytes = file.bytes;
            _audioFileName = file.name;
          });
          
          // Try to get duration by playing briefly
          if (kIsWeb) {
            // On web, create a blob URL
            // For simplicity, we'll estimate duration or let user input
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick audio: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _coverBytes = file.bytes;
            _coverFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playPreview() async {
    if (_audioBytes == null) return;
    
    if (_isPlayingPreview) {
      await _audioPlayer.pause();
    } else {
      // On web, we need to use a data URL
      if (kIsWeb) {
        await _audioPlayer.play(BytesSource(_audioBytes!));
      } else {
        await _audioPlayer.play(BytesSource(_audioBytes!));
      }
    }
  }

  Future<void> _stopPreview() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayingPreview = false;
      _previewPosition = Duration.zero;
    });
  }

  Future<void> _uploadMusic() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audioBytes == null || _audioFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('story_music.select_audio'),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isUploading = true);
    await _stopPreview();
    
    try {
      await _musicRepo.uploadMusic(
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        audioBytes: _audioBytes!,
        audioFileName: _audioFileName!,
        coverBytes: _coverBytes,
        coverFileName: _coverFileName,
        durationSec: _durationSec > 0 ? _durationSec : 180, // Default 3 min if unknown
        genre: _genreController.text.trim().isNotEmpty ? _genreController.text.trim() : null,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('story_music.uploaded'),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFFBFAE01),
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _genreController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0C0C0C) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lang.t('story_music.add_music'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Audio file picker
                  _buildSectionTitle(lang.t('story_music.audio_file'), isDark),
                  const SizedBox(height: 8),
                  _buildAudioPicker(isDark, lang),
                  const SizedBox(height: 24),
                  
                  // Cover image picker
                  _buildSectionTitle(lang.t('story_music.cover_image'), isDark),
                  const SizedBox(height: 8),
                  _buildCoverPicker(isDark, lang),
                  const SizedBox(height: 24),
                  
                  // Title
                  _buildSectionTitle(lang.t('story_music.track_title'), isDark),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleController,
                    hint: lang.t('story_music.title_hint'),
                    isDark: isDark,
                    validator: (v) => v == null || v.trim().isEmpty 
                        ? lang.t('story_music.title_required') 
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Artist
                  _buildSectionTitle(lang.t('story_music.artist_name'), isDark),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _artistController,
                    hint: lang.t('story_music.artist_hint'),
                    isDark: isDark,
                    validator: (v) => v == null || v.trim().isEmpty 
                        ? lang.t('story_music.artist_required') 
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Genre (optional)
                  _buildSectionTitle('${lang.t('story_music.genre')} (${lang.t('common.optional')})', isDark),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _genreController,
                    hint: lang.t('story_music.genre_hint'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                  
                  // Upload button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadMusic,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFAE01),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: const Color(0xFFBFAE01).withValues(alpha: 0.5),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(
                              lang.t('story_music.upload'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFAE01), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildAudioPicker(bool isDark, LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _audioBytes != null 
              ? const Color(0xFFBFAE01) 
              : (isDark ? Colors.white12 : Colors.black12),
          width: _audioBytes != null ? 2 : 1,
        ),
      ),
      child: _audioBytes == null
          ? InkWell(
              onTap: _pickAudioFile,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.audio_file,
                      size: 48,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang.t('story_music.tap_to_select'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MP3, WAV, M4A',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Play button
                      GestureDetector(
                        onTap: _playPreview,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFAE01),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isPlayingPreview ? Icons.pause : Icons.play_arrow,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // File info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _audioFileName ?? '',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_audioBytes!.length / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Change button
                      IconButton(
                        onPressed: () async {
                          await _stopPreview();
                          _pickAudioFile();
                        },
                        icon: Icon(
                          Icons.swap_horiz,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  
                  // Progress bar when playing
                  if (_isPlayingPreview || _previewPosition > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_previewPosition),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _previewDuration.inMilliseconds > 0
                                    ? _previewPosition.inMilliseconds / _previewDuration.inMilliseconds
                                    : 0,
                                backgroundColor: isDark ? Colors.white24 : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_previewDuration),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCoverPicker(bool isDark, LanguageProvider lang) {
    return Row(
      children: [
        // Cover preview
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _coverBytes != null 
                    ? const Color(0xFFBFAE01) 
                    : (isDark ? Colors.white12 : Colors.black12),
                width: _coverBytes != null ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _coverBytes != null
                ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        size: 32,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.t('story_music.add_cover'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Info text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('story_music.cover_optional'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.t('story_music.cover_hint'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              if (_coverBytes != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _coverBytes = null;
                    _coverFileName = null;
                  }),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: Text(
                    lang.t('common.remove'),
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
