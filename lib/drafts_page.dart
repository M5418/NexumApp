import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'repositories/interfaces/draft_repository.dart';
import 'repositories/models/draft_model.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';
import 'create_post_page.dart';
import 'podcasts/create_podcast_page.dart';

class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DraftRepository _draftRepo;

  List<DraftModel> _postDrafts = [];
  List<DraftModel> _podcastDrafts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _draftRepo = context.read<DraftRepository>();
    _loadDrafts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    setState(() => _loading = true);
    try {
      final posts = await _draftRepo.getPostDrafts();
      final podcasts = await _draftRepo.getPodcastDrafts();
      if (!mounted) return;
      setState(() {
        _postDrafts = posts;
        _podcastDrafts = podcasts;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.load_drafts_failed')}: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor =
            isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
        final textColor = isDark ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              Provider.of<LanguageProvider>(context).t('drafts.title'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFBFAE01),
              labelColor: const Color(0xFFBFAE01),
              unselectedLabelColor: const Color(0xFF666666),
              labelStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: '${context.read<LanguageProvider>().t('bookmarks.posts')} (${_postDrafts.length})'),
                Tab(text: '${context.read<LanguageProvider>().t('bookmarks.podcasts')} (${_podcastDrafts.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostDrafts(isDark),
              _buildPodcastDrafts(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostDrafts(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_postDrafts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drafts_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              Provider.of<LanguageProvider>(context, listen: false).t('drafts.no_posts'),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDrafts,
      color: const Color(0xFFBFAE01),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _postDrafts.length,
        itemBuilder: (context, index) {
          final draft = _postDrafts[index];
          return _buildDraftCard(draft, isDark);
        },
      ),
    );
  }

  Widget _buildPodcastDrafts(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_podcastDrafts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              Provider.of<LanguageProvider>(context, listen: false).t('drafts.no_podcasts'),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDrafts,
      color: const Color(0xFFBFAE01),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _podcastDrafts.length,
        itemBuilder: (context, index) {
          final draft = _podcastDrafts[index];
          return _buildDraftCard(draft, isDark);
        },
      ),
    );
  }

  Widget _buildDraftCard(DraftModel draft, bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _openDraft(draft),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    draft.type == DraftType.post
                        ? Icons.article_outlined
                        : Icons.mic_outlined,
                    color: const Color(0xFFBFAE01),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      draft.title.isEmpty ? Provider.of<LanguageProvider>(context, listen: false).t('drafts.untitled') : draft.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteDraft(draft.id),
                  ),
                ],
              ),
              if (draft.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  draft.body,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    timeago.format(draft.updatedAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF999999),
                    ),
                  ),
                  if (draft.mediaUrls.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      draft.type == DraftType.post
                          ? Icons.image_outlined
                          : Icons.audiotrack_outlined,
                      size: 16,
                      color: const Color(0xFF999999),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${draft.mediaUrls.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDraft(DraftModel draft) async {
    if (draft.type == DraftType.post) {
      // Open post editor with draft
      await CreatePostPage.showPopup(context, draft: draft);
      // Refresh drafts after closing editor
      await _loadDrafts();
    } else if (draft.type == DraftType.podcast) {
      // Open podcast editor with draft
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'create_podcast'),
          builder: (_) => CreatePodcastPage(draft: draft),
        ),
      );
      // Refresh drafts after closing editor
      await _loadDrafts();
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Text(
            Provider.of<LanguageProvider>(ctx, listen: false).t('drafts.delete_title'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('drafts.delete_confirm'),
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('drafts.delete_button'),
                style: GoogleFonts.inter(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _draftRepo.deleteDraft(draftId);
        await _loadDrafts();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.draft_deleted'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.delete_draft_failed')}: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
