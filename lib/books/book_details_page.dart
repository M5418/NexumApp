import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'books_home_page.dart' show Book;
import 'book_read_page.dart';
import 'book_play_page.dart';
import '../repositories/interfaces/bookmark_repository.dart';

class BookDetailsPage extends StatefulWidget {
  final Book book;
  const BookDetailsPage({super.key, required this.book});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  late Book book;
  bool _togglingLike = false;
  bool _togglingFav = false;

  @override
  void initState() {
    super.initState();
    book = widget.book;
  }

  Future<void> _toggleLike() async {
    if (_togglingLike) return;
    setState(() => _togglingLike = true);
    try {
      final bookmarkRepo = context.read<BookmarkRepository>();
      if (book.meLiked) {
        await bookmarkRepo.removeBookmark(book.id);
        setState(() {
          book.meLiked = false;
          book.likes = (book.likes - 1).clamp(0, 999999);
        });
      } else {
        // Just increment locally - simplified for now
        setState(() {
          book.meLiked = true;
          book.likes = (book.likes + 1).clamp(0, 999999);
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    } finally {
      if (mounted) setState(() => _togglingLike = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_togglingFav) return;
    setState(() => _togglingFav = true);
    try {
      final bookmarkRepo = context.read<BookmarkRepository>();
      if (book.meFavorite) {
        await bookmarkRepo.removeBookmark(book.id);
        setState(() {
          book.meFavorite = false;
          book.favorites = (book.favorites - 1).clamp(0, 999999);
        });
      } else {
        // Just increment locally - simplified for now
        setState(() {
          book.meFavorite = true;
          book.favorites = (book.favorites + 1).clamp(0, 999999);
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    } finally {
      if (mounted) setState(() => _togglingFav = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    // Debug logging
    debugPrint('📚 [BookDetails] Book: ${book.title}');
    debugPrint('📚 [BookDetails] PDF URL: ${book.pdfUrl ?? "null"}');
    debugPrint('📚 [BookDetails] Audio URL: ${book.audioUrl ?? "null"}');
    
    // Determine which format is available for reading
    final hasPdf = (book.pdfUrl ?? '').isNotEmpty;

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
                book.meLiked ? Icons.favorite : Icons.favorite_border,
                color: book.meLiked ? Colors.pink.shade400 : Colors.white,
                size: 20,
              ),
            ),
          ),
          IconButton(
            onPressed: _togglingFav ? null : _toggleFavorite,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                book.meFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: book.meFavorite ? const Color(0xFFBFAE01) : Colors.white,
                size: 20,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            ),
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
                if ((book.coverUrl ?? '').isNotEmpty)
                  Image.network(
                    book.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 80),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 80),
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
                        book.title,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.author ?? 'Unknown Author',
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
                            label: '${book.likes}',
                            color: Colors.pink.shade400,
                            isDark: isDark,
                          ),
                          _buildStatChip(
                            icon: Icons.visibility,
                            label: '${book.reads}',
                            color: Colors.green.shade400,
                            isDark: isDark,
                          ),
                          if (book.readingMinutes != null)
                            _buildStatChip(
                              icon: Icons.schedule,
                              label: '${book.readingMinutes}m',
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
                          if (book.category != null && book.category!.isNotEmpty)
                            _buildTag(book.category!, isDark),
                          if (book.language != null && book.language!.isNotEmpty)
                            _buildTag(book.language!.toUpperCase(), isDark),
                          ...book.tags.take(3).map((tag) => _buildTag(tag, isDark)),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // About Section
                      Text(
                        'About',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.description ?? 'No description available.',
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
                          label: 'Start Reading',
                          icon: Icons.auto_stories,
                          isPrimary: true,
                          onPressed: hasPdf
                              ? () {
                                  debugPrint('📖 [BookDetails] Opening PDF reader');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => BookReadPage(book: book)),
                                  );
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          label: 'Listen Now',
                          icon: Icons.headphones,
                          isPrimary: false,
                          onPressed: () {
                            debugPrint('🎧 [BookDetails] Opening audio player');
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BookPlayPage(book: book)),
                            );
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
