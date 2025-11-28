import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../repositories/interfaces/book_repository.dart';
import 'books_home_page.dart';
import 'book_details_page.dart';

class BookFavoritesPage extends StatefulWidget {
  const BookFavoritesPage({super.key});

  @override
  State<BookFavoritesPage> createState() => _BookFavoritesPageState();
}

class _BookFavoritesPageState extends State<BookFavoritesPage> {
  bool _loading = true;
  String? _error;
  List<Book> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bookRepo = context.read<BookRepository>();
      final bookModels = await bookRepo.listBooks(page: 1, limit: 100, isPublished: true);
      
      // Convert BookModel to Book
      final books = bookModels.map((m) => Book.fromModel(m)).toList();
      
      // Filter for favorite books (you can add a favorites field to the model)
      // For now, showing all books
      setState(() {
        _items = books;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load favorites: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text('My Favorite Books',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final book = _items[idx];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => BookDetailsPage(book: book),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      book.coverUrl!,
                                      width: 80,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 80,
                                        height: 100,
                                        color: const Color(0xFFBFAE01),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (book.author != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            book.author!,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: const Color(0xFFBFAE01),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
