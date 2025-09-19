import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

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

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double kSize = 56;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: kSize,
            height: kSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFBFAE01), size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
          ),
        ],
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
      // Pick multiple media (images and videos together in one interface)
      final mediaFiles = await _picker.pickMultipleMedia(limit: 10);

      if (mediaFiles.isEmpty) return;

      final newItems = <MediaItem>[];

      // Process each selected media file
      for (final media in mediaFiles) {
        final isVideo = media.mimeType?.startsWith('video/') ?? false;

        if (isVideo) {
          // Initialize video controller for videos
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
          // Add image
          newItems.add(MediaItem(file: media, isVideo: false));
        }
      }

      if (newItems.isEmpty) return;

      setState(() {
        _mediaItems = newItems;
        _currentIndex = 0;
      });

      // Auto-play first video if it exists
      if (newItems.isNotEmpty && newItems[0].isVideo) {
        newItems[0].videoController?.play();
      }
    } catch (e) {
      // Fallback to single media picker if pickMultipleMedia fails
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
    // Pause all videos
    for (final item in _mediaItems) {
      if (item.isVideo) {
        item.videoController?.pause();
      }
    }

    setState(() {
      _currentIndex = index;
    });

    // Play current video if it's a video
    if (_mediaItems[index].isVideo) {
      _mediaItems[index].videoController?.play();
    }
  }

  Future<void> _post() async {
    final imageCount = _mediaItems.where((item) => !item.isVideo).length;
    final videoCount = _mediaItems.where((item) => item.isVideo).length;

    String message = '';
    if (imageCount > 0 && videoCount > 0) {
      message =
          '$imageCount image(s) and $videoCount video(s) posted as stories (UI only)';
    } else if (imageCount > 0) {
      message = '$imageCount image stories posted (UI only)';
    } else {
      message = '$videoCount video stories posted (UI only)';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFBFAE01),
      ),
    );
    Navigator.pop(context);
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
                          // Media counter and navigation
                          if (_mediaItems.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_currentIndex + 1} of ${_mediaItems.length}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _currentIndex > 0
                                            ? () {
                                                setState(() => _currentIndex--);
                                                _pageController.previousPage(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                );
                                              }
                                            : null,
                                        icon: Icon(
                                          Icons.arrow_back_ios,
                                          color: _currentIndex > 0
                                              ? Colors.white
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed:
                                            _currentIndex <
                                                _mediaItems.length - 1
                                            ? () {
                                                setState(() => _currentIndex++);
                                                _pageController.nextPage(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                );
                                              }
                                            : null,
                                        icon: Icon(
                                          Icons.arrow_forward_ios,
                                          color:
                                              _currentIndex <
                                                  _mediaItems.length - 1
                                              ? Colors.white
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                                    return Container(
                                      margin: const EdgeInsets.all(16),
                                      child: item.isVideo
                                          ? _buildVideoPlayer(item)
                                          : _buildImageViewer(item),
                                    );
                                  },
                                ),

                                // Music selection preview chip
                                if (_selectedTrack != null)
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 153,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${_selectedTrack!.title} — ${_selectedTrack!.artist}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _selectedTrack = null,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
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
                                      color: Colors.black.withValues(
                                        alpha: 153,
                                      ),
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
                                      horizontal: 4,
                                    ),
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

            // Toolbar - Only show editing tools if media is uploaded
            if (_mediaItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 77),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Edit button - only show for images
                    if (!_mediaItems[_currentIndex].isVideo)
                      _ToolIcon(
                        icon: Icons.edit,
                        label: 'Edit',
                        onTap: _editCurrentImage,
                      )
                    else
                      const SizedBox(width: 56), // Placeholder for spacing
                    _ToolIcon(
                      icon: Icons.music_note,
                      label: 'Music',
                      onTap: _pickMusic,
                    ),
                    _ToolIcon(
                      icon: Icons.perm_media,
                      label: 'Choose',
                      onTap: _pickMedia,
                    ),
                    if (_mediaItems.length > 1)
                      _ToolIcon(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        onTap: _removeCurrentMedia,
                      ),
                    _ToolIcon(
                      icon: Icons.refresh,
                      label: 'Reset',
                      onTap: () => setState(() {
                        for (final item in _mediaItems) {
                          item.editedImageBytes = null;
                        }
                        _selectedTrack = null;
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(MediaItem item) {
    if (item.videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
      );
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: item.videoController!.value.aspectRatio == 0
              ? 9 / 16
              : item.videoController!.value.aspectRatio,
          child: VideoPlayer(item.videoController!),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 153),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.file.path.split('/').last,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 179),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageViewer(MediaItem item) {
    final hasEditedVersion = item.editedImageBytes != null;
    return hasEditedVersion
        ? Image.memory(item.editedImageBytes!, fit: BoxFit.contain)
        : Image.file(File(item.file.path), fit: BoxFit.contain);
  }
}

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
