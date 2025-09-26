import 'dart:typed_data';
import 'dart:io' show File, Directory; // Only used on non-web platforms

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:dio/dio.dart';

import 'core/api_client.dart';
import 'core/files_api.dart';
import 'core/stories_api.dart';

enum StoryComposeType { image, video, text, mixed }

// Bottom sheet to pick the composer type
class StoryTypePicker {
  static void show(
    BuildContext context, {
    required void Function(StoryComposeType type) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
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
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFBFAE01).withValues(alpha: 38),
                    child: const Icon(Icons.perm_media, color: Colors.white),
                  ),
                  title: Text('Media story', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(StoryComposeType.mixed);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFBFAE01).withValues(alpha: 38),
                    child: const Icon(Icons.text_fields, color: Colors.white),
                  ),
                  title: Text('Text story', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
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

// Simple music model and picker
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
  MusicTrack(id: '1', title: 'Sunrise Drive', artist: 'Nexum Beats', duration: Duration(minutes: 2, seconds: 14)),
  MusicTrack(id: '2', title: 'Golden Hour', artist: 'Nova', duration: Duration(minutes: 3, seconds: 2)),
  MusicTrack(id: '3', title: 'Focus Flow', artist: 'Deepwork', duration: Duration(minutes: 2, seconds: 47)),
  MusicTrack(id: '4', title: 'Night Vibes', artist: 'Pulse', duration: Duration(minutes: 2, seconds: 38)),
  MusicTrack(id: '5', title: 'City Lights', artist: 'Skyline', duration: Duration(minutes: 1, seconds: 55)),
  MusicTrack(id: '6', title: 'Cloud Surf', artist: 'Aero', duration: Duration(minutes: 2, seconds: 20)),
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
                  Icon(Icons.music_note, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'Select music',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
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
                  String two(int n) => n.toString().padLeft(2, '0');
                  final mm = two(t.duration.inMinutes.remainder(60));
                  final ss = two(t.duration.inSeconds.remainder(60));
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
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                    ),
                    subtitle: Text('${t.artist}  •  $mm:$ss', style: GoogleFonts.inter(color: const Color(0xFF666666))),
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

class MixedMediaStoryComposerPage extends StatefulWidget {
  const MixedMediaStoryComposerPage({super.key});
  @override
  State<MixedMediaStoryComposerPage> createState() => _MixedMediaStoryComposerPageState();
}

class MediaItem {
  final XFile file;
  final bool isVideo;
  VideoPlayerController? videoController;

  // Image data
  Uint8List? imageBytes; // web-safe original
  Uint8List? editedImageBytes; // from editor

  // Flags and metadata
  bool fitCover;
  bool muted;
  int? fileSizeBytes;
  Duration? videoDuration;

  MediaItem({
    required this.file,
    required this.isVideo,
    this.videoController,
    this.imageBytes,
    this.editedImageBytes,
    this.fitCover = true,
    this.muted = false,
    this.fileSizeBytes,
    this.videoDuration,
  });
}

class _MixedMediaStoryComposerPageState extends State<MixedMediaStoryComposerPage> {
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();
  final List<MediaItem> _items = [];
  int _index = 0;

  MusicTrack? _selectedTrack;

  @override
  void dispose() {
    _pageController.dispose();
    for (final it in _items) {
      it.videoController?.dispose();
    }
    super.dispose();
  }

  // Helpers
  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double b = bytes.toDouble();
    int i = 0;
    while (b >= 1024 && i < units.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(b < 10 ? 1 : 0)} ${units[i]}';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // Pick media
  Future<void> _pickMedia() async {
    try {
      final files = await _picker.pickMultipleMedia(limit: 10);
      await _appendPicked(files);
    } catch (_) {
      final one = await _picker.pickMedia();
      if (one != null) await _appendPicked([one]);
    }
  }

  Future<void> _appendPicked(List<XFile> files) async {
    if (files.isEmpty) return;

    for (final f in files) {
      final isVideo = f.mimeType?.startsWith('video/') ?? false;
      int? size;
      try {
        size = await f.length(); // web-safe file size
      } catch (_) {}

      if (isVideo) {
        final vc = kIsWeb
            ? VideoPlayerController.networkUrl(Uri.parse(f.path))
            : VideoPlayerController.file(File(f.path));
        try {
          await vc.initialize();
          await vc.setLooping(true);
          _items.add(MediaItem(
            file: f,
            isVideo: true,
            videoController: vc,
            videoDuration: vc.value.duration,
            muted: false,
            fileSizeBytes: size,
          ));
        } catch (_) {
          vc.dispose();
        }
      } else {
        Uint8List? bytes;
        if (kIsWeb) {
          try {
            bytes = await f.readAsBytes();
          } catch (_) {}
        }
        _items.add(
          MediaItem(
            file: f,
            isVideo: false,
            imageBytes: bytes,
            fileSizeBytes: size,
            fitCover: true,
          ),
        );
      }
    }

    if (_items.isNotEmpty && _items[_index].isVideo) {
      _items[_index].videoController?.play();
    }
    setState(() {});
  }

  // Edit image
  Future<void> _editCurrent() async {
    if (_items.isEmpty || _items[_index].isVideo) return;

    final srcBytes = await _items[_index].file.readAsBytes();

    final edited = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => ProImageEditor.memory(
          srcBytes,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) {
              Navigator.pop(context, bytes);
              return Future.value();
            },
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (edited != null) {
      setState(() {
        _items[_index].editedImageBytes = edited;
      });
    }
  }

  // Page change
  void _onPageChanged(int i) {
    for (final it in _items) {
      it.videoController?.pause();
    }
    setState(() => _index = i);
    final cur = _items[i];
    if (cur.isVideo) {
      cur.videoController?.setVolume(cur.muted ? 0.0 : 1.0);
      cur.videoController?.play();
    }
  }

  // Toggles
  void _toggleFit() {
    if (_items.isEmpty) return;
    final current = _items[_index];
    if (current.isVideo) return;
    setState(() {
      current.fitCover = !current.fitCover;
    });
  }

  void _toggleMute() {
    if (_items.isEmpty) return;
    final current = _items[_index];
    if (!current.isVideo) return;
    setState(() {
      current.muted = !current.muted;
      current.videoController?.setVolume(current.muted ? 0.0 : 1.0);
    });
  }

  void _togglePlayPause() {
    if (_items.isEmpty) return;
    final current = _items[_index];
    if (!current.isVideo) return;
    final vc = current.videoController;
    if (vc == null || !vc.value.isInitialized) return;
    setState(() {
      if (vc.value.isPlaying) {
        vc.pause();
      } else {
        vc.play();
      }
    });
  }

  // Upload helpers
  Future<File> _tmpWrite(Uint8List bytes, {String ext = 'jpg'}) async {
    final dir = await Directory.systemTemp.createTemp('nexum_story_');
    final file = File('${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Map<String, String>> _uploadBytesWeb(Uint8List bytes, {required String ext, required String mime}) async {
    final dio = ApiClient().dio;
    final pres = await dio.post('/api/files/presign-upload', data: {'ext': ext});
    final data = Map<String, dynamic>.from(Map<String, dynamic>.from(pres.data)['data'] ?? {});
    final putUrl = data['putUrl'] as String;
    final key = data['key'] as String;
    final readUrl = (data['readUrl'] ?? '').toString();
    final publicUrl = (data['publicUrl'] ?? '').toString();
    final bestUrl = readUrl.isNotEmpty ? readUrl : publicUrl;

    final s3 = Dio();
    await s3.put(
      putUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': mime, 'Content-Length': bytes.length}),
    );

    try {
      await dio.post('/api/files/confirm', data: {'key': key, 'url': bestUrl});
    } catch (_) {}

    return {'key': key, 'url': bestUrl};
  }

  // Post to backend
  Future<void> _post() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No media selected', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading...', style: GoogleFonts.inter())),
      );

      final filesApi = FilesApi();
      final storiesApi = StoriesApi();
      final payload = <Map<String, dynamic>>[];

      for (final it in _items) {
        if (it.isVideo) {
          if (kIsWeb) {
            final bytes = await it.file.readAsBytes();
            final mime = it.file.mimeType ?? 'video/mp4';
            final ext = mime.contains('webm')
                ? 'webm'
                : (mime.contains('ogg') ? 'ogg' : 'mp4');
            final up = await _uploadBytesWeb(bytes, ext: ext, mime: mime);
            payload.add({'media_type': 'video', 'media_url': up['url'], 'privacy': 'public'});
          } else {
            final up = await filesApi.uploadFile(File(it.file.path));
            payload.add({'media_type': 'video', 'media_url': up['url'], 'privacy': 'public'});
          }
        } else {
          if (kIsWeb) {
            final bytes = it.editedImageBytes ?? it.imageBytes ?? await it.file.readAsBytes();
            final mime = it.file.mimeType ?? 'image/jpeg';
            final ext = mime.contains('png')
                ? 'png'
                : (mime.contains('webp') ? 'webp' : 'jpg');
            final up = await _uploadBytesWeb(bytes, ext: ext, mime: mime);

            String? audioUrl;
            String? audioTitle;
            if (_selectedTrack != null) {
              // Replace with real music URL when available
              audioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
              audioTitle = _selectedTrack!.title;
            }

            payload.add({
              'media_type': 'image',
              'media_url': up['url'],
              if (audioUrl != null) 'audio_url': audioUrl,
              if (audioTitle != null) 'audio_title': audioTitle,
              'privacy': 'public',
            });
          } else {
            if (it.editedImageBytes != null) {
              final f = await _tmpWrite(it.editedImageBytes!, ext: 'jpg');
              final up = await filesApi.uploadFile(f);
              payload.add({'media_type': 'image', 'media_url': up['url'], 'privacy': 'public'});
            } else {
              final up = await filesApi.uploadFile(File(it.file.path));
              payload.add({'media_type': 'image', 'media_url': up['url'], 'privacy': 'public'});
            }

            // Optional music on image
            if (_selectedTrack != null) {
              payload.last['audio_url'] = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
              payload.last['audio_title'] = _selectedTrack!.title;
            }
          }
        }
      }

      // Create all stories in one request
      await storiesApi.createStoriesBatch(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Story posted!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF4CAF50)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post story', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  // UI builders
  Widget _buildVideo(MediaItem it) {
    final vc = it.videoController;
    if (vc == null || !vc.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFBFAE01))),
      );
    }
    return AspectRatio(aspectRatio: vc.value.aspectRatio == 0 ? 9 / 16 : vc.value.aspectRatio, child: VideoPlayer(vc));
  }

  Widget _buildImage(MediaItem it) {
    final edited = it.editedImageBytes;
    if (edited != null) {
      return Image.memory(edited, fit: it.fitCover ? BoxFit.cover : BoxFit.contain);
    }
    if (kIsWeb) {
      if (it.imageBytes != null) {
        return Image.memory(it.imageBytes!, fit: it.fitCover ? BoxFit.cover : BoxFit.contain);
      }
      return Image.network(it.file.path, fit: it.fitCover ? BoxFit.cover : BoxFit.contain);
    }
    return Image.file(File(it.file.path), fit: it.fitCover ? BoxFit.cover : BoxFit.contain);
  }

  Widget _buildPreview(MediaItem it) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Content with zoom/pan
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                minScale: 1,
                child: it.isVideo ? _buildVideo(it) : _buildImage(it),
              ),
            ),

            // Meta chip top-left (name • size[/duration])
            Positioned(
              left: 12,
              top: 12,
              child: _buildMetaChip(it),
            ),

            // Toggle buttons top-right (fit / mute)
            Positioned(
              right: 12,
              top: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!it.isVideo)
                    _roundIcon(
                      icon: it.fitCover ? Icons.crop_free : Icons.fit_screen,
                      tooltip: it.fitCover ? 'Fit contain' : 'Fit cover',
                      onTap: _toggleFit,
                    ),
                  if (it.isVideo) ...[
                    const SizedBox(width: 8),
                    _roundIcon(
                      icon: it.muted ? Icons.volume_off : Icons.volume_up,
                      tooltip: it.muted ? 'Unmute' : 'Mute',
                      onTap: _toggleMute,
                    ),
                  ],
                ],
              ),
            ),

            // Center play/pause overlay for video
            if (it.isVideo)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: Icon(
                      (it.videoController?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

            // Music chip if selected
            if (_selectedTrack != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 128),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note, size: 16, color: Colors.black),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedTrack!.title} • ${_selectedTrack!.artist}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedTrack = null),
                          child: const Icon(Icons.close, size: 16, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(MediaItem it) {
    String name;
    try {
      // XFile.name is available in recent image_picker versions
      name = (it.file.name.isNotEmpty ? it.file.name : it.file.path.split('/').last);
    } catch (_) {
      name = it.file.path.split('/').last;
    }
    final sizeTxt = it.fileSizeBytes != null ? _formatBytes(it.fileSizeBytes!) : null;
    final durationTxt = it.isVideo
        ? _formatDuration(it.videoDuration ?? it.videoController?.value.duration ?? Duration.zero)
        : null;

    final text = it.isVideo
        ? '$name • ${durationTxt ?? '--:--'}${sizeTxt != null ? ' • $sizeTxt' : ''}'
        : '$name${sizeTxt != null ? ' • $sizeTxt' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
      ),
    );
  }

  Widget _roundIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 204),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.black),
        ),
      ),
    );
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

  void _resetAll() {
    setState(() {
      for (final item in _items) {
        item.editedImageBytes = null;
        item.fitCover = true;
        if (item.isVideo) {
          item.muted = false;
          item.videoController?.setVolume(1.0);
        }
      }
      _selectedTrack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(_items.length > 1 ? '${_items.length} Stories' : 'Story',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _post,
            child: Text('Post', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _items.isEmpty
                    ? _PickPlaceholder(onPick: _pickMedia)
                    : Column(
                        children: [
                          if (_items.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _index > 0
                                        ? () {
                                            setState(() => _index--);
                                            _pageController.previousPage(
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    color: Colors.white,
                                  ),
                                  Text('${_index + 1}/${_items.length}',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                                  IconButton(
                                    onPressed: _index < _items.length - 1
                                        ? () {
                                            setState(() => _index++);
                                            _pageController.nextPage(
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _items.length,
                              onPageChanged: _onPageChanged,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: _buildPreview(_items[i]),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Bottom circular actions row (Edit, Music, Choose, Reset)
            if (_items.isNotEmpty)
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleAction(
                      icon: Icons.edit,
                      label: 'Edit',
                      enabled: !_items[_index].isVideo,
                      onTap: !_items[_index].isVideo ? _editCurrent : null,
                    ),
                    _CircleAction(
                      icon: Icons.music_note,
                      label: 'Music',
                      onTap: _pickMusic,
                    ),
                    _CircleAction(
                      icon: Icons.add,
                      label: 'Choose',
                      onTap: _pickMedia,
                    ),
                    _CircleAction(
                      icon: Icons.replay,
                      label: 'Reset',
                      onTap: _resetAll,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _CircleAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFBFAE01) : const Color(0xFFBFAE01).withValues(alpha: 77),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.black, size: 24),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: enabled ? onTap : null,
          child: circle,
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.inter(color: Colors.white)),
      ],
    );
  }
}

// Text story page (kept, unchanged style)
class TextStoryComposerPage extends StatefulWidget {
  const TextStoryComposerPage({super.key});
  @override
  State<TextStoryComposerPage> createState() => _TextStoryComposerPageState();
}

class _TextStoryComposerPageState extends State<TextStoryComposerPage> {
  final _controller = TextEditingController();
  Color _bg = const Color(0xFFE74C3C);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Write something', style: GoogleFonts.inter())));
      return;
    }
    try {
      final hex = '#${_bg.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
      await StoriesApi().createStory(mediaType: 'text', textContent: text, backgroundColor: hex);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Story posted!', style: GoogleFonts.inter()), backgroundColor: const Color(0xFF4CAF50)),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to post story', style: GoogleFonts.inter()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Story', style: GoogleFonts.inter()),
        actions: [TextButton(onPressed: _postText, child: Text('Post', style: GoogleFonts.inter(fontWeight: FontWeight.w700)))],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: _bg,
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: TextField(
                controller: _controller,
                maxLines: null,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 22, color: Colors.white, height: 1.3),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Type your story...'),
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
                for (final c in [0xFFE74C3C, 0xFF2ECC71, 0xFF3498DB, 0xFFF1C40F, 0xFF9B59B6, 0xFF34495E, 0xFF1ABC9C])
                  GestureDetector(
                    onTap: () => setState(() => _bg = Color(c)),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
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

class _PickPlaceholder extends StatelessWidget {
  final VoidCallback onPick;
  const _PickPlaceholder({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: const Icon(Icons.perm_media, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        Text('Select images and videos', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 179), fontSize: 16)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onPick,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
          child: Text('Pick Media', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}