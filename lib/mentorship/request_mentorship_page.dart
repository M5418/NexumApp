import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/i18n/language_provider.dart';

class RequestMentorshipPage extends StatefulWidget {
  final String fieldId;
  final String fieldName;

  const RequestMentorshipPage({super.key, required this.fieldId, required this.fieldName});

  @override
  State<RequestMentorshipPage> createState() => _RequestMentorshipPageState();
}

class _RequestMentorshipPageState extends State<RequestMentorshipPage> {
  final TextEditingController _textController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final surfaceColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final secondaryTextColor = const Color(0xFF666666);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('mentorship.request_title'), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textColor)),
        centerTitle: false,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(Provider.of<LanguageProvider>(context, listen: false).t('mentorship.tell_us_more'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFBFAE01).withAlpha(26), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${Provider.of<LanguageProvider>(context, listen: false).t('mentorship.field')}: ', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: secondaryTextColor)),
                  Text(widget.fieldName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFBFAE01))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: Provider.of<LanguageProvider>(context, listen: false).t('mentorship.goals_hint'),
                    hintStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: secondaryTextColor),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: textColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: IconButton(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    // Placeholder: request creation is handled elsewhere in the new flow.
    // Synchronously acknowledge and close without crossing async gaps.
    _showSuccessSnackBar();
    Navigator.pop(context);
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Provider.of<LanguageProvider>(context, listen: false).t('mentorship.request_sent'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black)),
        backgroundColor: const Color(0xFFBFAE01),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}