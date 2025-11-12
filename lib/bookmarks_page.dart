import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'repositories/interfaces/bookmark_repository.dart';
import 'repositories/models/bookmark_model.dart';
import 'theme_provider.dart';
import 'core/i18n/language_provider.dart';

class BookmarksPage extends StatefulWidget {
  final int initialTabIndex;

  const BookmarksPage({super.key, this.initialTabIndex = 0});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BookmarkRepository _bookmarkRepo;

  List<BookmarkModel> _postBookmarks = [];
  List<BookmarkModel> _podcastBookmarks = [];
  List<BookmarkModel> _bookBookmarks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _bookmarkRepo = context.read<BookmarkRepository>();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _loading = true);
    try {
      final posts = await _bookmarkRepo.getPostBookmarks();
      final podcasts = await _bookmarkRepo.getPodcastBookmarks();
      final books = await _bookmarkRepo.getBookBookmarks();
      
      if (!mounted) return;
      setState(() {
        _postBookmarks = posts;
        _podcastBookmarks = podcasts;
        _bookBookmarks = books;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.load_bookmarks_failed')}: $e', style: GoogleFonts.inter()),
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
              Provider.of<LanguageProvider>(context).t('bookmarks.title'),
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
                Tab(text: '${context.read<LanguageProvider>().t('bookmarks.posts')} (${_postBookmarks.length})'),
                Tab(text: '${context.read<LanguageProvider>().t('bookmarks.podcasts')} (${_podcastBookmarks.length})'),
                Tab(text: '${context.read<LanguageProvider>().t('bookmarks.books')} (${_bookBookmarks.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostBookmarks(isDark),
              _buildPodcastBookmarks(isDark),
              _buildBookBookmarks(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostBookmarks(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_postBookmarks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_outline,
        message: context.read<LanguageProvider>().t('bookmarks.no_posts'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: const Color(0xFFBFAE01),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _postBookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = _postBookmarks[index];
          return _buildBookmarkCard(bookmark, isDark);
        },
      ),
    );
  }

  Widget _buildPodcastBookmarks(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_podcastBookmarks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mic_none,
        message: context.read<LanguageProvider>().t('bookmarks.no_podcasts'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: const Color(0xFFBFAE01),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _podcastBookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = _podcastBookmarks[index];
          return _buildBookmarkCard(bookmark, isDark);
        },
      ),
    );
  }

  Widget _buildBookBookmarks(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookBookmarks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.menu_book_outlined,
        message: context.read<LanguageProvider>().t('bookmarks.no_books'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: const Color(0xFFBFAE01),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookBookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = _bookBookmarks[index];
          return _buildBookmarkCard(bookmark, isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkCard(BookmarkModel bookmark, bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    IconData getIcon() {
      switch (bookmark.type) {
        case BookmarkType.post:
          return Icons.article_outlined;
        case BookmarkType.podcast:
          return Icons.mic_outlined;
        case BookmarkType.book:
          return Icons.menu_book_outlined;
      }
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _openBookmark(bookmark),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cover image or icon
              if (bookmark.coverUrl != null && bookmark.coverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    bookmark.coverUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(getIcon(), color: const Color(0xFFBFAE01)),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(getIcon(), color: const Color(0xFFBFAE01)),
                ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bookmark.title != null && bookmark.title!.isNotEmpty)
                      Text(
                        bookmark.title!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (bookmark.authorName != null && bookmark.authorName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          bookmark.authorName!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF666666),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        timeago.format(bookmark.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF999999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.bookmark, color: Color(0xFFBFAE01)),
                onPressed: () => _removeBookmark(bookmark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBookmark(BookmarkModel bookmark) {
    switch (bookmark.type) {
      case BookmarkType.post:
        // Navigate to post detail page
        Navigator.pushNamed(
          context,
          '/post',
          arguments: {'postId': bookmark.itemId},
        );
        break;
      case BookmarkType.podcast:
        // Navigate to podcast detail page
        Navigator.pushNamed(
          context,
          '/podcast',
          arguments: {'podcastId': bookmark.itemId},
        );
        break;
      case BookmarkType.book:
        // Navigate to book detail page
        Navigator.pushNamed(
          context,
          '/book',
          arguments: {'bookId': bookmark.itemId},
        );
        break;
    }
  }

  Future<void> _removeBookmark(BookmarkModel bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Text(
            Provider.of<LanguageProvider>(ctx, listen: false).t('bookmarks.remove_title'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            Provider.of<LanguageProvider>(ctx, listen: false).t('bookmarks.remove_message'),
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
                Provider.of<LanguageProvider>(ctx, listen: false).t('common.delete'),
                style: GoogleFonts.inter(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _bookmarkRepo.removeBookmark(bookmark.id);
        await _loadBookmarks();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('messages.bookmark_removed'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('messages.remove_bookmark_failed')}: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
