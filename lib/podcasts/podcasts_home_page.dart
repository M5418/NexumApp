import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme_provider.dart';
import 'podcast_sample_data.dart';
import 'podcast_models.dart';
import 'create_podcast_page.dart';
import 'my_library_page.dart';
import 'favorites_page.dart';
import 'podcast_categories_page.dart';
import 'favorite_playlist_page.dart';

class PodcastsHomePage extends StatelessWidget {
  const PodcastsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => Scaffold(
        backgroundColor: bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 26),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'Podcast',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.search,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF666666),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.more_horiz,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF666666),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Quick actions
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                sliver: _QuickActionsSliver(
                  onCreate: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreatePodcastPage(),
                    ),
                  ),
                  onLibrary: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyLibraryPage(),
                    ),
                  ),
                  onFavorites: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesPage(),
                    ),
                  ),
                  onCategories: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PodcastCategoriesPage(),
                    ),
                  ),
                ),
              ),
              // Section: Top Podcast
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Top Podcast',
                    trailing: 'More',
                    onTapTrailing: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PodcastCategoryFeedPage(
                          title: 'Top Podcast',
                          podcasts: PodcastSampleData.topPodcasts,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: _PodcastSliverGrid(
                  podcasts: PodcastSampleData.topPodcasts,
                  onTap: (p) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FavoritePlaylistPage(
                        playlist: Playlist(
                          id: 'auto-top-${p.id}',
                          title: '${p.title} — Highlights',
                          coverUrl: p.coverUrl,
                          description: p.description,
                          episodes: p.episodes,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Section: Educations
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Educations',
                    trailing: 'More',
                    onTapTrailing: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PodcastCategoryFeedPage(
                          title: 'Education & Languages',
                          podcasts: PodcastSampleData.byDomain(
                            'Education & Languages',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: _PodcastSliverGrid(
                  podcasts: PodcastSampleData.byDomain('Education & Languages'),
                  onTap: (p) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FavoritePlaylistPage(
                        playlist: Playlist(
                          id: 'edu-${p.id}',
                          title: '${p.title} — Education',
                          coverUrl: p.coverUrl,
                          description: p.description,
                          episodes: p.episodes,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback onTapTrailing;
  const _SectionHeader({
    required this.title,
    required this.trailing,
    required this.onTapTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTapTrailing,
          child: Row(
            children: [
              Text(
                trailing,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFBFAE01),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFBFAE01),
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodcastSliverGrid extends StatelessWidget {
  final List<Podcast> podcasts;
  final void Function(Podcast) onTap;
  const _PodcastSliverGrid({required this.podcasts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final p = podcasts[i];
        return GestureDetector(
          onTap: () => onTap(p),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 13),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: p.coverUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      memCacheHeight: 400,
                      placeholder: (context, url) => Container(
                        color: isDark
                            ? const Color(0xFF111111)
                            : const Color(0xFFEAEAEA),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark
                            ? const Color(0xFF111111)
                            : const Color(0xFFEAEAEA),
                        child: const Center(
                          child: Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }, childCount: podcasts.length),
    );
  }
}

class _QuickActionsSliver extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onLibrary;
  final VoidCallback onFavorites;
  final VoidCallback onCategories;
  const _QuickActionsSliver({
    required this.onCreate,
    required this.onLibrary,
    required this.onFavorites,
    required this.onCategories,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      delegate: SliverChildListDelegate([
        _QuickActionTile(
          icon: Icons.add,
          label: 'Add Podcast',
          onTap: onCreate,
          isDark: isDark,
        ),
        _QuickActionTile(
          icon: Icons.library_music_outlined,
          label: 'My Library',
          onTap: onLibrary,
          isDark: isDark,
        ),
        _QuickActionTile(
          icon: Icons.favorite_border,
          label: 'Favorites',
          onTap: onFavorites,
          isDark: isDark,
        ),
        _QuickActionTile(
          icon: Icons.category_outlined,
          label: 'Categories',
          onTap: onCategories,
          isDark: isDark,
        ),
      ]),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 13),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBFAE01), size: 18),
          ],
        ),
      ),
    );
  }
}

class PodcastCategoryFeedPage extends StatelessWidget {
  final String title;
  final List<Podcast> podcasts;
  const PodcastCategoryFeedPage({
    super.key,
    required this.title,
    required this.podcasts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _PodcastSliverGrid(
              podcasts: podcasts,
              onTap: (p) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoritePlaylistPage(
                    playlist: Playlist(
                      id: 'cat-${p.id}',
                      title: '${p.title} — Highlights',
                      coverUrl: p.coverUrl,
                      description: p.description,
                      episodes: p.episodes,
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
}
