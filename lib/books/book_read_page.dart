import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'books_home_page.dart' show Book;
import '../repositories/interfaces/book_repository.dart';

class BookReadPage extends StatefulWidget {
  final Book book;
  const BookReadPage({super.key, required this.book});

  @override
  State<BookReadPage> createState() => _BookReadPageState();
}

class _BookReadPageState extends State<BookReadPage> {
  PdfControllerPinch? _pdfController;

  bool isLoading = true;
  String? errorMessage;

  int currentPage = 0;   // 0-based for our state
  int totalPages = 0;
  int defaultPage = 0;   // 0-based for our state

  @override
  void initState() {
    super.initState();
    _loadPdfAndProgress();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdfAndProgress() async {
    try {
      // Load progress first
      final bookRepo = context.read<BookRepository>();
      final progress = await bookRepo.getProgress(widget.book.id);
      if (progress != null && progress.currentPage > 0) {
        defaultPage = (progress.currentPage - 1).clamp(0, 1000000);
        currentPage = defaultPage;
        if (progress.totalPages > 0) {
          totalPages = progress.totalPages;
        }
      }

      // Load PDF document
      final pdfUrl = widget.book.pdfUrl;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        throw Exception('No PDF URL available');
      }

      // Create PdfControllerPinch with Future<PdfDocument>
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(
          DefaultCacheManager().getSingleFile(pdfUrl).then((file) => file.readAsBytes()),
        ),
        initialPage: defaultPage + 1, // PdfControllerPinch uses 1-based pages
      );

      // Wait for document to load to get page count
      final document = await _pdfController!.document;

      totalPages = document.pagesCount;
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint('📖 [PDF] Error loading: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load PDF: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProgress() async {
    if (currentPage == 0 || totalPages == 0) return;
    try {
      final bookRepo = context.read<BookRepository>();
      await bookRepo.updateProgress(
        bookId: widget.book.id,
        currentPage: currentPage,
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);


    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.book.title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          if (!isLoading && totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white : Colors.black),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.white : Colors.black),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _pdfController == null
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
                  : PdfViewPinch(
                      controller: _pdfController!,
                      onPageChanged: (page) {
                        currentPage = (page - 1).clamp(0, totalPages > 0 ? totalPages - 1 : 0);
                        setState(() {}); // Update page counter in AppBar
                        _updateProgress();
                      },
                      onDocumentError: (error) {
                        debugPrint('📖 [PDF] Document error: $error');
                        setState(() {
                          errorMessage = 'Error displaying PDF: $error';
                        });
                      },
                    ),
    );
  }
}