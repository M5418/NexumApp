import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class StoryMediaViewer extends StatelessWidget {
  final bool isVideo;
  final VideoPlayerController? videoController;
  final File? imageFile;
  final Uint8List? editedImageBytes;
  final String? fileName;

  const StoryMediaViewer({
    super.key,
    required this.isVideo,
    this.videoController,
    this.imageFile,
    this.editedImageBytes,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: isVideo ? _buildVideo() : _buildImage(),
    );
  }

  Widget _buildVideo() {
    final vc = videoController;
    if (vc == null || !vc.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
      );
    }
    return Stack(
      children: [
        AspectRatio(
          aspectRatio:
              vc.value.aspectRatio == 0 ? 9 / 16 : vc.value.aspectRatio,
          child: VideoPlayer(vc),
        ),
        if (fileName != null)
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
                fileName!,
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

  Widget _buildImage() {
    if (editedImageBytes != null) {
      return Image.memory(editedImageBytes!, fit: BoxFit.contain);
    }
    if (imageFile != null) {
      return Image.file(imageFile!, fit: BoxFit.contain);
    }
    return const SizedBox.shrink();
  }
}
