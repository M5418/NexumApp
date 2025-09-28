import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'book_details_page.dart';
import 'create_book_page.dart';
import 'books_api.dart';
import 'book_search_page.dart';

class Book {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? pdfUrl;
  final String? audioUrl;
  final String? language;
  final String? category;
  final List<String> tags;
  final double? price;
  final bool isPublished;
  final int? readingMinutes;
  final int? audioDurationSec;
  final DateTime? createdAt;

  int likes;
  int favorites;
  int reads;
  int plays;
  bool meLiked;
  bool meFavorite;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.pdfUrl,
    this.audioUrl,
    this.language,
    this.category,
    this.tags = const [],
    this.price,
    this.isPublished = false,
    this.readingMinutes,
    this.audioDurationSec,
    this.createdAt,
    this.likes = 0,
    this.favorites = 0,
    this.reads = 0,
    this.plays = 0,
    this.meLiked = false,
    this.meFavorite = false,
  });

  factory Book.fromApi(Map<String, dynamic> m) {
    final counts = Map<String, dynamic>.from(m['counts'] ?? {});
    final me = Map<String, dynamic>.from(m['me'] ?? {});
    return Book(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      author: m['author']?.toString(),
      coverUrl: (m['coverUrl'] ?? '').toString().isEmpty ? null : (m['coverUrl'] as String),
      pdfUrl: (m['pdfUrl'] ?? '').toString().isEmpty ? null : (m['pdfUrl'] as String),
      audioUrl: (m['audioUrl'] ?? '').toString().isEmpty ? null : (m['audioUrl'] as String),
      language: m['language']?.toString(),
      category: m['category']?.toString(),
      tags: List<String>.from((m['tags'] ?? const []) as List),
      price: m['price'] == null ? null : double.tryParse(m['price'].toString()),
      isPublished: (m['isPublished'] ?? false) == true,
      readingMinutes: m['readingMinutes'] == null ? null : int.tryParse(m['readingMinutes'].toString()),
      audioDurationSec: m['audioDurationSec'] == null ? null : int.tryParse(m['audioDurationSec'].toString()),
      createdAt: m['createdAt'] != null ? DateTime.tryParse(m['createdAt'].toString()) : null,
      likes: int.tryParse((counts['likes'] ?? 0).toString()) ?? 0,
      favorites: int.tryParse((counts['favorites'] ?? 0).toString()) ?? 0,
      reads: int.tryParse((counts['reads'] ?? 0).toString()) ?? 0,
      plays: int.tryParse((counts['plays'] ?? 0).toString()) ?? 0,
      meLiked: (me['liked'] ?? false) == true,
      meFavorite: (me['favorite'] ?? false) == true,
    );
  }
}

class BooksHomePage extends StatefulWidget {
  const BooksHomePage({super.key});

  @override
  State<BooksHomePage> createState() => _BooksHomePageState();
}

class _BooksHomePageState extends State<BooksHomePage> {
  String _selectedLanguage = 'All';
  List<Book> _books = [];
  bool _loading = true;
  String? _error;

  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchBooks(reset: true);
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _languages {
    final set = <String>{'All'};
    for (final b in _books) {
      if ((b.language ?? '').isNotEmpty) set.add(b.language!);
    }
    return set.toList();
  }

