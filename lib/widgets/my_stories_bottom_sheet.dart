import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../repositories/interfaces/story_repository.dart';
import '../core/i18n/language_provider.dart';

class MyStoriesBottomSheet extends StatefulWidget {
  final String currentUserId;
  final VoidCallback onAddStory;

  const MyStoriesBottomSheet({
    super.key,
    required this.currentUserId,
    required this.onAddStory,
  });

  static void show(
    BuildContext context, {
    required String currentUserId,
    required VoidCallback onAddStory,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MyStoriesBottomSheet(
        currentUserId: currentUserId,
        onAddStory: onAddStory,
      ),
    );
  }

  @override
  State<MyStoriesBottomSheet> createState() => _MyStoriesBottomSheetState();
}

class _MyStoriesBottomSheetState extends State<MyStoriesBottomSheet> {
  bool _loading = true;
  List<StoryModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storyRepo = context.read<StoryRepository>();
      final rings = await storyRepo.getStoryRings();
      
      // Find the user's ring
      final myRing = rings.where((r) => r.userId == widget.currentUserId).firstOrNull;
      
      if (myRing != null) {
        // Filter for active stories only (< 24 hours old)
        final now = DateTime.now();
        final activeStories = myRing.stories.where((story) {
          final age = now.difference(story.createdAt);
          return age.inHours < 24;
        }).toList();
        
        // Sort by most recent first
        activeStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        if (!mounted) return;
        setState(() {
          _items = activeStories;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _items = [];
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  Widget _storyThumbnail(StoryModel item) {
    if (item.mediaType == 'image') {
      final url = item.thumbnailUrl ?? item.mediaUrl ?? '';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF666666).withValues(alpha: 51)),
                  errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white70),
                )
              : Container(
                  color: const Color(0xFF666666).withValues(alpha: 51),
                  child: const Icon(Icons.image, color: Colors.white70),
                ),
        ),
      );
    }
    if (item.mediaType == 'video') {
      final thumb = item.thumbnailUrl ?? item.mediaUrl ?? '';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: thumb.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFF666666).withValues(alpha: 51)),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF333333)),
                    )
                  : Container(color: const Color(0xFF333333)),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
            ),
          ],
        ),
      );
    }
    // Text story
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: item.backgroundColor != null 
            ? Color(int.parse(item.backgroundColor!.replaceFirst('#', '0xFF')))
            : const Color(0xFFE74C3C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (item.textContent ?? 'T').isEmpty ? 'T' : item.textContent!.substring(0, 1).toUpperCase(),
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
      ),
    );
  }

  String _label(StoryModel story) {
    if (story.mediaType == 'text') {
      final t = (story.textContent ?? '').trim();
      return t.isEmpty ? Provider.of<LanguageProvider>(context, listen: false).t('story.text_story') : (t.length > 30 ? '${t.substring(0, 30)}...' : t);
    }
    return story.mediaType == 'image' ? Provider.of<LanguageProvider>(context, listen: false).t('story.image_story') : Provider.of<LanguageProvider>(context, listen: false).t('story.video_story');
  }

  Future<void> _confirmDelete(StoryModel story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('story.delete_story_title'), style: GoogleFonts.inter()),
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('story.delete_story_message'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('story.cancel'), style: GoogleFonts.inter(color: const Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('story.delete'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteStory(story);
    }
  }

  Future<void> _deleteStory(StoryModel story) async {
    try {
      final storyRepo = context.read<StoryRepository>();
      await storyRepo.deleteStory(story.id);
      
      // Remove from local list
      setState(() {
        _items.removeWhere((s) => s.id == story.id);
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('story.story_deleted'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFBFAE01),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('story.delete_failed'), style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('story.your_stories'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onAddStory();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(Provider.of<LanguageProvider>(context, listen: false).t('story.add_story'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('story.no_active_stories'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    return Row(
                      children: [
                        _storyThumbnail(it),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_label(it),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.visibility, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Text('${it.viewsCount}', style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.favorite, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Text('${it.likesCount}', style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.chat_bubble_outline, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Text('${it.commentsCount}', style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Delete button
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          onPressed: () => _confirmDelete(it),
                          tooltip: Provider.of<LanguageProvider>(context, listen: false).t('story.delete_story'),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}