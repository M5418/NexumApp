import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../repositories/interfaces/book_repository.dart';
import '../repositories/firebase/firebase_book_repository.dart';
import '../core/i18n/language_provider.dart';

class BookCategoriesPage extends StatefulWidget {
  const BookCategoriesPage({super.key});

  @override
  State<BookCategoriesPage> createState() => _BookCategoriesPageState();
}

class _BookCategoriesPageState extends State<BookCategoriesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cats = [];
  
  // FASTFEED: Direct repository access for cache-first loading
  final FirebaseBookRepository _firebaseBookRepo = FirebaseBookRepository();

  @override
  void initState() {
    super.initState();
    // FASTFEED: Load cached categories instantly, then refresh
    _loadFromCacheInstantly();
    _load();
  }

  /// INSTANT: Load cached books and extract categories (no network wait)
  Future<void> _loadFromCacheInstantly() async {
    try {
      final bookModels = await _firebaseBookRepo.listBooksFromCache(
        limit: 500,
        isPublished: true,
      );
      if (bookModels.isNotEmpty && mounted) {
        final categoryList = _buildCategoryList(bookModels);
        setState(() {
          _cats = categoryList;
          _loading = false;
        });
      }
    } catch (_) {
      // Cache miss - will load from server
    }
  }

  List<Map<String, dynamic>> _buildCategoryList(List<BookModel> books) {
    final categoryMap = <String, int>{};
    for (final book in books) {
      final category = book.category?.trim() ?? '';
      if (category.isNotEmpty) {
        final categories = category.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty);
        for (final cat in categories) {
          categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        }
      }
    }
    return categoryMap.entries
        .map((e) => {'category': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  Future<void> _load() async {
    if (_cats.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final bookRepo = context.read<BookRepository>();
      final bookModels = await bookRepo.listBooks(
        page: 1,
        limit: 1000,
        isPublished: true,
      );
      
      final categoryList = _buildCategoryList(bookModels);
      
      setState(() {
        _cats = categoryList;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (_cats.isEmpty) {
        setState(() {
          _error = 'Failed to load categories: $e';
          _loading = false;
        });
      }
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
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('books.book_categories'),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final c = _cats[idx];
                    final name = (c['category'] ?? '').toString();
                    final count = int.tryParse((c['count'] ?? 0).toString()) ?? 0;
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    
                    return GestureDetector(
                      onTap: () {
                        // Navigate to category filtered books
                        Navigator.pop(context, name);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.category_outlined,
                                color: Color(0xFFBFAE01),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '$count ${count == 1 ? Provider.of<LanguageProvider>(context, listen: false).t('books.book_count') : Provider.of<LanguageProvider>(context, listen: false).t('books.books_count')}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
