import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'core/files_api.dart';
import 'core/stories_api.dart';

// Extracted reusable widgets
import 'widgets/story_editor_toolbar.dart';
import 'widgets/story_media_viewer.dart';
import 'widgets/music_chip.dart';
import 'widgets/media_nav_bar.dart';

enum StoryComposeType { image, video, text, mixed }

// ======================= Type Picker (bottom sheet) =======================
class StoryTypePicker {
  static void show(
    BuildContext context, {
    required void Function(StoryComposeType type) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withValues(alpha: 77),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                _TypeTile(
                  icon: Icons.perm_media,
                  label: 'Media story',
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(StoryComposeType.mixed);
                  },
                ),
                _TypeTile(
                  icon: Icons.text_fields,
                  label: 'Text story',
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(StoryComposeType.text);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFBFAE01).withValues(alpha: 38),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
    );
  }
}

// ---------------------- Music Picker ----------------------
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final Duration duration;
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
  });
}

const List<MusicTrack> _sampleTracks = [
  MusicTrack(
    id: '1',
    title: 'Sunrise Drive',
    artist: 'Nexum Beats',
    duration: Duration(minutes: 2, seconds: 14),
  ),
  MusicTrack(
    id: '2',
    title: 'Golden Hour',
    artist: 'Nova',
    duration: Duration(minutes: 3, seconds: 2),
  ),
  MusicTrack(
    id: '3',
    title: 'Focus Flow',
    artist: 'Deepwork',
    duration: Duration(minutes: 2, seconds: 47),
  ),
  MusicTrack(
    id: '4',
    title: 'Night Vibes',
    artist: 'Pulse',
    duration: Duration(minutes: 2, seconds: 38),
  ),
  MusicTrack(
    id: '5',
    title: 'City Lights',
    artist: 'Skyline',
    duration: Duration(minutes: 1, seconds: 55),
  ),
  MusicTrack(
    id: '6',
    title: 'Cloud Surf',
    artist: 'Aero',
    duration: Duration(minutes: 2, seconds: 20),
  ),
];

class _MusicPickerSheet extends StatelessWidget {
  final List<MusicTrack> tracks;
  const _MusicPickerSheet({required this.tracks});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF666666).withValues(alpha: 77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select music',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tracks.length,
                separatorBuilder: (context, _) => Divider(
                  color: const Color(0xFF666666).withValues(alpha: 51),
                  height: 1,
                ),
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  String twoDigits(int n) => n.toString().padLeft(2, '0');
                  final mm = twoDigits(t.duration.inMinutes.remainder(60));
                  final ss = twoDigits(t.duration.inSeconds.remainder(60));
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01).withValues(alpha: 38),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                    title: Text(
                      t.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      '${t.artist}  •  $mm:$ss',
                      style: GoogleFonts.inter(color: const Color(0xFF666666)),
                    ),
                    onTap: () => Navigator.pop(context, t),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ========================= Mixed Media Story Composer =========================
class MixedMediaStoryComposerPage extends StatefulWidget {
  const MixedMediaStoryComposerPage({super.key});

  @override
  State<MixedMediaStoryComposerPage> createState() =>
      _MixedMediaStoryComposerPageState();
}

class MediaItem {
  final XFile file;
  final bool isVideo;
  VideoPlayerController? videoController;
  Uint8List? editedImageBytes;

  MediaItem({
    required this.file,
    required this.isVideo,
    this.videoController,
    this.editedImageBytes,
  });
}

