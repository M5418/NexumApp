import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:video_compress/video_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/media_thumb.dart';
import 'core/i18n/language_provider.dart';
import 'core/files_api.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'services/media_compression_service.dart';
import 'core/profile_api.dart';

/// Create post page specifically for communities - no community selector needed
class CommunityCreatePostPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  
  const CommunityCreatePostPage({
    super.key,
    required this.communityId,
    required this.communityName,
  });
  
  static Future<T?> showPopup<T>(BuildContext context, {
    required String communityId,
    required String communityName,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: Provider.of<LanguageProvider>(context, listen: false).t('create_post.create_post'),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CommunityCreatePostPage(
                  communityId: communityId,
                  communityName: communityName,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CommunityCreatePostPage> createState() => _CommunityCreatePostPageState();
}

class _CommunityCreatePostPageState extends State<CommunityCreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<MediaItem> _mediaItems = [];
  final List<String> _taggedUsers = [];

  bool _posting = false;

  final FirebasePostRepository _postRepo = FirebasePostRepository();

  bool get _canPost => (!_posting) && _bodyController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0C0C0C) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t('create_post.create_post'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              widget.communityName,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFBFAE01),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _canPost ? _publishPost : null,
              style: TextButton.styleFrom(
                backgroundColor: _canPost
                    ? const Color(0xFFBFAE01)
                    : (isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                foregroundColor: _canPost ? Colors.black : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      lang.t('create_post.post_button'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Community badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group, size: 16, color: Color(0xFFBFAE01)),
                  const SizedBox(width: 6),
                  Text(
                    widget.communityName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFBFAE01),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title field (optional)
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: lang.t('create_post.title_hint'),
                hintStyle: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF666666),
                ),
                border: InputBorder.none,
              ),
              maxLines: 1,
            ),

            // Body field (required)
            TextField(
              controller: _bodyController,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: lang.t('create_post.body_hint'),
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF666666),
                ),
                border: InputBorder.none,
              ),
              maxLines: null,
              minLines: 5,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Toolbar
            _buildToolbar(isDark),

            // Media previews
            if (_mediaItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildMediaPreviews(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Image picker
          CircleIconButton(
            icon: Icons.image_outlined,
            size: 40,
            onTap: _pickImage,
          ),
          const SizedBox(width: 8),

          // Video picker
          CircleIconButton(
            icon: Icons.videocam_outlined,
            size: 40,
            onTap: _pickVideo,
          ),
          const SizedBox(width: 8),

          // Tag users
          CircleIconButton(
            icon: Icons.person_add_outlined,
            size: 40,
            onTap: _showTagUserSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewWidget(MediaItem item) {
    if (item.xfile != null) {
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: item.xfile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              );
            }
            return Container(
              width: 100,
              height: 100,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      } else {
        return Image.file(
          File(item.xfile!.path),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        );
      }
    }
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildMediaPreviews() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _mediaItems[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMediaPreviewWidget(item),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _mediaItems.removeAt(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
              if (item.type == MediaType.video)
                const Positioned.fill(
                  child: Center(
                    child: Icon(Icons.play_circle_outline, size: 32, color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      setState(() {
        for (final xfile in picked) {
          _mediaItems.add(MediaItem(
            type: MediaType.image,
            path: kIsWeb ? null : xfile.path,
            xfile: xfile,
          ));
        }
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _mediaItems.add(MediaItem(
          type: MediaType.video,
          path: kIsWeb ? null : picked.path,
          xfile: picked,
        ));
      });
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  void _showTagUserSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String query = '';
        List<_TagUser> results = [];
        bool loading = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> search(String q) async {
              if (q.trim().isEmpty) {
                setSheetState(() {
                  results = [];
                  loading = false;
                });
                return;
              }

              setSheetState(() => loading = true);

              try {
                final userRepo = FirebaseUserRepository();
                final users = await userRepo.searchUsers(query: q.trim());
                final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;

                setSheetState(() {
                  results = users
                      .where((u) => u.uid != currentUid)
                      .map((u) {
                        final name = '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
                        return _TagUser(
                          id: u.uid,
                          name: name.isNotEmpty ? name : (u.username ?? 'User'),
                          username: u.username != null ? '@${u.username}' : '',
                          avatarUrl: u.avatarUrl,
                          avatarLetter: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        );
                      })
                      .toList();
                  loading = false;
                });
              } catch (e) {
                setSheetState(() {
                  results = [];
                  loading = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 500),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF666666).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      lang.t('create_post.tag_users'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search field
                    TextField(
                      autofocus: true,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: lang.t('create_post.search_users'),
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        query = v;
                        search(v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Results
                    Expanded(
                      child: loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                              ),
                            )
                          : results.isEmpty
                              ? Center(
                                  child: Text(
                                    query.isEmpty
                                        ? lang.t('create_post.type_to_search')
                                        : lang.t('create_post.no_users_found'),
                                    style: GoogleFonts.inter(color: const Color(0xFF666666)),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    final user = results[index];
                                    final isTagged = _taggedUsers.contains(user.id);

                                    return ListTile(
                                      leading: _Avatar(
                                        avatarUrl: user.avatarUrl,
                                        letter: user.avatarLetter,
                                      ),
                                      title: Text(
                                        user.name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        user.username,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                      trailing: isTagged
                                          ? const Icon(Icons.check_circle, color: Color(0xFFBFAE01))
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          if (isTagged) {
                                            _taggedUsers.remove(user.id);
                                          } else {
                                            _taggedUsers.add(user.id);
                                          }
                                        });
                                        setSheetState(() {});
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _publishPost() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('create_post.empty_post'),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      final content = [
        _titleController.text.trim(),
        body,
      ].where((e) => e.isNotEmpty).join('\n\n');

      final hasMedia = _mediaItems.isNotEmpty;
      
      List<String> mediaUrls = [];
      List<String> thumbUrls = [];
      
      if (hasMedia) {
        debugPrint('🖼️ Uploading thumbnails first for instant display...');
        final compressionService = MediaCompressionService();
        final profileApi = ProfileApi();
        
        final thumbFutures = _mediaItems.map((item) async {
          try {
            if (item.xfile != null) {
              final bytes = await item.xfile!.readAsBytes();
              final thumb = await compressionService.generateFeedThumbnailFromBytes(
                bytes: bytes,
                filename: item.xfile!.name,
                maxSize: 400,
                quality: 60,
              );
              if (thumb != null) {
                final thumbUrl = await profileApi.uploadBytes(thumb, ext: 'jpg');
                return thumbUrl;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Thumbnail generation failed: $e');
          }
          return '';
        }).toList();
        
        thumbUrls = await Future.wait(thumbFutures);
        mediaUrls = thumbUrls.where((u) => u.isNotEmpty).toList();
        debugPrint('✅ Thumbnails uploaded: ${mediaUrls.length}');
      }
      
      debugPrint('🚀 Creating post to community ${widget.communityId}');
      final postId = await _postRepo.createPost(
        text: content, 
        mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
        thumbUrls: thumbUrls.isNotEmpty ? thumbUrls : null,
        communityId: widget.communityId,
      );
      debugPrint('✅ Post created with ID: $postId');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('create_post.posted'),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );
      
      Navigator.pop(context, true);

      if (hasMedia) {
        debugPrint('💾 Starting background upload for full-resolution media');
        _uploadMediaInBackground(postId, content, _mediaItems);
      }

    } catch (e, stackTrace) {
      debugPrint('❌ Error creating post: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${Provider.of<LanguageProvider>(context, listen: false).t('create_post.publish_failed')}: $e',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _uploadMediaInBackground(String postId, String text, List<MediaItem> items) async {
    try {
      debugPrint('💾 Starting parallel upload of ${items.length} media items');
      
      final uploadFutures = items.asMap().entries.map((entry) async {
        final i = entry.key;
        final item = entry.value;
        final xf = item.xfile;
        final path = item.path;
        
        if (xf == null && (path == null || path.isEmpty)) return <String, String>{};

        if (xf != null) {
          debugPrint('💾 Uploading media ${i + 1}/${items.length}');
          final uploaded = await _uploadXFile(xf, item.type);
          debugPrint('✅ Media ${i + 1} uploaded: ${uploaded['url']}');
          return uploaded;
        } else if (path != null && path.startsWith('http')) {
          return {'url': path, 'thumbUrl': path};
        }

        return <String, String>{};
      }).toList();
      
      final results = await Future.wait(uploadFutures);
      final mediaUrls = results.map((r) => r['url'] ?? '').where((u) => u.isNotEmpty).toList();
      final thumbUrls = results.map((r) => r['thumbUrl'] ?? r['url'] ?? '').where((u) => u.isNotEmpty).toList();

      if (mediaUrls.isEmpty) {
        debugPrint('⚠️ No media URLs to update');
        return;
      }

      debugPrint('🔄 Updating post with ${mediaUrls.length} real URLs + ${thumbUrls.length} thumbs');
      await _postRepo.updatePost(
        postId: postId,
        text: text,
        mediaUrls: mediaUrls,
        thumbUrls: thumbUrls,
      );
      debugPrint('✅ Post updated successfully with real media + thumbnails');
    } catch (e) {
      debugPrint('❌ Background upload failed: $e');
    }
  }

  Future<Map<String, String>> _uploadXFile(XFile file, MediaType type) async {
    final ext = _extensionOf(file.name);
    final compressionService = MediaCompressionService();
    
    try {
      if (type == MediaType.image) {
        debugPrint('🖼️ Compressing image before upload: ${file.name}');
        
        final originalBytes = await file.readAsBytes();
        
        final thumbFuture = compressionService.generateFeedThumbnailFromBytes(
          bytes: originalBytes,
          filename: file.name,
          maxSize: 400,
          quality: 60,
        );
        
        final compressedBytes = kIsWeb
            ? await compressionService.compressImageBytes(
                bytes: originalBytes,
                filename: file.name,
                quality: 92,
                minWidth: 1920,
                minHeight: 1920,
              )
            : await compressionService.compressImage(
                filePath: file.path,
                quality: 92,
                minWidth: 1920,
                minHeight: 1920,
              );
        
        final thumbBytes = await thumbFuture;
        
        if (compressedBytes == null) {
          debugPrint('⚠️ Compression failed, using original image');
          final res = await FilesApi().uploadBytes(originalBytes, ext: ext);
          final url = res['url'] ?? '';
          String thumbUrl = url;
          if (thumbBytes != null) {
            final thumbRes = await FilesApi().uploadBytes(thumbBytes, ext: ext);
            thumbUrl = thumbRes['url'] ?? url;
          }
          return {'url': url, 'thumbUrl': thumbUrl};
        }
        
        final fullUpload = FilesApi().uploadBytes(compressedBytes, ext: ext);
        final thumbUpload = thumbBytes != null 
            ? FilesApi().uploadBytes(thumbBytes, ext: ext)
            : Future.value(<String, dynamic>{'url': ''});
        
        final results = await Future.wait([fullUpload, thumbUpload]);
        final fullUrl = results[0]['url'] ?? '';
        final thumbUrl = results[1]['url'] ?? fullUrl;
        
        debugPrint('✅ Uploaded: full=${(compressedBytes.length / 1024).toStringAsFixed(0)}KB, thumb=${thumbBytes != null ? (thumbBytes.length / 1024).toStringAsFixed(0) : 0}KB');
        return {'url': fullUrl, 'thumbUrl': thumbUrl};
      } else if (type == MediaType.video && !kIsWeb) {
        debugPrint('🎥 Processing video for upload: ${file.name}');
        
        // Generate video thumbnail for feed (fast, low quality for feed)
        File? thumbFile;
        try {
          thumbFile = await VideoCompress.getFileThumbnail(
            file.path,
            quality: 30, // Lower quality for faster generation
            position: -1,
          );
        } catch (_) {
          debugPrint('⚠️ Thumbnail generation failed');
        }
        
        // Check file size first to decide compression strategy
        final originalFile = File(file.path);
        final originalSize = await originalFile.length();
        debugPrint('📊 Original video size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        File? fileToUpload;
        String? compressionInfo;
        
        // Skip compression for small videos (< 20MB) to save time
        if (originalSize < 20 * 1024 * 1024) {
          debugPrint('⏭️ Video is small (<20MB), uploading without compression');
          fileToUpload = originalFile;
          compressionInfo = 'original';
        } else {
          debugPrint('🗜️ Compressing large video...');
          // Use faster compression settings
          final compressedFile = await compressionService.compressVideo(
            filePath: file.path,
            quality: VideoQuality.MediumQuality, // Faster than HighestQuality
          );
          
          if (compressedFile != null) {
            final compressedSize = await compressedFile.length();
            final reduction = ((originalSize - compressedSize) / originalSize * 100);
            debugPrint('✅ Compressed to ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB (${reduction.toStringAsFixed(1)}% reduction)');
            fileToUpload = compressedFile;
            compressionInfo = 'compressed';
          } else {
            debugPrint('⚠️ Compression failed, using original');
            fileToUpload = originalFile;
            compressionInfo = 'original';
          }
        }
        
        // Upload video and thumbnail in parallel
        debugPrint('📤 Uploading video ($compressionInfo)...');
        final videoBytes = await fileToUpload.readAsBytes();
        
        // Start uploads in parallel
        final futures = <Future<Map<String, String>>>[];
        
        // Video upload
        futures.add(FilesApi().uploadBytes(videoBytes, ext: ext));
        
        // Thumbnail upload (if available)
        if (thumbFile != null) {
          futures.add(thumbFile.readAsBytes().then((bytes) => 
            FilesApi().uploadBytes(bytes, ext: 'jpg')));
        } else {
          futures.add(Future.value({'url': ''}));
        }
        
        // Wait for both uploads
        final results = await Future.wait(futures);
        final videoUrl = results[0]['url'] ?? '';
        final thumbUrl = results[1]['url'] ?? videoUrl;
        
        debugPrint('✅ Video uploaded successfully');
        
        // Clean up compressed file if different from original
        if (compressionInfo == 'compressed' && fileToUpload != originalFile) {
          try {
            await fileToUpload.delete();
            debugPrint('🧹 Cleaned up compressed file');
          } catch (_) {
            // Ignore cleanup errors
          }
        }
        
        return {'url': videoUrl, 'thumbUrl': thumbUrl};
      } else {
        // Web video - upload original (no compression available)
        debugPrint('📤 Web: Uploading video without compression: ${file.name}');
        final bytes = await file.readAsBytes();
        final res = await FilesApi().uploadBytes(bytes, ext: ext);
        return {'url': res['url'] ?? '', 'thumbUrl': res['url'] ?? ''};
      }
    } catch (e) {
      debugPrint('❌ Error during compression/upload: $e');
      final bytes = await file.readAsBytes();
      final res = await FilesApi().uploadBytes(bytes, ext: ext);
      return {'url': res['url'] ?? '', 'thumbUrl': res['url'] ?? ''};
    }
  }

  String _extensionOf(String filename) {
    final idx = filename.lastIndexOf('.');
    if (idx == -1 || idx == filename.length - 1) return 'bin';
    return filename.substring(idx + 1).toLowerCase();
  }
}

class MediaItem {
  final MediaType type;
  final String? path;
  final String? thumbnailUrl;
  final XFile? xfile;

  MediaItem({
    required this.type,
    this.path,
    this.thumbnailUrl,
    this.xfile,
  });
}

class _TagUser {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String avatarLetter;

  _TagUser({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.avatarLetter,
  });
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String letter;
  const _Avatar({required this.avatarUrl, required this.letter});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Colors.transparent,
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE0E0E0),
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
