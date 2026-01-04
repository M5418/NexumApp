import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class ChatImageEditorPage extends StatefulWidget {
  final Function(List<Uint8List>) onSendImages;

  const ChatImageEditorPage({super.key, required this.onSendImages});

  @override
  State<ChatImageEditorPage> createState() => _ChatImageEditorPageState();
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

class _ChatImageEditorPageState extends State<ChatImageEditorPage> {
  final ImagePicker _picker = ImagePicker();
  List<MediaItem> _mediaItems = [];
  int _currentIndex = 0;
  final TextEditingController _captionController = TextEditingController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pickMedia();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    for (final item in _mediaItems) {
      item.videoController?.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    // Pick multiple images
    final images = await _picker.pickMultiImage();

    // Pick multiple videos
    final videos = <XFile>[];
    while (true) {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (video == null) break;
      videos.add(video);

      // Ask if user wants to add more videos
      if (!mounted) break;
      final addMore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add More Videos?', style: GoogleFonts.inter()),
          content: Text(
            'Would you like to add another video?',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Done', style: GoogleFonts.inter()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add More', style: GoogleFonts.inter()),
            ),
          ],
        ),
      );
      if (addMore != true) break;
    }

    if (images.isEmpty && videos.isEmpty) {
      // If no media selected, go back
      if (mounted) Navigator.pop(context);
      return;
    }

    // Combine images and videos into MediaItem list
    final List<MediaItem> newItems = [];

    // Add images
    for (final image in images) {
      newItems.add(MediaItem(file: image, isVideo: false));
    }

    // Add videos with controllers
    for (final video in videos) {
      final controller = VideoPlayerController.file(File(video.path));
      await controller.initialize();
      await controller.setLooping(true);
      newItems.add(
        MediaItem(file: video, isVideo: true, videoController: controller),
      );
    }

    setState(() {
      _mediaItems = newItems;
      _currentIndex = 0;
    });

    // Auto-play first video if it exists
    if (newItems.isNotEmpty && newItems[0].isVideo) {
      newItems[0].videoController?.play();
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
        settings: const RouteSettings(name: 'image_editor'),
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

  void _sendImages() async {
    List<Uint8List> imagesToSend = [];

    for (final item in _mediaItems) {
      if (!item.isVideo) {
        if (item.editedImageBytes != null) {
          imagesToSend.add(item.editedImageBytes!);
        } else {
          final bytes = await File(item.file.path).readAsBytes();
          imagesToSend.add(bytes);
        }
      }
    }

    if (mounted) {
      widget.onSendImages(imagesToSend);
      Navigator.pop(context);
    }
  }

  void _removeCurrentMedia() {
    if (_mediaItems.length <= 1) {
      Navigator.pop(context);
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

  Widget _buildVideoPlayer(MediaItem item) {
    if (item.videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF007AFF)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageCount = _mediaItems.where((item) => !item.isVideo).length;
    final videoCount = _mediaItems.where((item) => item.isVideo).length;

    String titleText = '';
    if (imageCount > 0 && videoCount > 0) {
      titleText = 'Send $imageCount Image(s) & $videoCount Video(s)';
    } else if (imageCount > 0) {
      titleText = imageCount > 1 ? 'Send $imageCount Images' : 'Send Image';
    } else if (videoCount > 0) {
      titleText = videoCount > 1 ? 'Send $videoCount Videos' : 'Send Video';
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          titleText,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: imageCount > 0 ? _sendImages : null,
            child: Text(
              'Send',
              style: GoogleFonts.inter(
                color: imageCount > 0 ? const Color(0xFF007AFF) : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _mediaItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currentIndex + 1} of ${_mediaItems.length}',
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black,
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
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              onPressed: _currentIndex < _mediaItems.length - 1
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
                                color: _currentIndex < _mediaItems.length - 1
                                    ? (isDark ? Colors.white : Colors.black)
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
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 26)
                            : Colors.black.withValues(alpha: 26),
                      ),
                    ),
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _mediaItems.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final item = _mediaItems[index];
                            return Container(
                              margin: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.isVideo
                                    ? _buildVideoPlayer(item)
                                    : _buildImageViewer(item),
                              ),
                            );
                          },
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
                              color: Colors.black.withValues(alpha: 153),
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
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentIndex
                                ? const Color(0xFF007AFF)
                                : Colors.grey.withValues(alpha: 77),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Edit button - only show for images
                if (!_mediaItems[_currentIndex].isVideo)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _editCurrentImage,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: Text(
                          _mediaItems[_currentIndex].editedImageBytes != null
                              ? 'Edit Again'
                              : 'Edit Image',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Caption input
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
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
                      hintText: 'Add a caption...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 3,
                    minLines: 1,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom actions
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Pick different media
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickMedia,
                          icon: Icon(
                            Icons.perm_media,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          label: Text(
                            'Choose Different',
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 77)
                                  : Colors.black.withValues(alpha: 77),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Remove current media
                      if (_mediaItems.length > 1)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _removeCurrentMedia,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            label: Text(
                              'Remove',
                              style: GoogleFonts.inter(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.red),
                            ),
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