  List<Book> get _filteredBooks => _selectedLanguage == 'All'
      ? _books
      : _books.where((b) => (b.language ?? '') == _selectedLanguage).toList();

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200) {
      _fetchBooks(reset: false);
    }
  }

  Future<void> _fetchBooks({required bool reset}) async {
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _page = 1;
        _books = [];
        _hasMore = true;
      }
    });
    try {
      final api = BooksApi.create();
      final res = await api.listBooks(page: _page, limit: _limit, isPublished: true);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['books'] ?? const []);
      final newBooks = list.map(Book.fromApi).toList();

      setState(() {
        _books.addAll(newBooks);
        _hasMore = newBooks.length >= _limit;
        _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load books: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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

  Future<void> _openCreate() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateBookPage()),
    );
    if (changed == true && mounted) {
      await _fetchBooks(reset: true);
    }
  }

  Future<void> _toggleFavorite(Book b) async {
    try {
      final api = BooksApi.create();
      if (b.meFavorite) {
        await api.unfavorite(b.id);
        setState(() {
          b.meFavorite = false;
          b.favorites = (b.favorites - 1).clamp(0, 1 << 30);
        });
      } else {
        await api.favorite(b.id);
        setState(() {
          b.meFavorite = true;
          b.favorites = b.favorites + 1;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  ),
                  Text(
                    'Books',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookSearchPage()),
                      );
                    },
                    icon: Icon(Icons.search, color: isDark ? Colors.white : const Color(0xFF666666)),
                  ),
                  _LanguageFilter(
                    selected: _selectedLanguage,
                    options: _languages,
                    onChanged: (v) => setState(() => _selectedLanguage = v),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _openCreate,
                    icon: Icon(Icons.add, color: isDark ? Colors.white : const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFBFAE01),
        onRefresh: () => _fetchBooks(reset: true),
        child: _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)),
                  ),
                ],
              )
            : ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.all(16),
                itemCount: _filteredBooks.length + (_loading ? 1 : 0),
                separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  if (idx >= _filteredBooks.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                      ),
                    );
                  }
                  final b = _filteredBooks[idx];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (ctx) => BookDetailsPage(book: b)),
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
                              color: Colors.black.withValues(alpha: 0),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: SizedBox(
                                  width: 80,
                                  height: 140,
                                  child: b.coverUrl != null && b.coverUrl!.isNotEmpty
                                      ? Image.network(
                                          b.coverUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, error, stackTrace) => Container(
                                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                            child: const Icon(
                                              Icons.menu_book_outlined,
                                              color: Color(0xFFBFAE01),
                                              size: 24,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                          child: const Icon(
                                            Icons.menu_book_outlined,
                                            color: Color(0xFFBFAE01),
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              b.title,
                                              maxLines: 2,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        b.author ?? 'Unknown',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFF999999),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _timeAgo(b.createdAt),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: const Color(0xFF999999),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            (b.language ?? '').isEmpty ? '—' : b.language!,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: const Color(0xFF999999),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.favorite, size: 14, color: Colors.pink.shade300),
                                          const SizedBox(width: 4),
                                          Text('${b.likes}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                          const SizedBox(width: 10),
                                          Icon(Icons.star, size: 14, color: const Color(0xFFBFAE01)),
                                          const SizedBox(width: 4),
                                          Text('${b.favorites}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                          const SizedBox(width: 10),
                                          Icon(Icons.menu_book, size: 14, color: isDark ? Colors.white : Colors.black),
                                          const SizedBox(width: 4),
                                          Text('${b.reads}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                          const SizedBox(width: 10),
                                          Icon(Icons.play_arrow, size: 14, color: isDark ? Colors.white : Colors.black),
                                          const SizedBox(width: 4),
                                          Text('${b.plays}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      onPressed: () => _toggleFavorite(b),
                                      icon: Icon(
                                        b.meFavorite ? Icons.star : Icons.star_border,
                                        size: 22,
                                        color: const Color(0xFFBFAE01),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => b.audioUrl != null && b.audioUrl!.isNotEmpty
                                          ? Navigator.push(
                                              ctx,
                                              MaterialPageRoute(
                                                builder: (ctx) => BookDetailsPage(book: b),
                                              ),
                                            )
                                          : null,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFBFAE01),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.black,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _LanguageFilter extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _LanguageFilter({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
      ),
      child: PopupMenuButton<String>(
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (final o in options) PopupMenuItem<String>(value: o, child: Text(o, style: GoogleFonts.inter(fontSize: 13))),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.translate, size: 16, color: Color(0xFFBFAE01)),
              const SizedBox(width: 6),
              Text(
                selected,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFFBFAE01)),
            ],
          ),
        ),
      ),
    );
  }
}