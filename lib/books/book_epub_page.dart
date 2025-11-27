import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vocsy_epub_viewer/epub_viewer.dart';
import 'books_home_page.dart' show Book;

class BookEpubPage extends StatefulWidget {
  final Book book;
  const BookEpubPage({super.key, required this.book});

  @override
  State<BookEpubPage> createState() => _BookEpubPageState();
}

class _BookEpubPageState extends State<BookEpubPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  Future<void> _loadEpub() async {
    try {
      final epubUrl = widget.book.epubUrl;
      if (epubUrl == null || epubUrl.isEmpty) {
        setState(() {
          _error = 'No EPUB URL available';
          _loading = false;
        });
        return;
      }

      debugPrint('📖 [EPUB] Loading from URL: $epubUrl');

      // Configure the EPUB viewer
      VocsyEpub.setConfig(
        themeColor: const Color(0xFFBFAE01),
        identifier: 'book_${widget.book.id}',
        scrollDirection: EpubScrollDirection.ALLDIRECTIONS,
        allowSharing: true,
        enableTts: true,
        nightMode: false,
      );

      // Open the EPUB file
      VocsyEpub.open(
        epubUrl,
        lastLocation: null, // TODO: Save/restore reading position
      );
      
      debugPrint('📖 [EPUB] Opened successfully');
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('📖 [EPUB] Exception: $e');
      setState(() {
        _error = 'Error loading EPUB: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(widget.book.title, style: GoogleFonts.inter()),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(widget.book.title, style: GoogleFonts.inter()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadEpub();
                },
                icon: const Icon(Icons.refresh),
                label: Text('Retry', style: GoogleFonts.inter()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // EPUB viewer opens in its own activity/view controller
    // This page is just a placeholder that gets replaced
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.book.title, style: GoogleFonts.inter()),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
      ),
    );
  }
}