class _MixedMediaStoryComposerPageState
    extends State<MixedMediaStoryComposerPage> {
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();
  List<MediaItem> _mediaItems = [];
  int _currentIndex = 0;
  MusicTrack? _selectedTrack;

  @override
  void dispose() {
    _pageController.dispose();
    for (final item in _mediaItems) {
      item.videoController?.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final mediaFiles = await _picker.pickMultipleMedia(limit: 10);
      if (mediaFiles.isEmpty) return;

      final newItems = <MediaItem>[];

      for (final media in mediaFiles) {
        final isVideo = media.mimeType?.startsWith('video/') ?? false;

        if (isVideo) {
          final controller = VideoPlayerController.file(File(media.path));
          try {
            await controller.initialize();
            await controller.setLooping(true);
            newItems.add(
              MediaItem(
                file: media,
                isVideo: true,
                videoController: controller,
              ),
            );
          } catch (e) {
            controller.dispose();
          }
        } else {
          newItems.add(MediaItem(file: media, isVideo: false));
        }
      }

      if (newItems.isEmpty) return;

      setState(() {
        _mediaItems = newItems;
        _currentIndex = 0;
      });

      if (newItems.isNotEmpty && newItems[0].isVideo) {
        newItems[0].videoController?.play();
      }
    } catch (e) {
      // Fallback to single media
      final media = await _picker.pickMedia();
      if (media == null) return;

      final newItems = <MediaItem>[];
      final isVideo = media.mimeType?.startsWith('video/') ?? false;

      if (isVideo) {
        final controller = VideoPlayerController.file(File(media.path));
        try {
          await controller.initialize();
          await controller.setLooping(true);
          newItems.add(
            MediaItem(file: media, isVideo: true, videoController: controller),
          );
        } catch (e) {
          controller.dispose();
          return;
        }
      } else {
        newItems.add(MediaItem(file: media, isVideo: false));
      }

      setState(() {
        _mediaItems = newItems;
        _currentIndex = 0;
      });

      if (newItems.isNotEmpty && newItems[0].isVideo) {
        newItems[0].videoController?.play();
      }
    }
  }

  Future<void> _editCurrentImage() async {
    if (_mediaItems.isEmpty || _mediaItems[_currentIndex].isVideo) return;

    final currentItem = _mediaItems[_currentIndex];
    final imageBytes = await File(currentItem.file.path).readAsBytes();

    if (!mounted) return;

    final result = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.memory(
          imageBytes,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) {
              Navigator.pop(context, bytes);
              return Future.value();
            },
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _mediaItems[_currentIndex].editedImageBytes = result;
      });
    }
  }

  void _removeCurrentMedia() {
    if (_mediaItems.length <= 1) {
      setState(() {
        for (final item in _mediaItems) {
          item.videoController?.dispose();
        }
        _mediaItems.clear();
        _currentIndex = 0;
      });
      return;
    }

    final removedItem = _mediaItems[_currentIndex];
    removedItem.videoController?.dispose();

    setState(() {
      _mediaItems.removeAt(_currentIndex);

      if (_currentIndex >= _mediaItems.length) {
        _currentIndex = _mediaItems.length - 1;
      }

      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    for (final item in _mediaItems) {
      if (item.isVideo) {
        item.videoController?.pause();
      }
    }

    setState(() {
      _currentIndex = index;
    });

    if (_mediaItems[index].isVideo) {
      _mediaItems[index].videoController?.play();
    }
  }

  Future<File> _writeBytesToTemp(Uint8List bytes, {String ext = 'jpg'}) async {
    final dir = await Directory.systemTemp.createTemp('nexum_story_');
    final file =
        File('${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _post() async {
    if (_mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No media selected', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading...', style: GoogleFonts.inter())),
      );

      final filesApi = FilesApi();
      final storiesApi = StoriesApi();
      final List<Map<String, dynamic>> items = [];

      for (final item in _mediaItems) {
        if (item.isVideo) {
          // Upload video
          final f = File(item.file.path);
          final up = await filesApi.uploadFile(f);
          items.add({
            'media_type': 'video',
            'media_url': up['url'],
            'privacy': 'public',
          });
        } else {
          // Upload image (prefer edited bytes)
          File f;
          if (item.editedImageBytes != null) {
            f = await _writeBytesToTemp(item.editedImageBytes!, ext: 'jpg');
          } else {
            f = File(item.file.path);
          }
          final up = await filesApi.uploadFile(f);

          String? audioUrl;
          String? audioTitle;
          if (_selectedTrack != null) {
            // Replace with real music URL when catalog is available
            audioUrl =
                'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
            audioTitle = _selectedTrack!.title;
          }

          items.add({
            'media_type': 'image',
            'media_url': up['url'],
            if (audioUrl != null) 'audio_url': audioUrl,
            if (audioTitle != null) 'audio_title': audioTitle,
            'privacy': 'public',
          });
        }
      }

      await storiesApi.createStoriesBatch(items);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story posted!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post story', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickMusic() async {
    final selected = await showModalBottomSheet<MusicTrack>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MusicPickerSheet(tracks: _sampleTracks),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() => _selectedTrack = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _mediaItems.length > 1 ? '${_mediaItems.length} Stories' : 'Story',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _post,
            child: Text(
              'Post',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _mediaItems.isEmpty
                    ? _PickMixedMediaPlaceholder(onPick: _pickMedia)
                    : Column(
                        children: [
                          if (_mediaItems.length > 1)
                            MediaNavBar(
                              currentIndex: _currentIndex,
                              total: _mediaItems.length,
                              onPrev: _currentIndex > 0
                                  ? () {
                                      setState(() => _currentIndex--);
                                      _pageController.previousPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  : null,
                              onNext: _currentIndex < _mediaItems.length - 1
                                  ? () {
                                      setState(() => _currentIndex++);
                                      _pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  : null,
                            ),

                          // Media PageView
                          Expanded(
                            child: Stack(
                              children: [
                                PageView.builder(
                                  controller: _pageController,
                                  itemCount: _mediaItems.length,
                                  onPageChanged: _onPageChanged,
                                  itemBuilder: (context, index) {
                                    final item = _mediaItems[index];
                                    return StoryMediaViewer(
                                      isVideo: item.isVideo,
                                      videoController: item.videoController,
                                      imageFile: item.isVideo
                                          ? null
                                          : File(item.file.path),
                                      editedImageBytes: item.editedImageBytes,
                                      fileName: item.isVideo
                                          ? item.file.path.split('/').last
                                          : null,
                                    );
                                  },
                                ),

                                // Music selection preview chip
                                if (_selectedTrack != null)
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    top: 12,
                                    child: MusicChip(
                                      title: _selectedTrack!.title,
                                      artist: _selectedTrack!.artist,
                                      onClear: () =>
                                          setState(() => _selectedTrack = null),
                                    ),
                                  ),

                                // Media type indicator
                                Positioned(
                                  right: 16,
                                  top: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 153),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _mediaItems[_currentIndex].isVideo
                                              ? Icons.videocam
                                              : Icons.image,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _mediaItems[_currentIndex].isVideo
                                              ? 'Video'
                                              : 'Image',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Page indicators
                          if (_mediaItems.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _mediaItems.length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == _currentIndex
                                          ? const Color(0xFFBFAE01)
                                          : Colors.white.withValues(alpha: 77),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            // Bottom editor toolbar
            if (_mediaItems.isNotEmpty)
              StoryEditorToolbar(
                isImage: !_mediaItems[_currentIndex].isVideo,
                canRemove: _mediaItems.length > 1,
                onEdit: !_mediaItems[_currentIndex].isVideo
                    ? _editCurrentImage
                    : null,
                onPickMusic: _pickMusic,
                onPickMedia: _pickMedia,
                onRemove: _mediaItems.length > 1 ? _removeCurrentMedia : null,
                onReset: () => setState(() {
                  for (final item in _mediaItems) {
                    item.editedImageBytes = null;
                  }
                  _selectedTrack = null;
                }),
              ),
          ],
        ),
      ),
    );
  }
}

// ========================= Text Story Composer =========================
class TextStoryComposerPage extends StatefulWidget {
  const TextStoryComposerPage({super.key});

  @override
  State<TextStoryComposerPage> createState() => _TextStoryComposerPageState();
}

class _TextStoryComposerPageState extends State<TextStoryComposerPage> {
  final _controller = TextEditingController();
  Color _bgColor = const Color(0xFFE74C3C);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postText() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Write something', style: GoogleFonts.inter())),
      );
      return;
    }
    try {
      final hex =
          '#${_bgColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
      await StoriesApi().createStory(
        mediaType: 'text',
        textContent: _controller.text.trim(),
        backgroundColor: hex,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story posted!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post story', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Story', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: _postText,
            child: Text('Post',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: _bgColor,
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: TextField(
                controller: _controller,
                maxLines: null,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 22, color: Colors.white, height: 1.3),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your story...',
                ),
              ),
            ),
          ),
          Container(
            height: 60,
            color: isDark ? Colors.black : Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final c in [
                  0xFFE74C3C,
                  0xFF2ECC71,
                  0xFF3498DB,
                  0xFFF1C40F,
                  0xFF9B59B6,
                  0xFF34495E,
                  0xFF1ABC9C
                ])
                  GestureDetector(
                    onTap: () => setState(() => _bgColor = Color(c)),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12)),
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

// ========================= Placeholder (pick media) =========================
class _PickMixedMediaPlaceholder extends StatelessWidget {
  final VoidCallback onPick;
  const _PickMixedMediaPlaceholder({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.perm_media, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        Text(
          'Select images and videos',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 179),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onPick,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBFAE01),
          ),
          child: Text(
            'Pick Media',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
