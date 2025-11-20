import 'dart:io' as io;
import 'dart:ui' as ui show instantiateImageCodec, ImageByteFormat, Image, PictureRecorder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MediaPreviewResult {
  final List<XFile> files;
  final String caption;

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

  String _extForMime(String mime) {
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    return 'jpg';
  }

  Future<Uint8List> _downscaleForEditor(Uint8List input, {required int maxSide}) async {
    try {
      final codec0 = await ui.instantiateImageCodec(input);
      final frame0 = await codec0.getNextFrame();
      final w = frame0.image.width;
      final h = frame0.image.height;
      final maxDim = w > h ? w : h;
      if (maxDim <= maxSide) return input;

      final scale = maxSide / maxDim;
      final targetW = (w * scale).round().clamp(1, w);
      final targetH = (h * scale).round().clamp(1, h);

      final codec = await ui.instantiateImageCodec(
        input,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return input;
      return data.buffer.asUint8List();
    } catch (_) {
      return input;
    }
  }

  Future<void> _editCurrent() async {
    if (_files.isEmpty) return;
    final current = _files[_index];
    if (_isVideo(current)) return;

    try {
      final originalBytes = await current.readAsBytes();
      if (!mounted) return;

      final editorBytes = await _downscaleForEditor(
        originalBytes,
        maxSide: kIsWeb ? 1280 : 2048,
      );
      if (!mounted) return;

      dynamic result;

      if (kIsWeb) {
        // Fallback editor on Web to avoid plugin apply hang
        result = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => SimpleWebEditorPage(
              bytes: editorBytes,
              isDark: widget.isDark,
            ),
          ),
        );
      } else {
        // Mobile/Desktop: use plugin
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProImageEditor.memory(
              editorBytes,
              callbacks: ProImageEditorCallbacks(),
            ),
          ),
        );
      }

      if (!mounted) return;

      // Normalize result
      Uint8List? editedBytes;
      String? editedPath;
      XFile? editedXFile;

      if (result is Uint8List) {
        editedBytes = result;
      } else if (result is XFile) {
        editedXFile = result;
      } else if (result is String) {
        editedPath = result;
      } else if (result is Map) {
        final dynamic v = result['bytes'] ?? result['image'] ?? result['data'] ?? result['result'];
        if (v is Uint8List) {
          editedBytes = v;
        }
        if (v is XFile) {
          editedXFile = v;
        }
        if (v is String) {
          editedPath = v;
        }
      }

      final mime = _mimeFromPath(current.path);

      if (kIsWeb) {
        // Use plugin-returned XFile when available, else in-memory bytes
        if (editedBytes != null) {
        final web = XFile.fromData(
          editedBytes,
          mimeType: mime,
          name: 'edited_${DateTime.now().millisecondsSinceEpoch}.${_extForMime(mime)}',
        );
        setState(() => _files[_index] = web);
      }
      } else {
        // Mobile/Desktop: prefer XFile, then path, else bytes
        if (editedPath != null && editedPath.isNotEmpty) {
        final xf = XFile(editedPath, mimeType: mime, name: io.File(editedPath).uri.pathSegments.last);
        setState(() => _files[_index] = xf);
      } else if (editedBytes != null) {
        final ext = _extForMime(mime);
        final dirPath = io.File(current.path).parent.path;
        final sep = io.Platform.pathSeparator;
        final filename = 'edited_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final outPath = '$dirPath$sep$filename';
        final outFile = io.File(outPath);
        await outFile.writeAsBytes(editedBytes);
        final xf = XFile(outFile.path, mimeType: mime, name: filename);
        setState(() => _files[_index] = xf);
      }
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
              icon: Icon(Icons.edit, color: isDark ? Colors.white : Colors.black),
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
                color: _files.isEmpty ? const Color(0xFF999999) : const Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Center(
                                child: _isVideo(f)
                                    ? InlineVideoPlayer(file: f, isDark: isDark)
                                    : _buildZoomableImage(f),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _roundIcon(
                            icon: Icons.delete_outline,
                            onTap: _files.isEmpty ? null : _removeCurrent,
                            isDark: isDark,
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 26) : Colors.black.withValues(alpha: 26),
                  ),
                ),
                child: TextField(
                  controller: _captionController,
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(height: 8),
            ],
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
                  proxyDecorator: (child, index, animation) => Transform.scale(scale: 1.03, child: child),
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
                                  color: selected ? const Color(0xFF007AFF) : Colors.transparent,
                                  width: 2,
                                ),
                                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF1F4F8),
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
                                  child: const Icon(Icons.videocam, size: 14, color: Colors.white),
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
          color: (isDark ? Colors.white10 : Colors.white).withValues(alpha: enabled ? 1 : 0.5),
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
          color: enabled ? (isDark ? Colors.white : Colors.black87) : const Color(0xFF999999),
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
      Navigator.pop(context, MediaPreviewResult(files: const [], caption: ''));
    }
  }

  void _jumpTo(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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

  // Optimized viewer with downscaled decode and spinner until first frame.
  Widget _buildZoomableImage(XFile file) {
    if (!kIsWeb) {
      final f = io.File(file.path);
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Image.file(
            f,
            fit: BoxFit.contain,
            cacheWidth: 1024,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSync) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  child,
                  if (frame == null)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black12,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData) {
          return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 48));
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.memory(
              snap.data!,
              fit: BoxFit.contain,
              cacheWidth: 1024,
              filterQuality: FilterQuality.medium,
              frameBuilder: (context, child, frame, wasSync) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    child,
                    if (frame == null)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black12,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                );
              },
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

    if (!kIsWeb) {
      return Image.file(
        io.File(file.path),
        fit: BoxFit.cover,
        cacheWidth: 128,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSync) {
          return Stack(
            alignment: Alignment.center,
            children: [
              child,
              if (frame == null)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black12,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
          cacheWidth: 128,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSync) {
            return Stack(
              alignment: Alignment.center,
              children: [
                child,
                if (frame == null)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/* ============================
   Simple editor for Web only
   ============================ */

class SimpleWebEditorPage extends StatefulWidget {
  final Uint8List bytes;
  final bool isDark;

  const SimpleWebEditorPage({
    super.key,
    required this.bytes,
    required this.isDark,
  });

  @override
  State<SimpleWebEditorPage> createState() => _SimpleWebEditorPageState();
}

class _SimpleWebEditorPageState extends State<SimpleWebEditorPage> {
  double _imgW = 0;
  double _imgH = 0;

  // Strokes are stored as normalized points (0..1) in display space
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  final double _penPx = 4.0;
  final Color _penColor = Colors.redAccent;

  double _overlayW = 1;
  double _overlayH = 1;

  @override
  void initState() {
    super.initState();
    _decodeDims();
  }

  Future<void> _decodeDims() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _imgW = frame.image.width.toDouble();
        _imgH = frame.image.height.toDouble();
      });
    } catch (_) {
      // Fallback
      setState(() {
        _imgW = 1080;
        _imgH = 1350;
      });
    }
  }

  void _startStroke(Offset local) {
    if (_overlayW <= 0 || _overlayH <= 0) return;
    final nx = (local.dx / _overlayW).clamp(0.0, 1.0);
    final ny = (local.dy / _overlayH).clamp(0.0, 1.0);
    _current = [Offset(nx, ny)];
    setState(() {});
  }

  void _appendStroke(Offset local) {
    if (_current == null) return;
    final nx = (local.dx / _overlayW).clamp(0.0, 1.0);
    final ny = (local.dy / _overlayH).clamp(0.0, 1.0);
    _current = [..._current!, Offset(nx, ny)];
    setState(() {});
  }

  void _endStroke() {
    if (_current != null && _current!.length > 1) {
      _strokes.add(_current!);
    }
    _current = null;
    setState(() {});
  }

  void _undo() {
    if (_current != null && _current!.isNotEmpty) {
      _current = null;
    } else if (_strokes.isNotEmpty) {
      _strokes.removeLast();
    }
    setState(() {});
  }

  void _clearAll() {
    _strokes.clear();
    _current = null;
    setState(() {});
  }

  Future<void> _save() async {
    // Compose annotations onto the image at its current resolution
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      final ui.Image base = frame.image;
      final int w = base.width;
      final int h = base.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw base
      final paint = Paint();
      canvas.drawImage(base, Offset.zero, paint);

      // Draw strokes
      final strokePaint = Paint()
        ..color = _penColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final thickness = _penPx * (w / 400.0);
      strokePaint.strokeWidth = thickness.clamp(2.0, 16.0);

      List<List<Offset>> all = List.from(_strokes);
      if (_current != null && _current!.length > 1) {
        all = [...all, _current!];
      }

      for (final stroke in all) {
        if (stroke.length < 2) continue;
        final path = Path()
          ..moveTo(stroke.first.dx * w, stroke.first.dy * h);
        for (int i = 1; i < stroke.length; i++) {
          final p = stroke[i];
          path.lineTo(p.dx * w, p.dy * h);
        }
        canvas.drawPath(path, strokePaint);
      }

      final picture = recorder.endRecording();
      final ui.Image out = await picture.toImage(w, h);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        if (!mounted) return;
        Navigator.pop<Uint8List?>(context, null);
        return;
      }
      final bytes = data.buffer.asUint8List();
      if (!mounted) return;
      Navigator.pop<Uint8List?>(context, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          'Quick Edit',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: (_strokes.isEmpty && (_current == null || _current!.isEmpty)) ? null : _undo,
            icon: Icon(Icons.undo, color: isDark ? Colors.white : Colors.black),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _strokes.isEmpty && _current == null ? null : _clearAll,
            icon: Icon(Icons.delete_sweep, color: isDark ? Colors.white : Colors.black),
          ),
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: const Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _imgW <= 0 || _imgH <= 0
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: AspectRatio(
                aspectRatio: _imgW / _imgH,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _overlayW = constraints.maxWidth;
                    _overlayH = constraints.maxHeight;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: (d) {
                              final rb = context.findRenderObject() as RenderBox;
                              _startStroke(rb.globalToLocal(d.globalPosition));
                            },
                            onPanUpdate: (d) {
                              final rb = context.findRenderObject() as RenderBox;
                              _appendStroke(rb.globalToLocal(d.globalPosition));
                            },
                            onPanEnd: (_) => _endStroke(),
                            child: CustomPaint(
                              painter: _ScribblePainter(
                                strokes: _strokes,
                                current: _current,
                                color: _penColor,
                                penPx: _penPx,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _ScribblePainter extends CustomPainter {
  final List<List<Offset>> strokes; // normalized
  final List<Offset>? current; // normalized
  final Color color;
  final double penPx;

  _ScribblePainter({
    required this.strokes,
    required this.current,
    required this.color,
    required this.penPx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = (penPx * (size.width / 400)).clamp(2.0, 16.0);

    void drawStroke(List<Offset> s) {
      if (s.length < 2) return;
      final path = Path()
        ..moveTo(s.first.dx * size.width, s.first.dy * size.height);
      for (int i = 1; i < s.length; i++) {
        final p = s[i];
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      drawStroke(s);
    }
    if (current != null) drawStroke(current!);
  }

  @override
  bool shouldRepaint(covariant _ScribblePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.current != current ||
        oldDelegate.color != color ||
        oldDelegate.penPx != penPx;
  }
}

/* ============================
   Inline video (unchanged)
   ============================ */

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
  bool _muted = false;

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
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.file.path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        _controller = VideoPlayerController.file(
          io.File(widget.file.path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      await _controller!.setVolume(_muted ? 0.0 : 1.0);
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

  Future<void> _toggleMute() async {
    if (_controller == null) return;
    setState(() => _muted = !_muted);
    await _controller!.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final ratio = _initialized
        ? (_controller!.value.aspectRatio == 0 ? (9 / 16) : _controller!.value.aspectRatio)
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
                  opacity: _showOverlay || !(_controller?.value.isPlaying ?? false) ? 1 : 0,
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
              top: 8,
              right: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 22,
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