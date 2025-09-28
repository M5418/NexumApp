import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/media_thumb.dart';
import 'widgets/tag_chip.dart';
import 'package:dio/dio.dart';
import 'core/api_client.dart';
import 'core/posts_api.dart';
import 'core/communities_api.dart';
import 'core/community_posts_api.dart';
import 'core/connections_api.dart';
import 'core/users_api.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<ApiCommunity> _selectedCommunities = [];
  final List<MediaItem> _mediaItems = [];
  final List<String> _taggedUsers = [];
  final int _maxCommunities = 3;

  bool _posting = false;

  // Body is REQUIRED, title optional. Media can be attached but not sufficient without body.
  bool get _canPost => (!_posting) && _bodyController.text.trim().isNotEmpty;

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
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
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
          // Title field (optional)
          _buildTitleField(isDark),
          const SizedBox(height: 16),

          // Body field (required)
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
        // Left group - actions
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
            // For web, opening camera is limited; reuse gallery picker for reliability.
            _pickImagesFromGallery();
          },
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.photo_outlined,
          size: 36,
          onTap: () {
            _pickImagesFromGallery();
          },
        ),
        const SizedBox(width: 12),
        CircleIconButton(
          icon: Icons.videocam_outlined,
          size: 36,
          onTap: () {
            _pickVideoFromGallery();
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
          label: community.name,
          onRemove: () {
            setState(() {
              _selectedCommunities.removeWhere((c) => c.id == community.id);
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
        imageUrl: _mediaItems.first.path,
        width: double.infinity,
        height: 200,
        borderRadius: 25,
        onRemove: () {
          setState(() {
            _mediaItems.clear();
          });
        },
      );
    } else if (_mediaItems.length == 1 && _mediaItems.first.type == MediaType.video) {
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
            imageUrl: item.path,
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return FutureBuilder<List<_TagUser>>(
          future: _fetchConnectionUsers(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load connections',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              );
            }
            final users = snap.data ?? [];
            return StatefulBuilder(
              builder: (context, setSheetState) {
                String query = '';
                final Set<String> localSelected = {..._taggedUsers};

                List<_TagUser> filtered = users;
                void applyQuery(String q) {
                  setSheetState(() {
                    query = q.trim().toLowerCase();
                  });
                }

                filtered = users.where((u) {
                  if (query.isEmpty) return true;
                  return u.name.toLowerCase().contains(query) ||
                      u.username.toLowerCase().contains(query);
                }).toList();

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
                            'Tag People',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          if (localSelected.isNotEmpty)
                            Text(
                              '${localSelected.length} selected',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF666666), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                onChanged: applyQuery,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Search connections...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  border: InputBorder.none,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Users list
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No connections found',
                                  style: GoogleFonts.inter(color: const Color(0xFF666666)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final u = filtered[index];
                                  final label = u.username.isNotEmpty ? u.username : u.name;
                                  final selected = localSelected.contains(label);
                                  return ListTile(
                                    leading: _Avatar(avatarUrl: u.avatarUrl, letter: u.avatarLetter),
                                    title: Text(
                                      u.name,
                                      style: GoogleFonts.inter(),
                                    ),
                                    subtitle: Text(
                                      u.username,
                                      style: GoogleFonts.inter(color: const Color(0xFF666666)),
                                    ),
                                    trailing: selected
                                        ? const Icon(Icons.check_circle, color: Color(0xFFBFAE01))
                                        : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCCCCCC)),
                                    onTap: () {
                                      setSheetState(() {
                                        if (selected) {
                                          localSelected.remove(label);
                                        } else {
                                          localSelected.add(label);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),

                      // Done button
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _taggedUsers
                                ..clear()
                                ..addAll(localSelected);
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0C0C),
                              borderRadius: BorderRadius.circular(27),
                            ),
                            child: Center(
                              child: Text(
                                'Done',
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
          },
        );
      },
    );
  }

  Future<List<_TagUser>> _fetchConnectionUsers() async {
    try {
      final status = await ConnectionsApi().status();
      final ids = <String>{...status.inbound, ...status.outbound};
      if (ids.isEmpty) return [];

      final all = await UsersApi().list(); // all users except current
      final filtered = all.where((u) => ids.contains((u['id'] ?? '').toString()));

      final List<_TagUser> users = filtered.map((u) {
        final name = (u['name'] ?? '').toString();
        final username = (u['username'] ?? '').toString();
        final avatarUrl = u['avatarUrl']?.toString();
        final email = (u['email'] ?? '').toString();
        final letterSource = name.isNotEmpty ? name : (username.isNotEmpty ? username : email);
        final letter = letterSource.isNotEmpty ? letterSource[0].toUpperCase() : 'U';
        return _TagUser(
          id: (u['id'] ?? '').toString(),
          name: name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@')[0] : 'User'),
          username: username.isNotEmpty ? username : '@user',
          avatarUrl: avatarUrl,
          avatarLetter: letter,
        );
      }).toList();

      users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return users;
    } catch (_) {
      return [];
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();

      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (!mounted) return;

      if (images.isNotEmpty) {
        setState(() {
          // If a video was selected before, replace it with images
          if (_mediaItems.any((m) => m.type == MediaType.video)) {
            _mediaItems.clear();
          }
          for (final image in images) {
            _mediaItems.add(
              MediaItem(type: MediaType.image, path: image.path, xfile: image),
            );
          }
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'photo_access_denied'
                ? 'Photo access denied. Please enable gallery permissions in settings.'
                : 'Error accessing gallery. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unexpected error occurred.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final picker = ImagePicker();

      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (!mounted) return;

      if (video != null) {
        setState(() {
          // Only one video allowed, replace any existing media
          _mediaItems
            ..clear()
            ..add(MediaItem(type: MediaType.video, path: video.path, xfile: video));
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'photo_access_denied'
                ? 'Video access denied. Please enable gallery permissions in settings.'
                : 'Error accessing gallery. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unexpected error occurred.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCommunitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0C0C0C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return FutureBuilder<List<ApiCommunity>>(
          future: CommunitiesApi().listMine(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load your communities',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              );
            }

            final communities = snap.data ?? [];

            return StatefulBuilder(
              builder: (context, setSheetState) {
                String query = '';

                List<ApiCommunity> filtered = communities;
                void applyQuery(String q) {
                  setSheetState(() {
                    query = q.trim().toLowerCase();
                  });
                }

                filtered = communities.where((c) {
                  if (query.isEmpty) return true;
                  return c.name.toLowerCase().contains(query) ||
                      c.bio.toLowerCase().contains(query);
                }).toList();

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
                          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF666666), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                onChanged: applyQuery,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Search community...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                  border: InputBorder.none,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Communities list
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No communities found',
                                  style: GoogleFonts.inter(color: const Color(0xFF666666)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final community = filtered[index];
                                  final isSelected = _selectedCommunities.any((c) => c.id == community.id);
                                  final canSelect = _selectedCommunities.length < _maxCommunities || isSelected;

                                  return GestureDetector(
                                    onTap: canSelect
                                        ? () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedCommunities.removeWhere((c) => c.id == community.id);
                                              } else {
                                                _selectedCommunities.add(community);
                                              }
                                            });
                                            setSheetState(() {});
                                          }
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
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
                                          // Community avatar
                                          _CommunityAvatar(url: community.avatarUrl, name: community.name),
                                          const SizedBox(width: 16),

                                          // Community info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  community.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: canSelect ? (isDark ? Colors.white : Colors.black) : const Color(0xFF999999),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  community.bio,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: canSelect ? const Color(0xFF666666) : const Color(0xFF999999),
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Friends in common
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                community.friendsInCommon,
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
          },
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
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please write what's on your mind before posting.",
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirm if posting to a community
    if (_selectedCommunities.isNotEmpty) {
      final community = _selectedCommunities.first;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            title: Text('Post to Community?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            content: Text(
              "This post will be published in the community \"${community.name}\" and will not appear in your home feed.",
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Post', style: GoogleFonts.inter(color: const Color(0xFFBFAE01))),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    setState(() => _posting = true);
    try {
      // Upload local files (if any) and collect media descriptors
      final mediaPayload = <Map<String, dynamic>>[];
      for (final item in _mediaItems) {
        final xf = item.xfile;
        final path = item.path;
        if (xf == null && (path == null || path.isEmpty)) continue;

        final uploaded = await _uploadXFile(xf!, item.type);
        if (item.type == MediaType.image) {
          mediaPayload.add({
            'type': 'image',
            'url': uploaded['url'],
          });
        } else if (item.type == MediaType.video) {
          mediaPayload.add({
            'type': 'video',
            'url': uploaded['url'],
          });
        }
      }

      final content = [
        _titleController.text.trim(),
        body,
      ].where((e) => e.isNotEmpty).join('\n\n');

      if (_selectedCommunities.isNotEmpty) {
        // Post to the first selected community (UI unchanged; supports up to 3 selections but we take the first for publishing)
        final community = _selectedCommunities.first;
        await CommunityPostsApi().create(
          communityId: community.id,
          content: content,
          media: mediaPayload.isEmpty ? null : mediaPayload,
        );
      } else {
        // Post to home feed (global posts)
        await PostsApi().create(
          content: content,
          media: mediaPayload.isEmpty ? null : mediaPayload,
        );
      }

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

  // Upload helper that works on web and mobile using XFile bytes
  Future<Map<String, String>> _uploadXFile(XFile file, MediaType type) async {
    final dio = ApiClient().dio;
    final ext = _extensionOf(file.name);
    final contentType = _contentTypeForExt(ext, type);

    // 1) presign
    final pres = await dio.post(
      '/api/files/presign-upload',
      data: {'ext': ext},
    );
    final body = Map<String, dynamic>.from(pres.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final putUrl = (data['putUrl'] ?? '').toString();
    final key = (data['key'] ?? '').toString();
    final readUrl = (data['readUrl'] ?? '').toString();
    final publicUrl = (data['publicUrl'] ?? '').toString();
    final bestUrl = readUrl.isNotEmpty ? readUrl : publicUrl;

    // 2) upload to S3 via presigned URL
    final bytes = await file.readAsBytes();
    final s3 = Dio();
    await s3.put(
      putUrl,
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': contentType,
          // 'Content-Length' is not always allowed on web/XHR; omit for compatibility.
        },
      ),
    );

    // 3) confirm (non-blocking)
    try {
      await dio.post('/api/files/confirm', data: {'key': key, 'url': bestUrl});
    } catch (_) {}

    return {'key': key, 'url': bestUrl};
  }

  String _extensionOf(String filename) {
    final idx = filename.lastIndexOf('.');
    if (idx == -1 || idx == filename.length - 1) return 'bin';
    return filename.substring(idx + 1).toLowerCase();
  }

  String _contentTypeForExt(String ext, MediaType hint) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      default:
        // Fallback based on hint
        return hint == MediaType.video ? 'video/mp4' : 'application/octet-stream';
    }
  }
}

class MediaItem {
  final MediaType type;
  final String? path; // Local file path (mobile); not used on web
  final String? thumbnailUrl; // Optional remote thumbnail for videos
  final XFile? xfile; // Always keep the selected XFile to support web uploads

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
  final String username; // includes leading @ if available
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

class _CommunityAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _CommunityAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}