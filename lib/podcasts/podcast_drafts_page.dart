import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'create_podcast_page.dart';
import '../repositories/interfaces/draft_repository.dart';
import '../repositories/models/draft_model.dart';

class PodcastDraftsPage extends StatefulWidget {
  const PodcastDraftsPage({super.key});

  @override
  State<PodcastDraftsPage> createState() => _PodcastDraftsPageState();
}

class _PodcastDraftsPageState extends State<PodcastDraftsPage> {
  bool _loading = true;
  String? _error;
  List<DraftModel> _drafts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final repo = context.read<DraftRepository>();
      final drafts = await repo.getPodcastDrafts();
      
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load drafts: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteDraft(DraftModel draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Draft', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "${draft.title}"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final repo = context.read<DraftRepository>();
      await repo.deleteDraft(draft.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft deleted', style: GoogleFonts.inter())),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editDraft(DraftModel draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'create_podcast'),
        builder: (_) => CreatePodcastPage(draft: draft),
      ),
    ).then((result) {
      if (result == true) {
        _load();
      }
    });
  }

  String _shortDate(DateTime? d) {
    if (d == null) return '';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'Podcast Drafts',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : _drafts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.drafts_outlined,
                            size: 64,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No drafts yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : const Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your podcast drafts will appear here',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : const Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFBFAE01),
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drafts.length,
                        itemBuilder: (context, i) {
                          final draft = _drafts[i];
                          return _DraftCard(
                            title: draft.title.isNotEmpty ? draft.title : 'Untitled',
                            description: draft.body,
                            coverUrl: draft.coverUrl,
                            date: _shortDate(draft.updatedAt),
                            onTap: () => _editDraft(draft),
                            onDelete: () => _deleteDraft(draft),
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final String title;
  final String description;
  final String? coverUrl;
  final String date;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDark;

  const _DraftCard({
    required this.title,
    required this.description,
    this.coverUrl,
    required this.date,
    required this.onTap,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Cover image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: (coverUrl ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        memCacheHeight: 120,
                        placeholder: (context, url) => Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                          child: const Center(
                            child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 24),
                          ),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                        child: const Center(
                          child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 24),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Title and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF999999),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: isDark ? Colors.white54 : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
