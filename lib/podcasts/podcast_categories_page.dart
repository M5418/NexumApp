import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/interest_domains.dart';
import 'podcast_sample_data.dart';
import 'podcasts_home_page.dart';

class PodcastCategoriesPage extends StatelessWidget {
  const PodcastCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'Categories',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35, // taller cards -> no bottom overflow
        ),
        itemCount: interestDomains.length,
        itemBuilder: (context, i) {
          final domain = interestDomains[i];
          final count = PodcastSampleData.byDomain(domain).length;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PodcastCategoryFeedPage(
                  title: domain,
                  podcasts: PodcastSampleData.byDomain(domain),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 13),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFAE01),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    domain,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '$count',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Color(0xFFBFAE01)),
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