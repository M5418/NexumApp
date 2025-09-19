import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ReportReason {
  poorEngagement,
  irrelevantContent,
  overposting,
  harmfulContent,
  privacyViolation,
}

class ReportOption {
  final ReportReason reason;
  final String title;
  final String description;

  ReportOption({
    required this.reason,
    required this.title,
    required this.description,
  });
}

class ReportBottomSheet extends StatefulWidget {
  final String postId;
  final String authorName;
  final Function(String postId, ReportReason reason, String comment)? onReport;

  const ReportBottomSheet({
    super.key,
    required this.postId,
    required this.authorName,
    this.onReport,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();

  static void show(
    BuildContext context, {
    required String postId,
    required String authorName,
    Function(String postId, ReportReason reason, String comment)? onReport,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReportBottomSheet(
        postId: postId,
        authorName: authorName,
        onReport: onReport,
      ),
    );
  }
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  ReportReason? _selectedReason;
  bool _isSubmitting = false;
  final TextEditingController _commentController = TextEditingController();

  final List<ReportOption> _reportOptions = [
    ReportOption(
      reason: ReportReason.poorEngagement,
      title: 'Poor Engagement',
      description:
          'This post doesn\'t engage their audience or lacks meaningful content.',
    ),
    ReportOption(
      reason: ReportReason.irrelevantContent,
      title: 'Irrelevant Content',
      description:
          'Content doesn\'t match the community or platform guidelines.',
    ),
    ReportOption(
      reason: ReportReason.overposting,
      title: 'Overposting',
      description: 'User posts too frequently or spams the feed.',
    ),
    ReportOption(
      reason: ReportReason.harmfulContent,
      title: 'Harmful Content',
      description:
          'Contains false or harmful information that violates our policies.',
    ),
    ReportOption(
      reason: ReportReason.privacyViolation,
      title: 'Privacy Violation',
      description: 'Shares private information without consent.',
    ),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _selectReason(ReportReason reason) {
    setState(() {
      _selectedReason = reason;
    });
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() {
      _isSubmitting = true;
    });

    // Simulate processing time
    await Future.delayed(const Duration(seconds: 2));

    widget.onReport?.call(
      widget.postId,
      _selectedReason!,
      _commentController.text,
    );

    if (mounted) {
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report submitted successfully. We\'ll review this content.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'What\'s wrong with this post?',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          const SizedBox(height: 20),

          // Report options
          ...(_reportOptions.map(
            (option) => _buildReportOption(option, isDark),
          )),

          const SizedBox(height: 20),

          // Comment text field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Additional details (optional)',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
            ),
          ),

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason != null && !_isSubmitting
                  ? _submitReport
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedReason != null
                    ? Colors.red
                    : const Color(0xFFE0E0E0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Submit Report',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedReason != null
                            ? Colors.white
                            : const Color(0xFF666666),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildReportOption(ReportOption option, bool isDark) {
    final isSelected = _selectedReason == option.reason;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectReason(option.reason),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.red.withValues(alpha: 26)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.red : const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.red
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isSelected ? Colors.red : const Color(0xFF666666),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
