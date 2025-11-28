import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../repositories/interfaces/book_repository.dart';

class BookCategoriesPage extends StatefulWidget {
  const BookCategoriesPage({super.key});

  @override
  State<BookCategoriesPage> createState() => _BookCategoriesPageState();
}

class _BookCategoriesPageState extends State<BookCategoriesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bookRepo = context.read<BookRepository>();
      
      // Fetch all published books
      final bookModels = await bookRepo.listBooks(
        page: 1,
        limit: 1000, // Get all books to count categories
        isPublished: true,
      );
      
      // Aggregate categories and count
      final categoryMap = <String, int>{};
      for (final book in bookModels) {
        final category = book.category?.trim() ?? '';
        if (category.isNotEmpty) {
          // Handle multi-category (comma-separated)
          final categories = category.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty);
          for (final cat in categories) {
            categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
          }
        }
      }
      
      // Convert to list and sort by count
      final categoryList = categoryMap.entries
          .map((e) => {'category': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      setState(() {
        _cats = categoryList;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories: $e';
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
        title: Text('Book Categories',
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
                                    '$count book${count == 1 ? '' : 's'}',
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
