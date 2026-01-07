import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'podcasts_home_page.dart' show Podcast;
import 'player_page.dart';
import 'add_to_playlist_sheet.dart';
import 'edit_podcast_page.dart';
import '../repositories/interfaces/bookmark_repository.dart';
import '../repositories/interfaces/podcast_repository.dart';
import '../repositories/models/bookmark_model.dart';
import '../core/i18n/language_provider.dart';

class PodcastDetailsPage extends StatefulWidget {
  final Podcast podcast;
  const PodcastDetailsPage({super.key, required this.podcast});

  @override
  State<PodcastDetailsPage> createState() => _PodcastDetailsPageState();
}

class _PodcastDetailsPageState extends State<PodcastDetailsPage> {
  late Podcast podcast;
  bool _togglingLike = false;
  bool _togglingBookmark = false;
  bool _isBookmarked = false;
  bool _isOwner = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    podcast = widget.podcast;
    _checkBookmarkStatus();
    _checkOwnership();
  }

  void _checkOwnership() {
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && podcast.authorId == currentUid) {
      setState(() => _isOwner = true);
    }
  }

  Future<void> _editPodcast() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'edit_podcast'),
        builder: (_) => EditPodcastPage(podcast: podcast),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deletePodcast() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('podcasts.delete'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(lang.t('podcasts.delete_confirm'), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('common.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lang.t('common.delete'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final podcastRepo = context.read<PodcastRepository>();
      await podcastRepo.deletePodcast(podcast.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.t('podcasts.deleted'), style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.t('podcasts.delete_failed')}: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _checkBookmarkStatus() async {
    try {
      final bookmarkRepo = context.read<BookmarkRepository>();
      final isBookmarked = await bookmarkRepo.isBookmarked(podcast.id, BookmarkType.podcast);
      if (mounted) {
        setState(() => _isBookmarked = isBookmarked);
      }
    } catch (e) {
      debugPrint('⚠️ Error checking bookmark status: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_togglingLike) return;
    setState(() => _togglingLike = true);
    try {
      final bookmarkRepo = context.read<BookmarkRepository>();
      if (podcast.meLiked) {
        await bookmarkRepo.removeBookmark(podcast.id);
        setState(() {
          podcast.meLiked = false;
          podcast.likes = (podcast.likes - 1).clamp(0, 999999);
        });
      } else {
        setState(() {
          podcast.meLiked = true;
          podcast.likes = (podcast.likes + 1).clamp(0, 999999);
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    } finally {
      if (mounted) setState(() => _togglingLike = false);
    }
  }

  Future<void> _toggleBookmark() async {
    if (_togglingBookmark) return;
    setState(() {
      _togglingBookmark = true;
      _isBookmarked = !_isBookmarked;
    });

    try {
      final bookmarkRepo = context.read<BookmarkRepository>();
      if (_isBookmarked) {
        await bookmarkRepo.bookmarkPodcast(
          podcastId: podcast.id,
          title: podcast.title,
          coverUrl: podcast.coverUrl,
          authorName: podcast.author,
          description: podcast.description,
        );
      } else {
        await bookmarkRepo.removeBookmarkByItem(podcast.id, BookmarkType.podcast);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('podcasts.bookmark_failed')}: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingBookmark = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _togglingLike ? null : _toggleLike,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                podcast.meLiked ? Icons.favorite : Icons.favorite_border,
                color: podcast.meLiked ? Colors.pink.shade400 : Colors.white,
                size: 20,
              ),
            ),
          ),
          IconButton(
            onPressed: _togglingBookmark ? null : _toggleBookmark,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? const Color(0xFFBFAE01) : Colors.white,
                size: 20,
              ),
            ),
          ),
          IconButton(
            onPressed: () => showAddToPlaylistSheet(context, podcast),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.playlist_add, color: Colors.white, size: 20),
            ),
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _editPodcast();
                } else if (value == 'delete') {
                  _deletePodcast();
                }
              },
              itemBuilder: (ctx) {
                final lang = Provider.of<LanguageProvider>(ctx, listen: false);
                return [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20, color: Color(0xFFBFAE01)),
                        const SizedBox(width: 12),
                        Text(lang.t('podcasts.edit'), style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !_deleting,
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: _deleting ? Colors.grey : Colors.red),
                        const SizedBox(width: 12),
                        Text(lang.t('podcasts.delete'), style: GoogleFonts.inter(color: _deleting ? Colors.grey : Colors.red)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Hero Background Image with Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.30,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if ((podcast.coverUrl ?? '').isNotEmpty)
                  Image.network(
                    podcast.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 80),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 80),
                  ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                        isDark ? const Color(0xFF0C0C0C) : const Color(0xFF000000),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: screenHeight * 0.24),
              
              // Content Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C0C0C) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                constraints: BoxConstraints(
                  minHeight: screenHeight * 0.76,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Author
                      Text(
                        podcast.title,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        podcast.author ?? Provider.of<LanguageProvider>(context, listen: false).t('common.unknown_author'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFBFAE01),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Stats Row
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildStatChip(
                            icon: Icons.favorite,
                            label: '${podcast.likes}',
                            color: Colors.pink.shade400,
                            isDark: isDark,
                          ),
                          _buildStatChip(
                            icon: Icons.play_arrow,
                            label: '${podcast.plays}',
                            color: Colors.green.shade400,
                            isDark: isDark,
                          ),
                          if (podcast.durationSec != null && podcast.durationSec! > 0)
                            _buildStatChip(
                              icon: Icons.schedule,
                              label: '${(podcast.durationSec! ~/ 60)}m',
                              color: Colors.blue.shade400,
                              isDark: isDark,
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Tags Section
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (podcast.category != null && podcast.category!.isNotEmpty)
                            _buildTag(podcast.category!, isDark),
                          if (podcast.language != null && podcast.language!.isNotEmpty)
                            _buildTag(podcast.language!.toUpperCase(), isDark),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // About Section
                      Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('podcasts.about'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        podcast.description ?? Provider.of<LanguageProvider>(context, listen: false).t('common.no_description'),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          label: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.play_now'),
                          icon: Icons.play_arrow,
                          isPrimary: true,
                          onPressed: (podcast.audioUrl ?? '').isNotEmpty
                              ? () {
                                  debugPrint('🎧 [PodcastDetails] Opening audio player');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(settings: const RouteSettings(name: 'podcast_player'), builder: (_) => PlayerPage(podcast: podcast)),
                                  );
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          label: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.add_to_playlist'),
                          icon: Icons.playlist_add,
                          isPrimary: false,
                          onPressed: () {
                            showAddToPlaylistSheet(context, podcast);
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTag(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isPrimary && !isDisabled
            ? const LinearGradient(
                colors: [Color(0xFFD4C100), Color(0xFFBFAE01)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isDisabled
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
            : null,
        border: isPrimary || isDisabled
            ? null
            : Border.all(
                color: const Color(0xFFBFAE01),
                width: 1.5,
              ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary && !isDisabled
              ? Colors.transparent
              : isDisabled
                  ? Colors.transparent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06)),
          foregroundColor: isDisabled
              ? (isDark ? Colors.grey : Colors.black45)
              : (isPrimary
                  ? Colors.black
                  : (isDark ? Colors.white : Colors.black)),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}