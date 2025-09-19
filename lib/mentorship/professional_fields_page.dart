import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/mentorship_data.dart';
import 'request_mentorship_page.dart';

class ProfessionalFieldsPage extends StatefulWidget {
  const ProfessionalFieldsPage({super.key});

  @override
  State<ProfessionalFieldsPage> createState() => _ProfessionalFieldsPageState();
}

class _ProfessionalFieldsPageState extends State<ProfessionalFieldsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final surfaceColor = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final secondaryTextColor = const Color(0xFF666666);

    final fields = MentorshipData.getProfessionalFields();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          'Professional Fields',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your area of interest to find mentors',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fields.length,
              itemBuilder: (context, index) {
                final field = fields[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 13),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getFieldColor(
                            field.name,
                          ).withValues(alpha: 26),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            field.icon,
                            style: TextStyle(
                              fontSize: 28,
                              color: _getFieldColor(field.name),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getFieldDescription(field.name),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RequestMentorshipPage(fieldName: field.name),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Request',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getFieldColor(String fieldName) {
    switch (fieldName.toLowerCase()) {
      case 'finance':
        return const Color(0xFFFFB800);
      case 'business':
        return const Color(0xFF8B4513);
      case 'tech':
        return const Color(0xFF4CAF50);
      case 'marketing':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFFBFAE01);
    }
  }

  String _getFieldDescription(String fieldName) {
    switch (fieldName.toLowerCase()) {
      case 'finance':
        return 'Learn about investing, financial planning, budgeting, and wealth management from experienced professionals.';
      case 'business':
        return 'Get guidance on entrepreneurship, business strategy, leadership, and scaling your business ventures.';
      case 'tech':
        return 'Advance your technical skills, learn about software development, AI, and emerging technologies.';
      case 'marketing':
        return 'Master digital marketing, brand building, content strategy, and customer acquisition techniques.';
      default:
        return 'Connect with experienced mentors in this field to accelerate your professional growth.';
    }
  }
}
