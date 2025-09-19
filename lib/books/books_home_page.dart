import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'book_details_page.dart';
import 'create_book_page.dart';
import 'book_play_page.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String pdfUrl;
  final String description;
  final String language;
  final DateTime addedAt;
  final int readingMinutes;
  final String content;
  bool isFavorite;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.pdfUrl,
    required this.description,
    required this.language,
    required this.addedAt,
    required this.readingMinutes,
    required this.content,
    this.isFavorite = false,
  });
}

class BookSampleData {
  static List<Book> all() {
    final now = DateTime.now();
    const para =
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ';
    return [
      Book(
        id: 'b1',
        title: '48 Laws of Power',
        author: 'Robert Greene',
        coverUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71aG+xDKSYL.jpg',
        pdfUrl:
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        description:
            'Concise manual for power dynamics and strategy in personal and professional life.',
        language: 'English',
        addedAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 34)),
        readingMinutes: 540,
        content: List.filled(120, para).join(),
      ),
      Book(
        id: 'b2',
        title: 'War in Pakistan',
        author: 'Ayesha Khan',
        coverUrl:
            'https://images.unsplash.com/photo-1524985069026-dd778a71c7b4?q=80&w=600&auto=format&fit=crop',
        pdfUrl:
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        description:
            'An investigative chronicle into the human and political cost of regional conflicts.',
        language: 'English',
        addedAt: now.subtract(const Duration(days: 2, hours: 5)),
        readingMinutes: 380,
        content: List.filled(90, para).join(),
      ),
      Book(
        id: 'b3',
        title: 'Les Secrets de la Réussite',
        author: 'Claire Dupont',
        coverUrl:
            'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?q=80&w=600&auto=format&fit=crop',
        pdfUrl:
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        description:
            'Un guide pratique pour développer une carrière épanouissante et alignée avec vos valeurs.',
        language: 'French',
        addedAt: now.subtract(const Duration(hours: 7, minutes: 10)),
        readingMinutes: 300,
        content: List.filled(80, para).join(),
      ),
      Book(
        id: 'b4',
        title: 'القوة الناعمة',
        author: 'سلمان العتيبي',
        coverUrl:
            'https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=600&auto=format&fit=crop',
        pdfUrl:
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        description:
            'مدخل لفهم تأثير القوة الثقافية والإعلامية في تشكيل النفوذ الدولي.',
        language: 'Arabic',
        addedAt: now.subtract(const Duration(days: 3, hours: 12)),
        readingMinutes: 420,
        content: List.filled(95, para).join(),
      ),
      Book(
        id: 'b5',
        title: 'El Arte de Emprender',
        author: 'Luis Ortega',
        coverUrl:
            'https://images.unsplash.com/photo-1485322551133-3a4c27a9d925?q=80&w=600&auto=format&fit=crop',
        pdfUrl:
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        description:
            'Estrategias prácticas para iniciar y escalar proyectos con impacto.',
        language: 'Spanish',
        addedAt: now.subtract(const Duration(days: 1, hours: 22)),
        readingMinutes: 265,
        content: List.filled(70, para).join(),
      ),
    ];
  }
}

class BooksHomePage extends StatefulWidget {
  const BooksHomePage({super.key});

  @override
  State<BooksHomePage> createState() => _BooksHomePageState();
}

class _BooksHomePageState extends State<BooksHomePage> {
  String _selectedLanguage = 'All';
  late List<Book> _books;

  @override
  void initState() {
    super.initState();
    _books = BookSampleData.all();
  }

  List<String> get _languages => [
    'All',
    'English',
    'French',
    'Arabic',
    'Spanish',
  ];

  List<Book> get _filteredBooks => _selectedLanguage == 'All'
      ? _books
      : _books.where((b) => b.language == _selectedLanguage).toList();

  String _timeAgo(DateTime d) {
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
    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(25),
            ),
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
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black,
                    ),
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
                  _LanguageFilter(
                    selected: _selectedLanguage,
                    options: _languages,
                    onChanged: (v) => setState(() => _selectedLanguage = v),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateBookPage(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.add,
                      color: isDark ? Colors.white : const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredBooks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final b = _filteredBooks[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
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
                          child: Image.network(
                            b.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFEAEAEA),
                              child: const Icon(
                                Icons.menu_book_outlined,
                                color: Color(0xFFBFAE01),
                                size: 24,
                              ),
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
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.author,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF999999),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b.description,
                                maxLines: 2,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _timeAgo(b.addedAt),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF999999),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${b.readingMinutes ~/ 60} hr, ${b.readingMinutes % 60} min',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: const Color(0xFF999999),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    b.language,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: const Color(0xFF999999),
                                    ),
                                  ),
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
                            const Icon(
                              Icons.star_border,
                              size: 20,
                              color: Color(0xFFBFAE01),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookPlayPage(book: b),
                                ),
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
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: PopupMenuButton<String>(
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (final o in options)
            PopupMenuItem<String>(
              value: o,
              child: Text(o, style: GoogleFonts.inter(fontSize: 13)),
            ),
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
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: Color(0xFFBFAE01),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
