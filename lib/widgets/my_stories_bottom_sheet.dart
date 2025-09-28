import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/stories_api.dart' as stories;

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
  stories.StoryUser? _user;
  List<stories.StoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await stories.StoriesApi().getUserStories(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _user = resp.user;
        _items = resp.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = null;
        _items = [];
        _loading = false;
      });
    }
  }

  Widget _preview(stories.StoryItem it) {
    if (it.mediaType == 'image') {
      final url = it.thumbnailUrl ?? it.mediaUrl ?? '';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF666666).withAlpha(51)),
            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white70),
          ),
        ),
      );
    }
    if (it.mediaType == 'video') {
      final thumb = it.thumbnailUrl ?? it.mediaUrl ?? '';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF666666).withAlpha(51)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF333333)),
              ),
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
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (it.textContent ?? 'T').isEmpty ? 'T' : it.textContent!.substring(0, 1),
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _label(stories.StoryItem it) {
    if (it.mediaType == 'text') {
      final t = (it.textContent ?? '').trim();
      return t.isEmpty ? 'Text story' : (t.length > 30 ? '${t.substring(0, 30)}...' : t);
    }
    return it.mediaType == 'image' ? 'Image story' : 'Video story';
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
                  'Your Stories',
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
                  label: Text('Add Story', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                  'No active stories. Tap “Add Story”.',
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
                        _preview(it),
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