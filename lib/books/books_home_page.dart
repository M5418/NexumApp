import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../repositories/interfaces/book_repository.dart';
import 'book_details_page.dart';
import 'create_book_page.dart';
import 'book_search_page.dart';
import 'book_categories_page.dart';
import 'book_favorites_page.dart';
import '../responsive/responsive_breakpoints.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../core/admin_config.dart';
import '../core/i18n/language_provider.dart';

class Book {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final String? epubUrl;
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
    this.description,
    this.coverUrl,
    this.epubUrl,
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

  factory Book.fromModel(BookModel m) {
    return Book(
      id: m.id,
      title: m.title,
      author: m.author,
      description: m.description,
      coverUrl: m.coverUrl,
      epubUrl: m.epubUrl,
      pdfUrl: m.pdfUrl,
      audioUrl: m.audioUrl,
      language: m.language,
      category: m.category,
      tags: m.tags,
      price: m.price,
      isPublished: m.isPublished,
      readingMinutes: m.readingMinutes,
      audioDurationSec: m.audioDurationSec,
      createdAt: m.createdAt,
      likes: m.likeCount,
      favorites: m.isBookmarked ? 1 : 0,
      reads: m.viewCount,
      plays: 0,
      meLiked: m.isLiked,
      meFavorite: m.isBookmarked,
    );
  }
}

class BooksHomePage extends StatefulWidget {
  const BooksHomePage({super.key});

  @override
  State<BooksHomePage> createState() => _BooksHomePageState();
}

class _BooksHomePageState extends State<BooksHomePage> {
  final GlobalKey<NavigatorState> _rightNavKey = GlobalKey<NavigatorState>();
  late BookRepository _bookRepo;

  String _selectedLanguage = 'All';
  bool _hasInitializedLanguage = false;
  List<Book> _books = [];
  bool _loading = true;
  String? _error;

  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;
  final _controller = ScrollController();

