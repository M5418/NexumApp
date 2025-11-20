// File: lib/widgets/report_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/firebase/firebase_report_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

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
  // Generic target
  final String targetType; // 'post' | 'story' | 'user' | 'comment' | 'community_post'
  final String targetId;
  final String authorName; // display name (post/story owner or user full name)
  final String? authorUsername; // like '@username'
  final Function(String targetId, String cause, String comment)? onReport;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.authorName,
    this.authorUsername,
    this.onReport,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();

  static void show(
    BuildContext context, {
    required String targetType, // 'post' | 'story' | 'user' | 'comment' | 'community_post'
    required String targetId,
    required String authorName,
    String? authorUsername,
    Function(String targetId, String cause, String comment)? onReport,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReportBottomSheet(
        targetType: targetType,
        targetId: targetId,
        authorName: authorName,
        authorUsername: authorUsername,
        onReport: onReport,
      ),
    );
  }
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  ReportReason? _selectedReason;
  bool _isSubmitting = false;
  final TextEditingController _commentController = TextEditingController();
  final FirebaseReportRepository _repo = FirebaseReportRepository();

  final List<ReportOption> _reportOptions = [
    ReportOption(
      reason: ReportReason.poorEngagement,
      title: 'Poor Engagement',
      description:
          'This content does not engage the audience or lacks meaningful value.',
    ),
    ReportOption(
      reason: ReportReason.irrelevantContent,
      title: 'Irrelevant Content',
      description: 'Content does not match the community or platform guidelines.',
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
          'Contains false/harmful information or violates our policies.',
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

  String _causeCode(ReportReason r) {
    switch (r) {
      case ReportReason.poorEngagement:
        return 'poor_engagement';
      case ReportReason.irrelevantContent:
        return 'irrelevant_content';
      case ReportReason.overposting:
        return 'overposting';
      case ReportReason.harmfulContent:
        return 'harmful_content';
      case ReportReason.privacyViolation:
        return 'privacy_violation';
    }
  }

  String _titleForTarget() {
    switch (widget.targetType) {
      case 'user':
        return "What's wrong with this user?";
      case 'story':
        return "What's wrong with this story?";
      case 'comment':
        return "What's wrong with this comment?";
      case 'community_post':
        return "What's wrong with this community post?";
      case 'post':
      default:
        return "What's wrong with this post?";
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final cause = _causeCode(_selectedReason!);
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Must be signed in to report');
      }
      
      await _repo.createReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        cause: cause,
        comment: _commentController.text,
        reporterId: user.uid,
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report submitted. Our team will review it.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 3),
        ),
      );

      widget.onReport?.call(widget.targetId, cause, _commentController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
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

          const SizedBox(height: 16),

          // Target info
          Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reporting ${widget.authorName}${(widget.authorUsername != null && widget.authorUsername!.isNotEmpty) ? ' (${widget.authorUsername})' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            _titleForTarget(),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          const SizedBox(height: 16),

          // Report options
          ...(_reportOptions.map((option) => _buildReportOption(option, isDark))),

          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason != null && !_isSubmitting ? _submitReport : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedReason != null ? Colors.red : const Color(0xFFE0E0E0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
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
        onTap: () => setState(() => _selectedReason = option.reason),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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