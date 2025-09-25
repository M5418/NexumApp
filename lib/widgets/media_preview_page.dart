import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MediaPreviewResult {
  final List<XFile> files;
  final String caption; // caption entered in the preview

  MediaPreviewResult({
    required this.files,
    this.caption = '',
  });
}

class MediaPreviewPage extends StatefulWidget {
  final List<XFile> initialFiles;
  final bool isDark;

  const MediaPreviewPage({
    super.key,
    required this.initialFiles,
    required this.isDark,
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late List<XFile> _files;
  late final PageController _pageController;
  late final TextEditingController _captionController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _files = List<XFile>.from(widget.initialFiles);
    _pageController = PageController();
    _captionController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  bool _isVideo(XFile f) {
    final p = f.path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.webm') ||
        p.endsWith('.mkv') ||
        p.endsWith('.avi');
  }

  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _editCurrent() async {
    if (_files.isEmpty) return;
    final current = _files[_index];
    if (_isVideo(current)) return; // editing only for images

    try {
      final bytes = await current.readAsBytes();
      if (!mounted) return;

      final editedBytes = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(
          builder: (_) => ProImageEditor.memory(
            bytes,
            callbacks: ProImageEditorCallbacks(),
          ),
        ),
      );

      if (!mounted) return;

      if (editedBytes != null) {
        final mime = _mimeFromPath(current.path);
        final edited = XFile.fromData(
          editedBytes,
          mimeType: mime,
          name:
              'edited_${DateTime.now().millisecondsSinceEpoch}${mime == 'image/png' ? '.png' : '.jpg'}',
        );
        setState(() {
          _files[_index] = edited;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preview',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_files.isNotEmpty && !_isVideo(_files[_index]))
            IconButton(
              tooltip: 'Edit',
              onPressed: _editCurrent,
              icon:
                  Icon(Icons.edit, color: isDark ? Colors.white : Colors.black),
            ),
          TextButton(
            onPressed: _files.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      MediaPreviewResult(
                        files: _files,
                        caption: _captionController.text.trim(),
                      ),
                    ),
            child: Text(
              'Send (${_files.length})',
              style: GoogleFonts.inter(
                color: _files.isEmpty
                    ? const Color(0xFF999999)
                    : const Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main viewer (story-like)
            Expanded(
              child: _files.isEmpty
                  ? Center(
                      child: Text(
                        'No media selected',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _files.length,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (context, i) {
                            final f = _files[i];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Center(
                                child: _isVideo(f)
                                    ? InlineVideoPlayer(file: f, isDark: isDark)
                                    : _buildZoomableImage(f),
                              ),
                            );
                          },
                        ),

                        // Delete button
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _roundIcon(
                            icon: Icons.delete_outline,
                            onTap: _files.isEmpty ? null : _removeCurrent,
                            isDark: isDark,
                          ),
                        ),

                        // Index bubble
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_index + 1}/${_files.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // Caption input (inline, replaces any previous popup)
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 26)
                        : Colors.black.withValues(alpha: 26),
                  ),
                ),
                child: TextField(
                  controller: _captionController,
                  decoration: InputDecoration(
                    hintText: 'Add a caption (optional)...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Bottom strip (reorderable thumbnails)
            if (_files.isNotEmpty)
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _files.length,
                  onReorder: _onReorder,
                  proxyDecorator: (child, index, animation) {
                    return Transform.scale(
                      scale: 1.03,
                      child: child,
                    );
                  },
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    final selected = i == _index;
                    return Container(
                      key: ValueKey(f.path),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => _jumpTo(i),
                        child: Stack(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF007AFF)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                color: isDark
                                    ? const Color(0xFF1C1C1E)
                                    : const Color(0xFFF1F4F8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildThumb(f),
                            ),
                            if (_isVideo(f))
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon({
    required IconData icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              (isDark ? Colors.white10 : Colors.white).withValues(alpha: enabled ? 1 : 0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: enabled
              ? (isDark ? Colors.white : Colors.black87)
              : const Color(0xFF999999),
          size: 20,
        ),
      ),
    );
  }

  void _removeCurrent() {
    if (_files.isEmpty) return;
    setState(() {
      _files.removeAt(_index);
      if (_index >= _files.length) _index = _files.length - 1;
      if (_index < 0) _index = 0;
    });
    if (_files.isEmpty) {
      // Auto close when all removed
      Navigator.pop(context, MediaPreviewResult(files: const [], caption: ''));
    }
  }

  void _jumpTo(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _files.removeAt(oldIndex);
      _files.insert(newIndex, item);
      if (_index == oldIndex) {
        _index = newIndex;
        _jumpTo(_index);
      } else {
        if (oldIndex < _index && newIndex >= _index) {
          _index -= 1;
        } else if (oldIndex > _index && newIndex <= _index) {
          _index += 1;
        }
      }
    });
  }

  Widget _buildZoomableImage(XFile file) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
          );
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              snap.data!,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumb(XFile file) {
    if (_isVideo(file)) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam, color: Colors.white70, size: 28),
      );
    }
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || !snap.hasData) {
          return Container(
            color: const Color(0xFF666666).withValues(alpha: 0.2),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.memory(
          snap.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class InlineVideoPlayer extends StatefulWidget {
  final XFile file;
  final bool isDark;

  const InlineVideoPlayer({
    super.key,
    required this.file,
    required this.isDark,
  });

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _disposeController();
      _init();
    }
  }

  Future<void> _init() async {
    try {
      if (kIsWeb) {
        _controller =
            VideoPlayerController.networkUrl(Uri.parse(widget.file.path));
      } else {
        _controller = VideoPlayerController.file(io.File(widget.file.path));
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized || _controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {
      _showOverlay = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final ratio = _initialized
        ? (_controller!.value.aspectRatio == 0
            ? (9 / 16)
            : _controller!.value.aspectRatio)
        : (9 / 16);

    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        children: [
          Container(
            color: Colors.black,
            child: _initialized && _controller != null
                ? VideoPlayer(_controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlay,
                child: AnimatedOpacity(
                  opacity:
                      _showOverlay || !(_controller?.value.isPlaying ?? false)
                          ? 1
                          : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    color: Colors.black26,
                    child: Center(
                      child: Icon(
                        (_controller?.value.isPlaying ?? false)
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_initialized && _controller != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF007AFF),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _timeText(_controller!.value.position, isDark),
                      _timeText(_controller!.value.duration, isDark),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeText(Duration d, bool isDark) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return Text(
      '$m:%s'.replaceFirst('%s', s),
      style: GoogleFonts.inter(
        fontSize: 12,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }
}