  // Desktop search
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bookRepo = context.read<BookRepository>();
    _fetchBooks(reset: true);
    _controller.addListener(_onScroll);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedLanguage) {
      _initializeLanguageFilter();
      _hasInitializedLanguage = true;
    }
  }
  
  void _initializeLanguageFilter() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final userLanguageCode = languageProvider.code;
    
    // Map language code to display name
    final languageMap = {
      'en': 'English',
      'fr': 'Français',
      'pt': 'Português',
      'es': 'Español',
      'de': 'Deutsch',
    };
    
    final preferredLanguage = languageMap[userLanguageCode];
    
    // Set to user's preferred language if available in books, otherwise keep 'All'
    if (preferredLanguage != null && _languages.contains(preferredLanguage)) {
      setState(() {
        _selectedLanguage = preferredLanguage;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _languages {
    final set = <String>{'All'};
    for (final b in _books) {
      if ((b.language ?? '').isNotEmpty) set.add(b.language!);
    }
    return set.toList();
  }

  List<Book> get _filteredBooks =>
      _selectedLanguage == 'All' ? _books : _books.where((b) => (b.language ?? '') == _selectedLanguage).toList();

  List<Book> get _filteredDesktopBooks {
    final base = _filteredBooks;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((b) {
      final t = b.title.toLowerCase();
      final a = (b.author ?? '').toLowerCase();
      return t.contains(q) || a.contains(q);
    }).toList();
  }

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
      final bookModels = await _bookRepo.listBooks(
        page: _page,
        limit: _limit,
        isPublished: true,
      );
      final newBooks = bookModels.map(Book.fromModel).toList();

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

  Future<void> _openCreateMobile() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateBookPage()),
    );
    if (changed == true && mounted) {
      await _fetchBooks(reset: true);
    }
  }

  Future<void> _openCreateDesktop() async {
    final changed = await CreateBookPage.showPopup<bool>(context);
    if (changed == true && mounted) {
      await _fetchBooks(reset: true);
    }
  }

  void _openInRightPanel(Book b) {
    _rightNavKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => BookDetailsPage(book: b)),
      (route) => false,
    );
  }

  void _openCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookCategoriesPage()),
    );
  }

  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookFavoritesPage()),
    );
  }

   @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop || context.isLargeDesktop;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  // Desktop header: back + "NEXUM"
  Widget _buildDesktopHeader(bool isDark) {
    final barColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    return Material(
      color: barColor,
      elevation: isDark ? 0 : 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
            Text(
              'NEXUM',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // Desktop (Web) two-column
  // =========================
  Widget _buildDesktop(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDesktopHeader(isDark),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column: search + language + list + create
                        Container(
                          width: 360,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Row: Search + Language + Add
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _searchCtrl,
                                          onChanged: (v) => setState(() => _query = v),
                                          decoration: InputDecoration(
                                            hintText: 'Search books...',
                                            hintStyle: GoogleFonts.inter(color: const Color(0xFF999999), fontSize: 13),
                                            border: InputBorder.none,
                                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFBFAE01)),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                          style: GoogleFonts.inter(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _LanguageFilter(
                                      selected: _selectedLanguage,
                                      options: _languages,
                                      onChanged: (v) => setState(() => _selectedLanguage = v),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Create book',
                                      onPressed: _openCreateDesktop,
                                      icon: Icon(Icons.add, color: isDark ? Colors.white : const Color(0xFF666666)),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              // List of books
                              Expanded(
                                child: _error != null
                                    ? ListView(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)),
                                          ),
                                        ],
                                      )
                                    : RefreshIndicator(
                                        color: const Color(0xFFBFAE01),
                                        onRefresh: () => _fetchBooks(reset: true),
                                        child: ListView.separated(
                                          controller: _controller,
                                          padding: const EdgeInsets.all(12),
                                          itemCount: _filteredDesktopBooks.length + (_loading ? 1 : 0),
                                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                                          itemBuilder: (ctx, idx) {
                                            if (idx >= _filteredDesktopBooks.length) {
                                              return const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                                                ),
                                              );
                                            }
                                            final b = _filteredDesktopBooks[idx];
                                            return GestureDetector(
                                              onTap: () => _openInRightPanel(b),
                                              child: Container(
                                                width: 360,
                                                height: 140,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    if (!isDark)
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.06),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
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
                                                            Text(
                                                              b.author ?? 'Unknown',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 13,
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
                                                                Text('${b.likes}',
                                                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                                                const SizedBox(width: 10),
                                                                const Icon(Icons.star, size: 14, color: Color(0xFFBFAE01)),
                                                                const SizedBox(width: 4),
                                                                Text('${b.favorites}',
                                                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                                                const SizedBox(width: 10),
                                                                Icon(Icons.menu_book, size: 14, color: isDark ? Colors.white : Colors.black),
                                                                const SizedBox(width: 4),
                                                                Text('${b.reads}',
                                                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                                                const SizedBox(width: 10),
                                                                Icon(Icons.play_arrow, size: 14, color: isDark ? Colors.white : Colors.black),
                                                                const SizedBox(width: 4),
                                                                Text('${b.plays}',
                                                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
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
                                                            onPressed: () {
                                                              setState(() {
                                                                b.meFavorite = !b.meFavorite;
                                                                b.favorites = b.meFavorite
                                                                    ? b.favorites + 1
                                                                    : (b.favorites - 1).clamp(0, 1 << 30);
                                                              });
                                                            },
                                                            icon: Icon(
                                                              b.meFavorite ? Icons.star : Icons.star_border,
                                                              size: 22,
                                                              color: const Color(0xFFBFAE01),
                                                            ),
                                                          ),
                                                          GestureDetector(
                                                            onTap: () => _openInRightPanel(b),
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
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right panel: nested Navigator to show details/read/play
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: isDark ? Colors.black : Colors.white,
                              child: Navigator(
                                key: _rightNavKey,
                                onGenerateInitialRoutes: (_, __) {
                                  return [
                                    MaterialPageRoute(
                                      builder: (_) => const _BooksPlaceholder(),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
    // =========================
  // Mobile (unchanged)
  // =========================
  Widget _buildMobile(BuildContext context) {
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
                  const SizedBox(width: 8),
                  _LanguageFilter(
                    selected: _selectedLanguage,
                    options: _languages,
                    onChanged: (v) => setState(() => _selectedLanguage = v),
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
            : Column(
                children: [
                  // Quick action chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickActionChip(
                            icon: Icons.category_outlined,
                            label: 'Categories',
                            isDark: isDark,
                            onTap: _openCategories,
                          ),
                          const SizedBox(width: 8),
                          if (AdminConfig.isAdmin(fb.FirebaseAuth.instance.currentUser?.uid))
                            _QuickActionChip(
                              icon: Icons.add_circle_outline,
                              label: 'Add Book',
                              isDark: isDark,
                              onTap: _openCreateMobile,
                            ),
                          const SizedBox(width: 8),
                          _QuickActionChip(
                            icon: Icons.favorite_border,
                            label: 'Favorites',
                            isDark: isDark,
                            onTap: _openFavorites,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
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
                              color: Colors.black.withValues (alpha: 0),
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
                                      onPressed: () {
                                        // toggled locally in list item
                                        setState(() {
                                          b.meFavorite = !b.meFavorite;
                                          b.favorites =
                                              b.meFavorite ? b.favorites + 1 : (b.favorites - 1).clamp(0, 1 << 30);
                                        });
                                      },
                                      icon: const Icon(Icons.star_border, size: 22, color: Color(0xFFBFAE01)),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (ctx) => BookDetailsPage(book: b)),
                                      ),
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
                ],
              ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFBFAE01)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
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

class _BooksPlaceholder extends StatelessWidget {
  const _BooksPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Text(
          'Select a book from the left list',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: isDark ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}