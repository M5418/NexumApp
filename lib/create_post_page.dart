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
import 'widgets/tag_chip.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/community_repository.dart';
import 'repositories/interfaces/draft_repository.dart';
import 'repositories/models/draft_model.dart';
import 'core/files_api.dart';
import 'repositories/firebase/firebase_follow_repository.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'services/media_compression_service.dart';
import 'core/profile_api.dart';
import '../responsive/responsive_breakpoints.dart';

class CreatePostPage extends StatefulWidget {
  final DraftModel? draft;
  
  const CreatePostPage({super.key, this.draft});
  
  static Future<T?> showPopup<T>(BuildContext context, {DraftModel? draft}) {
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
                child: CreatePostPage(draft: draft),
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
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<CommunityModel> _selectedCommunities = [];
  final List<MediaItem> _mediaItems = [];
  final List<String> _taggedUsers = [];
  final int _maxCommunities = 3;

  bool _posting = false;
  bool _isEditingDraft = false;
  String? _draftId;

  final FirebasePostRepository _postRepo = FirebasePostRepository();

  // Body is REQUIRED, title optional. Media can be attached but not sufficient without body.
  bool get _canPost => (!_posting) && _bodyController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.draft != null) {
      _loadDraft(widget.draft!);
    }
  }

  void _loadDraft(DraftModel draft) {
    _isEditingDraft = true;
    _draftId = draft.id;
    _titleController.text = draft.title;
    _bodyController.text = draft.body;
    
    // Load media items
    for (final url in draft.mediaUrls) {
      _mediaItems.add(MediaItem(
        type: MediaType.image,
        path: url,
      ));
    }
    
    // Load tagged users
    if (draft.taggedUsers != null) {
      _taggedUsers.addAll(draft.taggedUsers!);
    }
    
    setState(() {});
  }

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
      backgroundColor:
          isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final isDesktop =
                kIsWeb && (context.isDesktop || context.isLargeDesktop);
            final content = Column(
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
            );

            if (!isDesktop) return content;

            // Desktop: center and constrain width like popup
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: content,
                ),
              ),
            );
          },
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
                Provider.of<LanguageProvider>(context, listen: false).t('create_post.create_post'),
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
        hintText: Provider.of<LanguageProvider>(context).t('create_post.title_hint'),
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
            hintText: Provider.of<LanguageProvider>(context).t('create_post.whats_on_mind'),
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
                  Provider.of<LanguageProvider>(context, listen: false).t('create_post.community'),
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
                    Provider.of<LanguageProvider>(context, listen: false).t('create_post.save_as_draft'),
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
                          Provider.of<LanguageProvider>(context).t('create_post.post_button'),
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
                          color: isDark
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: Color(0xFF666666), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                onChanged: applyQuery,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: Provider.of<LanguageProvider>(context).t('create_post.search_connections'),
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
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF666666)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final u = filtered[index];
                                  final label = u.username.isNotEmpty
                                      ? u.username
                                      : u.name;
                                  final selected =
                                      localSelected.contains(label);
                                  return ListTile(
                                    leading: _Avatar(
                                        avatarUrl: u.avatarUrl,
                                        letter: u.avatarLetter),
                                    title: Text(
                                      u.name,
                                      style: GoogleFonts.inter(),
                                    ),
                                    subtitle: Text(
                                      u.username,
                                      style: GoogleFonts.inter(
                                          color: const Color(0xFF666666)),
                                    ),
                                    trailing: selected
                                        ? const Icon(Icons.check_circle,
                                            color: Color(0xFFBFAE01))
                                        : const Icon(
                                            Icons.radio_button_unchecked,
                                            color: Color(0xFFCCCCCC)),
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
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];
      final follows = FirebaseFollowRepository();
      final usersRepo = FirebaseUserRepository();
      final followers = await follows.getFollowers(userId: uid, limit: 500);
      final following = await follows.getFollowing(userId: uid, limit: 500);
      final ids = <String>{
        ...followers.map((f) => f.followerId),
        ...following.map((f) => f.followedId),
      }..remove(uid);
      if (ids.isEmpty) return [];
      final profiles = await usersRepo.getUsers(ids.toList());
      final users = profiles.map((p) {
        final name = (p.displayName ?? '').trim();
        final username = (p.username ?? '').trim();
        final email = (p.email ?? '').trim();
        final letterSource = name.isNotEmpty
            ? name
            : (username.isNotEmpty ? username : email);
        final letter =
            letterSource.isNotEmpty ? letterSource[0].toUpperCase() : 'U';
        return _TagUser(
          id: p.uid,
          name: name.isNotEmpty
              ? name
              : (email.isNotEmpty ? email.split('@').first : 'User'),
          username: username.isNotEmpty ? '@$username' : '@user',
          avatarUrl: p.avatarUrl,
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
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_post.unexpected_error')),
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
        // Generate thumbnail for video preview
        String? thumbnailPath;
        if (!kIsWeb) {
          try {
            final thumbnail = await VideoCompress.getFileThumbnail(
              video.path,
              quality: 50,
            );
            thumbnailPath = thumbnail.path;
          } catch (e) {
            debugPrint('⚠️ Failed to generate video thumbnail: $e');
          }
        }
        
        setState(() {
          // Only one video allowed, replace any existing media
          _mediaItems
            ..clear()
            ..add(MediaItem(
                type: MediaType.video, 
                path: video.path, 
                xfile: video,
                thumbnailUrl: thumbnailPath ?? video.path)); // Use thumbnail or fallback to video path
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
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.unexpected_error')),
          backgroundColor: Colors.red,
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

        return FutureBuilder<List<CommunityModel>>(
          future: context.read<CommunityRepository>().listMine(),
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

                List<CommunityModel> filtered = communities;
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
                          color: isDark
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: Color(0xFF666666), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                onChanged: applyQuery,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: Provider.of<LanguageProvider>(context).t('create_post.search_community'),
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
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF666666)),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final community = filtered[index];
                                  final isSelected = _selectedCommunities
                                      .any((c) => c.id == community.id);
                                  final canSelect =
                                      _selectedCommunities.length <
                                              _maxCommunities ||
                                          isSelected;

                                  return GestureDetector(
                                    onTap: canSelect
                                        ? () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedCommunities
                                                    .removeWhere((c) =>
                                                        c.id == community.id);
                                              } else {
                                                _selectedCommunities
                                                    .add(community);
                                              }
                                            });
                                            setSheetState(() {});
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
                                            : Border.all(
                                                color: Colors.transparent,
                                                width: 2),
                                      ),
                                      child: Row(
                                        children: [
                                          // Community avatar
                                          _CommunityAvatar(
                                              url: community.avatarUrl,
                                              name: community.name),
                                          const SizedBox(width: 16),

                                          // Community info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  community.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: canSelect
                                                        ? (isDark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        : const Color(
                                                            0xFF999999),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  community.bio,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: canSelect
                                                        ? const Color(
                                                            0xFF666666)
                                                        : const Color(
                                                            0xFF999999),
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Friends in common
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                community.friendsInCommon,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xFF666666),
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

  Future<void> _saveDraft() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_post.write_something'), style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final draftRepo = context.read<DraftRepository>();
      
      // Upload media first if any
      final mediaUrls = <String>[];
      for (final item in _mediaItems) {
        if (item.xfile != null) {
          final uploaded = await _uploadXFile(item.xfile!, item.type);
          mediaUrls.add(uploaded['url'] ?? '');
        } else if (item.path != null && item.path!.startsWith('http')) {
          // Already uploaded (editing existing draft)
          mediaUrls.add(item.path!);
        }
      }

      if (_isEditingDraft && _draftId != null) {
        // Update existing draft
        await draftRepo.updatePostDraft(
          draftId: _draftId!,
          title: _titleController.text.trim(),
          body: body,
          mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
          taggedUsers: _taggedUsers.isNotEmpty ? _taggedUsers : null,
          communities: _selectedCommunities.map((c) => c.id).toList(),
        );
      } else {
        // Create new draft
        await draftRepo.savePostDraft(
          title: _titleController.text.trim(),
          body: body,
          mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
          taggedUsers: _taggedUsers.isNotEmpty ? _taggedUsers : null,
          communities: _selectedCommunities.map((c) => c.id).toList(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('create_post.saved_to_drafts'), style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('create_post.save_draft_failed')}: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            title: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('create_post.post_to_community'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            content: Text(
              '${Provider.of<LanguageProvider>(ctx, listen: false).t('create_post.community_post_notice')} "${community.name}"',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('create_post.post_button'),
                    style: GoogleFonts.inter(color: const Color(0xFFBFAE01))),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    setState(() => _posting = true);
    try {
      final content = [
        _titleController.text.trim(),
        body,
      ].where((e) => e.isNotEmpty).join('\n\n');

      final hasMedia = _mediaItems.isNotEmpty;
      final communityId = _selectedCommunities.isNotEmpty ? _selectedCommunities.first.id : null;
      
      List<String> mediaUrls = [];
      List<String> thumbUrls = [];
      
      if (hasMedia) {
        // FAST: Upload thumbnails first (small ~20-50KB each) for instant display
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
        // Use thumbnails as placeholder media URLs for instant display
        mediaUrls = thumbUrls.where((u) => u.isNotEmpty).toList();
        debugPrint('✅ Thumbnails uploaded: ${mediaUrls.length}');
      }
      
      debugPrint('🚀 Creating post with ${mediaUrls.length} thumbnails${communityId != null ? ' to community $communityId' : ''}');
      final postId = await _postRepo.createPost(
        text: content, 
        mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
        thumbUrls: thumbUrls.isNotEmpty ? thumbUrls : null,
        communityId: communityId,
      );
      debugPrint('✅ Post created with ID: $postId');

      if (!mounted) return;
      
      // Delete draft if editing (non-blocking)
      if (_isEditingDraft && _draftId != null) {
        context.read<DraftRepository>().deleteDraft(_draftId!).catchError((_) {});
      }
      
      // Show success message
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
      
      // Navigate back immediately
      Navigator.pop(context, true);

      // Upload full-resolution media in background and update post
      if (hasMedia) {
        debugPrint('💾 Starting background upload for full-resolution media');
        _uploadMediaInBackground(postId, content, _mediaItems);
      }

    } catch (e, stackTrace) {
      debugPrint('❌ Error creating post: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ Error type: ${e.runtimeType}');
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

  // Background upload: doesn't block UI - PARALLEL UPLOADS FOR SPEED
  Future<void> _uploadMediaInBackground(String postId, String text, List<MediaItem> items) async {
    try {
      debugPrint('💾 Starting parallel upload of ${items.length} media items');
      
      // Upload all media in parallel for faster performance
      // Returns {url, thumbUrl} for each item
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
          return {'url': path, 'thumbUrl': path}; // Already uploaded
        }

        return <String, String>{};
      }).toList();
      
      // Wait for all uploads to complete
      final results = await Future.wait(uploadFutures);
      final mediaUrls = results.map((r) => r['url'] ?? '').where((u) => u.isNotEmpty).toList();
      final thumbUrls = results.map((r) => r['thumbUrl'] ?? r['url'] ?? '').where((u) => u.isNotEmpty).toList();

      if (mediaUrls.isEmpty) {
        debugPrint('⚠️ No media URLs to update');
        return;
      }

      // Update post with real media URLs and thumbnails
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
      // Optionally: could retry or notify user
    }
  }

  // Upload helper that works on web and mobile using XFile bytes
  // Returns {'url': fullSizeUrl, 'thumbUrl': thumbnailUrl}
  Future<Map<String, String>> _uploadXFile(XFile file, MediaType type) async {
    final ext = _extensionOf(file.name);
    final compressionService = MediaCompressionService();
    
    try {
      // Compress based on media type
      if (type == MediaType.image) {
        debugPrint('🖼️ Compressing image before upload: ${file.name}');
        
        final originalBytes = await file.readAsBytes();
        
        // Generate feed thumbnail (400px, 60% quality) - PARALLEL with compression
        final thumbFuture = compressionService.generateFeedThumbnailFromBytes(
          bytes: originalBytes,
          filename: file.name,
          maxSize: 400,
          quality: 60,
        );
        
        // Compress image with high quality for full view
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
        
        // Wait for thumbnail
        final thumbBytes = await thumbFuture;
        
        if (compressedBytes == null) {
          debugPrint('⚠️ Compression failed, using original image');
          final res = await FilesApi().uploadBytes(originalBytes, ext: ext);
          final url = res['url'] ?? '';
          // Upload thumbnail if available
          String thumbUrl = url;
          if (thumbBytes != null) {
            final thumbRes = await FilesApi().uploadBytes(thumbBytes, ext: ext);
            thumbUrl = thumbRes['url'] ?? url;
          }
          return {'url': url, 'thumbUrl': thumbUrl};
        }
        
        // Upload compressed image + thumbnail in parallel
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
        debugPrint('🎥 Compressing video before upload: ${file.name}');
        
        // Generate video thumbnail for feed
        File? thumbFile;
        try {
          thumbFile = await VideoCompress.getFileThumbnail(
            file.path,
            quality: 50,
            position: -1, // Default position
          );
        } catch (_) {
          // Thumbnail generation failed
        }
        
        // Compress video (mobile only)
        final compressedFile = await compressionService.compressVideo(
          filePath: file.path,
          quality: VideoQuality.HighestQuality,
        );
        
        if (compressedFile == null) {
          debugPrint('⚠️ Video compression failed, using original');
          final bytes = await file.readAsBytes();
          final res = await FilesApi().uploadBytes(bytes, ext: ext);
          final url = res['url'] ?? '';
          // Upload video thumbnail if available
          String thumbUrl = url;
          if (thumbFile != null) {
            final thumbBytes = await thumbFile.readAsBytes();
            final thumbRes = await FilesApi().uploadBytes(thumbBytes, ext: 'jpg');
            thumbUrl = thumbRes['url'] ?? url;
          }
          return {'url': url, 'thumbUrl': thumbUrl};
        }
        
        // Upload compressed video + thumbnail in parallel
        final compressedBytes = await compressedFile.readAsBytes();
        final videoUpload = FilesApi().uploadBytes(compressedBytes, ext: ext);
        final thumbUpload = thumbFile != null 
            ? FilesApi().uploadBytes(await thumbFile.readAsBytes(), ext: 'jpg')
            : Future.value(<String, dynamic>{'url': ''});
        
        final results = await Future.wait([videoUpload, thumbUpload]);
        final videoUrl = results[0]['url'] ?? '';
        final thumbUrl = results[1]['url'] ?? videoUrl;
        
        return {'url': videoUrl, 'thumbUrl': thumbUrl};
      } else {
        // Web video or unsupported type - upload original
        debugPrint('📤 Uploading without compression: ${file.name}');
        final bytes = await file.readAsBytes();
        final res = await FilesApi().uploadBytes(bytes, ext: ext);
        return {'url': res['url'] ?? '', 'thumbUrl': res['url'] ?? ''};
      }
    } catch (e) {
      debugPrint('❌ Error during compression/upload: $e');
      // Fallback to original upload
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
