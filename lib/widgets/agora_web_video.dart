// Web Video Widget for Agora Live Streaming
// Uses HtmlElementView to display video from Agora Web SDK

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Conditional imports for web platform
import 'agora_web_video_stub.dart'
    if (dart.library.html) 'agora_web_video_web.dart' as platform;

/// Widget to display Agora video on web platform
/// Falls back to placeholder on non-web platforms
class AgoraWebVideoView extends StatefulWidget {
  final String containerId;
  final bool isLocalVideo;
  final int? remoteUid;
  final VoidCallback? onReady;

  const AgoraWebVideoView({
    super.key,
    required this.containerId,
    this.isLocalVideo = true,
    this.remoteUid,
    this.onReady,
  });

  @override
  State<AgoraWebVideoView> createState() => _AgoraWebVideoViewState();
}

class _AgoraWebVideoViewState extends State<AgoraWebVideoView> {
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerView();
    }
  }

  void _registerView() {
    if (!_isRegistered) {
      platform.registerVideoView(widget.containerId);
      _isRegistered = true;
      
      // Notify when ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onReady?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Non-web platforms should use native AgoraVideoView
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Use native AgoraVideoView',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return platform.buildVideoView(widget.containerId);
  }
}
