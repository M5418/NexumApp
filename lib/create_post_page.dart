import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/media_thumb.dart';
import 'widgets/tag_chip.dart';
import 'dart:io';
import 'core/files_api.dart';
import 'core/posts_api.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<String> _selectedCommunities = [];
  final List<MediaItem> _mediaItems = [];
  final List<String> _taggedUsers = [];
  final int _maxCommunities = 3;

  bool _posting = false;

  bool get _canPost =>
      (!_posting) &&
      (_titleController.text.trim().isNotEmpty ||
          _bodyController.text.trim().isNotEmpty ||
          _mediaItems.isNotEmpty);

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildPostCard(isDark),
              ),
            ),

            // Bottom action bar
            _buildBottomActionBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back,
            size: 40,
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Create Post',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildPostCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          _buildTitleField(isDark),
          const SizedBox(height: 16),

          // Body field
          _buildBodyField(isDark),
          const SizedBox(height: 16),

          // Toolbar
          _buildToolbar(isDark),

          // Selected communities chips
          if (_selectedCommunities.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCommunityChips(),
          ],

          // Media previews
          if (_mediaItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMediaPreviews(),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleField(bool isDark) {
    return TextField(
      controller: _titleController,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        hintText: 'Title',
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF666666),
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      maxLines: 1,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBodyField(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _bodyController,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: "What's on your mind today?",
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF666666),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          minLines: 6,
          maxLines: null,
          onChanged: (value) => setState(() {}),
        ),

        // Tagged users display
        if (_taggedUsers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taggedUsers.map((user) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFAE01).withValues(alpha: 26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBFAE01),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 14,
                        color: Color(0xFFBFAE01),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFBFAE01),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _taggedUsers.remove(user);
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFFBFAE01),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Row(
      children: [
        // Left group - media buttons
        CircleIconButton(
          icon: Icons.tag,
          size: 36,
          onTap: () {
            _showUserTagPicker();
          },
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.camera_alt_outlined,
          size: 36,
          onTap: () {
            _showGalleryPicker();
          },
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.photo_outlined,
          size: 36,
          onTap: () {
            _showGalleryPicker();
          },
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.videocam_outlined,
          size: 36,
          onTap: () {
            _showGalleryPicker();
          },
        ),

        const Spacer(),

        // Right - Community selector
        GestureDetector(
          onTap: () {
            _showCommunitySelector();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Community',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Color(0xFF666666),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedCommunities.map((community) {
        return TagChip(
          label: community,
          onRemove: () {
            setState(() {
              _selectedCommunities.remove(community);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildMediaPreviews() {
    if (_mediaItems.length == 1 && _mediaItems.first.type == MediaType.image) {
      // Single image - wide layout
      return MediaThumb(
        type: MediaType.image,
        imageUrl: _mediaItems.first.imageUrl,
        width: double.infinity,
        height: 200,
        borderRadius: 25,
        onRemove: () {
          setState(() {
            _mediaItems.clear();
          });
        },
      );
    } else if (_mediaItems.length == 1 &&
        _mediaItems.first.type == MediaType.video) {
      // Single video - wide layout
      return MediaThumb(
        type: MediaType.video,
        videoThumbnailUrl: _mediaItems.first.thumbnailUrl,
        width: double.infinity,
        height: 200,
        borderRadius: 25,
        onRemove: () {
          setState(() {
            _mediaItems.clear();
          });
        },
      );
    }

    // Images or multiple items - horizontal scroll
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _mediaItems[index];
          return MediaThumb(
            type: item.type,
            imageUrl: item.imageUrl,
            videoThumbnailUrl: item.thumbnailUrl,
            onRemove: () {
              setState(() {
                _mediaItems.removeAt(index);
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Save as Draft button
          Expanded(
            child: GestureDetector(
              onTap: () {
                _saveDraft();
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Center(
                  child: Text(
                    'Save as Draft',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Post button
          Expanded(
            child: GestureDetector(
              onTap: _canPost
                  ? () {
                      _publishPost();
                    }
                  : null,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: _canPost
                      ? const Color(0xFF0C0C0C)
                      : const Color(0xFF0C0C0C).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Center(
                  child: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Post',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _canPost
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final users = ['John Doe', 'Jane Doe', 'Bob Smith'];

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Users',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...users.map((user) {
                final isSelected = _taggedUsers.contains(user);

                return ListTile(
                  title: Text(
                    user,
                    style: GoogleFonts.inter(
                      color: isSelected ? null : Colors.grey,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFFBFAE01))
                      : null,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _taggedUsers.remove(user);
                      } else {
                        _taggedUsers.add(user);
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showGalleryPicker() async {
    // Try different permission strategies based on Android version
    PermissionStatus permissionStatus;

    // Check Android version and request appropriate permission
    try {
      // Try photos permission first (Android 13+)
      permissionStatus = await Permission.photos.request();
    } catch (e) {
      // Fallback to storage permission for older versions
      permissionStatus = await Permission.storage.request();
    }

    if (permissionStatus.isGranted) {
      try {
        final ImagePicker picker = ImagePicker();

        final List<XFile> images = await picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1080,
        );

        if (images.isNotEmpty) {
          setState(() {
            for (final image in images) {
              _mediaItems.add(
                MediaItem(type: MediaType.image, imageUrl: image.path),
              );
            }
          });
        }
      } on PlatformException catch (e) {
        if (!mounted) return;

        if (e.code == 'photo_access_denied') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo access denied. Please enable gallery permissions in settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error accessing gallery. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected error occurred.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (permissionStatus.isDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gallery permission denied. Please allow access to select photos.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else if (permissionStatus.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Gallery access permanently denied. Please enable in device settings.',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  void _showCommunitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0C0C0C)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final communities = [
          {
            'name': 'Bicycle Tribe',
            'description':
                'Join passionate cyclists sharing rides, tips, and adventures',
            'icon': '🚴‍♂️',
            'memberCount': '+1K',
            'color': const Color(0xFF8B4513),
          },
          {
            'name': 'Mountain Hikers',
            'description':
                'Explore trails, share hiking experiences and connect with nature',
            'icon': '🏔️',
            'memberCount': '+1K',
            'color': const Color(0xFF2E7D32),
          },
          {
            'name': 'Pet Pals',
            'description':
                'A friendly group for pet lovers to share stories and advice',
            'icon': '🐾',
            'memberCount': '+1K',
            'color': const Color(0xFF4CAF50),
          },
          {
            'name': 'Technology',
            'description': 'Latest tech trends, innovations, and discussions',
            'icon': '💻',
            'memberCount': '+2K',
            'color': const Color(0xFF2196F3),
          },
          {
            'name': 'Business',
            'description':
                'Business strategies, networking, and growth insights',
            'icon': '💼',
            'memberCount': '+3K',
            'color': const Color(0xFF9C27B0),
          },
          {
            'name': 'Finance',
            'description':
                'Investment tips, market analysis, and financial planning',
            'icon': '💰',
            'memberCount': '+1.5K',
            'color': const Color(0xFF4CAF50),
          },
        ];

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Choose Community',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: const Color(0xFF666666),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search community...',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Communities list
              Expanded(
                child: ListView.separated(
                  itemCount: communities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final community = communities[index];
                    final isSelected = _selectedCommunities.contains(
                      community['name'],
                    );
                    final canSelect =
                        _selectedCommunities.length < _maxCommunities ||
                        isSelected;

                    return GestureDetector(
                      onTap: canSelect
                          ? () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCommunities.remove(
                                    community['name'],
                                  );
                                } else {
                                  _selectedCommunities.add(
                                    community['name'] as String,
                                  );
                                }
                              });
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFFBFAE01),
                                  width: 2,
                                )
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: Row(
                          children: [
                            // Community icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (community['color'] as Color).withValues(
                                  alpha: 51,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  community['icon'] as String,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Community info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    community['name'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: canSelect
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black)
                                          : const Color(0xFF999999),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    community['description'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: canSelect
                                          ? const Color(0xFF666666)
                                          : const Color(0xFF999999),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Member count and selection indicator
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Member avatars (placeholder)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(3, (i) {
                                    return Container(
                                      margin: EdgeInsets.only(
                                        left: i > 0 ? 4 : 0,
                                      ),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: community['color'] as Color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF1A1A1A)
                                              : const Color(0xFFF8F9FA),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  community['memberCount'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),

                            if (isSelected) ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFBFAE01),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Continue button
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Center(
                      child: Text(
                        'Continue',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to drafts', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFBFAE01),
      ),
    );
  }

  Future<void> _publishPost() async {
    setState(() => _posting = true);
    try {
      // Upload local image files (if any) and collect media descriptors
      final mediaPayload = <Map<String, dynamic>>[];
      for (final item in _mediaItems) {
        if (item.type == MediaType.image && item.imageUrl != null) {
          final f = File(item.imageUrl!);
          if (await f.exists()) {
            final uploaded = await FilesApi().uploadFile(f);
            mediaPayload.add({
              'media_type': 'image',
              's3_key': uploaded['key'],
              'url': uploaded['url'],
            });
          }
        }
        // Note: video flow can be added similarly when implemented
      }

      final content = [
        _titleController.text.trim(),
        _bodyController.text.trim(),
      ].where((e) => e.isNotEmpty).join('\n\n');

      await PostsApi().create(
        content: content,
        media: mediaPayload.isEmpty ? null : mediaPayload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Posted', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish post', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

class MediaItem {
  final MediaType type;
  final String? imageUrl;
  final String? thumbnailUrl;

  MediaItem({required this.type, this.imageUrl, this.thumbnailUrl});
}
