import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'books_home_page.dart' show Book;
import 'books_api.dart';

class BookReadPage extends StatefulWidget {
  final Book book;
  const BookReadPage({super.key, required this.book});

  @override
  State<BookReadPage> createState() => _BookReadPageState();
}

class _BookReadPageState extends State<BookReadPage> {
  String? localPath;
  bool isLoading = true;
  String? errorMessage;
  int currentPage = 0;
  int totalPages = 0;
  int defaultPage = 0;

  @override
  void initState() {
    super.initState();
    _loadProgressThenPdf();
  }

  Future<void> _loadProgressThenPdf() async {
    await _loadProgress();
    await _downloadAndLoadPdf();
  }

  Future<void> _loadProgress() async {
    try {
      final api = BooksApi.create();
      final res = await api.getProgress(widget.book.id);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final p = d['progress'];
      if (p != null) {
        final lastPage = int.tryParse((p['last_page'] ?? 0).toString()) ?? 0;
        if (lastPage > 0) {
          defaultPage = (lastPage - 1).clamp(0, 1000000);
          currentPage = defaultPage;
        }
      }
    } catch (_) {
      // Ignore progress errors
    }
  }

  Future<void> _downloadAndLoadPdf() async {
    try {
      final pdfUrl = (widget.book.pdfUrl ?? '').isNotEmpty
          ? widget.book.pdfUrl!
          : 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';

      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/${widget.book.id}.pdf');
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to download PDF (Status: ${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading PDF: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _updateProgress() async {
    try {
      final api = BooksApi.create();
      // PDFView page index is 0-based, server expects 1-based page number.
      final page = (currentPage + 1).clamp(1, totalPages == 0 ? 1 : totalPages);
      await api.updateReadProgress(id: widget.book.id, page: page, totalPages: totalPages > 0 ? totalPages : null);
    } catch (_) {
      // Silently ignore
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
          if (!isLoading && localPath != null)
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white : Colors.black),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.white : Colors.black),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          _downloadAndLoadPdf();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              : PDFView(
                  filePath: localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: false,
                  pageFling: true,
                  pageSnap: true,
                  defaultPage: defaultPage,
                  fitPolicy: FitPolicy.WIDTH,
                  preventLinkNavigation: false,
                  onRender: (pages) {
                    setState(() {
                      totalPages = pages ?? 0;
                    });
                  },
                  onError: (error) {
                    setState(() {
                      errorMessage = 'PDF Error: $error';
                    });
                  },
                  onPageError: (page, error) {
                    setState(() {
                      errorMessage = 'Page Error: $error';
                    });
                  },
                  onViewCreated: (PDFViewController controller) {},
                  onLinkHandler: (String? uri) {},
                  onPageChanged: (int? page, int? total) {
                    setState(() {
                      currentPage = page ?? 0;
                    });
                    _updateProgress();
                  },
                ),
    );
  }
}