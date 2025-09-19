import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'interest_selection_page.dart';

class StatusSelectionPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;

  const StatusSelectionPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
    this.hasProfilePhoto = false,
  });

  @override
  State<StatusSelectionPage> createState() => _StatusSelectionPageState();
}

class _StatusSelectionPageState extends State<StatusSelectionPage> {
  String? _selectedStatus;

  void _selectStatus(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  void _navigateNext() {
    if (_selectedStatus != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InterestSelectionPage()),
      );
      debugPrint('Selected status: $_selectedStatus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Status',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Question Text
              Text(
                'What will be your status your Nexum',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 40),

              // Status Options
              Row(
                children: [
                  Expanded(
                    child: _buildStatusOption(
                      'Entrepreneur',
                      _selectedStatus == 'Entrepreneur',
                      isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatusOption(
                      'Investor',
                      _selectedStatus == 'Investor',
                      isDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              const Spacer(),

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedStatus != null ? _navigateNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedStatus != null
                        ? const Color(0xFFBFAE01)
                        : (isDarkMode
                              ? const Color(0xFF333333)
                              : const Color(0xFFE0E0E0)),
                    foregroundColor: _selectedStatus != null
                        ? Colors.black
                        : (isDarkMode ? Colors.grey : Colors.grey),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Next',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(String status, bool isSelected, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _selectStatus(status),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBFAE01)
              : (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBFAE01)
                : (isDarkMode
                      ? const Color(0xFF333333)
                      : const Color(0xFFE0E0E0)),
            width: 1,
          ),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.black
                    : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.black
                      : (isDarkMode
                            ? const Color(0xFF666666)
                            : const Color(0xFFCCCCCC)),
                  width: 2,
                ),
                color: Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
