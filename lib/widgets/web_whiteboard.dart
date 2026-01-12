import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A stroke on the whiteboard
class WhiteboardStroke {
  final String id;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String oderId;
  final DateTime createdAt;

  WhiteboardStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.oderId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'oderId': oderId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List?)?.map((p) {
      final map = p as Map<String, dynamic>;
      return Offset(
        (map['x'] as num?)?.toDouble() ?? 0,
        (map['y'] as num?)?.toDouble() ?? 0,
      );
    }).toList() ?? <Offset>[];

    return WhiteboardStroke(
      id: json['id'] as String? ?? '',
      points: pointsList,
      color: Color(json['color'] as int? ?? 0xFF000000),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      oderId: json['oderId'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Web-compatible whiteboard widget with Firebase sync
class WebWhiteboard extends StatefulWidget {
  final String meetingId;
  final String oderId;
  final bool readOnly;
  final Color initialColor;
  final double initialStrokeWidth;

  const WebWhiteboard({
    super.key,
    required this.meetingId,
    required this.oderId,
    this.readOnly = false,
    this.initialColor = Colors.black,
    this.initialStrokeWidth = 3.0,
  });

  @override
  State<WebWhiteboard> createState() => _WebWhiteboardState();
}

class _WebWhiteboardState extends State<WebWhiteboard> {
  final List<WhiteboardStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 3.0;
  bool _isEraser = false;
  
  StreamSubscription<QuerySnapshot>? _strokesSub;
  Timer? _syncTimer;
  final List<WhiteboardStroke> _pendingStrokes = [];
  
  // Throttle sync to avoid excessive writes
  static const _syncInterval = Duration(milliseconds: 500);
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _currentStrokeWidth = widget.initialStrokeWidth;
    _subscribeToStrokes();
  }

  @override
  void dispose() {
    _strokesSub?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _subscribeToStrokes() {
    final ref = FirebaseFirestore.instance
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('whiteboard')
        .orderBy('createdAt');

    _strokesSub = ref.snapshots().listen((snapshot) {
      if (!mounted) return;
      
      final remoteStrokes = <WhiteboardStroke>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        remoteStrokes.add(WhiteboardStroke.fromJson(data));
      }
      
      setState(() {
        _strokes.clear();
        _strokes.addAll(remoteStrokes);
      });
    });
  }

  Future<void> _syncStroke(WhiteboardStroke stroke) async {
    try {
      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meetingId)
          .collection('whiteboard')
          .doc(stroke.id)
          .set(stroke.toJson());
    } catch (e) {
      debugPrint('WebWhiteboard: Error syncing stroke: $e');
    }
  }

  void _throttledSync() {
    final now = DateTime.now();
    if (now.difference(_lastSync) < _syncInterval) {
      _syncTimer?.cancel();
      _syncTimer = Timer(_syncInterval, () {
        _flushPendingStrokes();
      });
      return;
    }
    _flushPendingStrokes();
  }

  void _flushPendingStrokes() {
    _lastSync = DateTime.now();
    for (final stroke in _pendingStrokes) {
      _syncStroke(stroke);
    }
    _pendingStrokes.clear();
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.readOnly) return;
    
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentPoints = [localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.readOnly) return;
    
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentPoints = [..._currentPoints, localPosition];
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.readOnly || _currentPoints.isEmpty) return;
    
    final stroke = WhiteboardStroke(
      id: '${widget.oderId}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      points: List.from(_currentPoints),
      color: _isEraser ? Colors.white : _currentColor,
      strokeWidth: _isEraser ? _currentStrokeWidth * 3 : _currentStrokeWidth,
      oderId: widget.oderId,
      createdAt: DateTime.now(),
    );
    
    setState(() {
      _strokes.add(stroke);
      _currentPoints = [];
    });
    
    _pendingStrokes.add(stroke);
    _throttledSync();
  }

  Future<void> _clearBoard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Whiteboard'),
        content: const Text('Are you sure you want to clear all drawings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final docs = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meetingId)
          .collection('whiteboard')
          .get();
      
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      if (mounted) {
        setState(() {
          _strokes.clear();
        });
      }
    } catch (e) {
      debugPrint('WebWhiteboard: Error clearing board: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        if (!widget.readOnly) _buildToolbar(),
        
        // Canvas
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              color: Colors.white,
              child: CustomPaint(
                painter: _WhiteboardPainter(
                  strokes: _strokes,
                  currentPoints: _currentPoints,
                  currentColor: _isEraser ? Colors.white : _currentColor,
                  currentStrokeWidth: _isEraser ? _currentStrokeWidth * 3 : _currentStrokeWidth,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[200],
      child: Row(
        children: [
          // Color picker
          _buildColorButton(Colors.black),
          _buildColorButton(Colors.red),
          _buildColorButton(Colors.blue),
          _buildColorButton(Colors.green),
          _buildColorButton(Colors.orange),
          _buildColorButton(Colors.purple),
          
          const SizedBox(width: 16),
          
          // Stroke width
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              setState(() {
                _currentStrokeWidth = max(1, _currentStrokeWidth - 1);
              });
            },
            tooltip: 'Thinner',
          ),
          Text('${_currentStrokeWidth.toInt()}'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _currentStrokeWidth = min(20, _currentStrokeWidth + 1);
              });
            },
            tooltip: 'Thicker',
          ),
          
          const SizedBox(width: 16),
          
          // Eraser toggle
          IconButton(
            icon: Icon(
              Icons.auto_fix_high,
              color: _isEraser ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isEraser = !_isEraser;
              });
            },
            tooltip: 'Eraser',
          ),
          
          const Spacer(),
          
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _clearBoard,
            tooltip: 'Clear All',
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _currentColor == color && !_isEraser;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentColor = color;
          _isEraser = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;

  _WhiteboardPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      
      canvas.drawPath(path, paint);
    }

    // Draw current stroke being drawn
    if (currentPoints.length >= 2) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      
      for (int i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentPoints != oldDelegate.currentPoints ||
        currentColor != oldDelegate.currentColor ||
        currentStrokeWidth != oldDelegate.currentStrokeWidth;
  }
}

/// Platform-aware whiteboard that uses Fastboard on native and WebWhiteboard on web
class PlatformWhiteboard extends StatelessWidget {
  final String meetingId;
  final String oderId;
  final bool readOnly;

  const PlatformWhiteboard({
    super.key,
    required this.meetingId,
    required this.oderId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // On web, always use WebWhiteboard
    if (kIsWeb) {
      return WebWhiteboard(
        meetingId: meetingId,
        oderId: oderId,
        readOnly: readOnly,
      );
    }
    
    // On native, you would use Fastboard here
    // For now, use WebWhiteboard as fallback on all platforms
    // TODO: Integrate fastboard_flutter for native when available
    return WebWhiteboard(
      meetingId: meetingId,
      oderId: oderId,
      readOnly: readOnly,
    );
  }
}
