import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import 'books_home_page.dart' show Book;
import '../repositories/interfaces/book_repository.dart';

class BookReadPage extends StatefulWidget {
  final Book book;
  const BookReadPage({super.key, required this.book});

  @override
  State<BookReadPage> createState() => _BookReadPageState();
}

class _BookReadPageState extends State<BookReadPage> {
  final PdfViewerController _pdfController = PdfViewerController();

  bool isLoading = true;
  String? errorMessage;

  int currentPage = 0;   // 0-based for our state
  int totalPages = 0;
  int defaultPage = 0;   // 0-based for our state

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final bookRepo = context.read<BookRepository>();
      final progress = await bookRepo.getProgress(widget.book.id);
      if (progress != null && progress.currentPage > 0) {
        defaultPage = (progress.currentPage - 1).clamp(0, 1000000);
        currentPage = defaultPage;
        if (progress.totalPages > 0) {
          totalPages = progress.totalPages;
        }
      }
    } catch (_) {
      // ignore errors
    } finally {
      if (mounted) setState(() => isLoading = false);
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

    final pdfUrl = (widget.book.pdfUrl ?? '').isNotEmpty
        ? widget.book.pdfUrl!
        : 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';

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
              : SfPdfViewer.network(
                  pdfUrl,
                  controller: _pdfController,
                  canShowPaginationDialog: false,
                  onDocumentLoaded: (details) {
                    totalPages = details.document.pages.count;
                    // Jump to last read page (1-based for viewer)
                    if (defaultPage > 0) {
                      _pdfController.jumpToPage(defaultPage + 1);
                    }
                    setState(() {}); // refresh page count in AppBar
                  },
                  onPageChanged: (details) {
                    // details.newPageNumber is 1-based
                    currentPage = (details.newPageNumber - 1).clamp(0, totalPages > 0 ? totalPages - 1 : 0);
                    _updateProgress();
                  },
                ),
    );
  }
}