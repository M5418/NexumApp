import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'books_home_page.dart' show Book;
import 'book_read_page.dart';
import 'book_play_page.dart';
import '../repositories/interfaces/book_repository.dart';
import '../repositories/interfaces/bookmark_repository.dart';
import '../repositories/models/bookmark_model.dart';

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
    final newLiked = !widget.book.meLiked;
    try {
      final bookRepo = context.read<BookRepository>();
      if (newLiked) {
        await bookRepo.likeBook(widget.book.id);
        if (!mounted) return;
        setState(() {
          book.meLiked = true;
          book.likes = book.likes + 1;
        });
      } else {
        await bookRepo.unlikeBook(widget.book.id);
        if (!mounted) return;
        setState(() {
          book.meLiked = false;
          book.likes = (book.likes - 1).clamp(0, 1 << 30);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    } finally {
      if (mounted) setState(() => _togglingLike = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final newFavorite = !widget.book.meFavorite;
    try {
      final bookRepo = context.read<BookRepository>();
      final bookmarkRepo = context.read<BookmarkRepository>();
      if (newFavorite) {
        await bookRepo.bookmarkBook(widget.book.id);
        // Save to bookmarks collection
        await bookmarkRepo.bookmarkBook(
          bookId: widget.book.id,
          title: widget.book.title,
          coverUrl: widget.book.coverUrl,
          authorName: widget.book.author,
        );
        if (!mounted) return;
        setState(() {
          book.meFavorite = true;
          book.favorites = book.favorites + 1;
        });
      } else {
        await bookRepo.unbookmarkBook(widget.book.id);
        // Remove from bookmarks collection
        await bookmarkRepo.removeBookmarkByItem(widget.book.id, BookmarkType.book);
        if (!mounted) return;
        setState(() {
          book.meFavorite = false;
          book.favorites = (book.favorites - 1).clamp(0, 1 << 30);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e')),
      );
    } finally {
      if (mounted) setState(() => _togglingFav = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    final coverAspect = isWide ? 0.75 : 1.2; // narrower on desktop
    final coverMaxWidth = isWide ? 250.0 : double.infinity;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                ),
                Expanded(
                  child: Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _togglingLike ? null : _toggleLike,
                  icon: Icon(
                    book.meLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink.shade300,
                  ),
                ),
                IconButton(
                  onPressed: _togglingFav ? null : _toggleFavorite,
                  icon: Icon(
                    book.meFavorite ? Icons.star : Icons.star_border,
                    color: const Color(0xFFBFAE01),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: coverMaxWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: coverAspect,
                  child: (book.coverUrl ?? '').isNotEmpty
                      ? Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                            child: const Center(
                              child: Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 48),
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                          child: const Center(
                            child: Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 48),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            book.author ?? 'Unknown',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666)),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            (book.category ?? '').isEmpty ? (book.language ?? '') : '${book.category} • ${book.language ?? ''}',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF999999)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: Colors.pink.shade300),
              const SizedBox(width: 4),
              Text('${book.likes}', style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.star, size: 16, color: Color(0xFFBFAE01)),
              const SizedBox(width: 4),
              Text('${book.favorites}', style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(width: 12),
              Icon(Icons.menu_book, size: 16, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 4),
              Text('${book.reads}', style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(width: 12),
              Icon(Icons.play_arrow, size: 16, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 4),
              Text('${book.plays}', style: GoogleFonts.inter(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          // Description fallback
          Text(
            'No description provided.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
            ),
          ),

          const SizedBox(height: 18),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: (book.pdfUrl ?? '').isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookReadPage(book: book)),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.menu_book_outlined, color: Colors.black),
                  label: Text(
                    'Read',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (book.audioUrl ?? '').isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookPlayPage(book: book)),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: Text(
                    'Play',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}