import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'books_home_page.dart' show Book; // reuse Book.fromApi + Book model
import 'book_details_page.dart';
import '../repositories/interfaces/book_repository.dart'; // reuse Book.fromApi + Book model

class BookSearchPage extends StatefulWidget {
  const BookSearchPage({super.key});

  @override
  State<BookSearchPage> createState() => _BookSearchPageState();
}

class _BookSearchPageState extends State<BookSearchPage> {
  final TextEditingController _controller = TextEditingController();
  late BookRepository _bookRepo;

  bool _loading = false;
  String? _error;
  List<Book> _results = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bookRepo = context.read<BookRepository>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _results = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookModels = await _bookRepo.searchBooks(q);
      final newBooks = bookModels.map(Book.fromModel).toList();

      if (!mounted) return;
      setState(() {
        _results = newBooks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed: $e';
        _loading = false;
      });
    }
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays >= 1) return 'Yesterday';
    if (diff.inHours >= 1) return '${diff.inHours} hr';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final appBarBg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: appBarBg,
          elevation: 5,
          automaticallyImplyLeading: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Row(
                children: [
                  // Back
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF666666),
                        width: 0.6,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Color(0xFF666666),
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search field
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF666666).withValues(alpha: 0.0),
                          width: 0.6,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: Color(0xFF666666)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _onQueryChanged,
                              style: GoogleFonts.inter(fontSize: 15),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Search books...',
                                hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() {
                                  _results = const [];
                                  _error = null;
                                });
                              },
                              child: const Icon(Icons.close, size: 18, color: Color(0xFF666666)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: GoogleFonts.inter(fontSize: 14, color: Colors.red)),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_controller.text.isEmpty) {
      return _hint('Start typing to search books');
    }
    if (_results.isEmpty) {
      return _hint('No books found');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final b = _results[idx];
        return GestureDetector(
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => BookDetailsPage(book: b)),
          ),
          child: Container(
            width: 360,
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.0),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Cover
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: 80,
                    height: 140,
                    child: (b.coverUrl ?? '').isNotEmpty
                        ? Image.network(
                            b.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, _, __) => Container(
                              color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                              child: const Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 24),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                            child: const Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 24),
                          ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title
                        Text(
                          b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Author
                        Text(
                          b.author ?? 'Unknown',
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF999999)),
                        ),
                        const SizedBox(height: 4),
                        // Meta row: time ago + language
                        Row(
                          children: [
                            Text(
                              _timeAgo(b.createdAt),
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF999999)),
                            ),
                            const Spacer(),
                            Text(
                              (b.language ?? '').isEmpty ? '—' : b.language!,
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF999999)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hint(String text) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF666666)),
      ),
    );
  }
}