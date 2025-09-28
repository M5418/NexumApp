import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/mentorship_api.dart';
import 'mentorship_conversations_page.dart';
import 'professional_fields_page.dart';
import 'my_mentors_page.dart';
import 'my_schedule_page.dart';

class MentorshipHomePage extends StatefulWidget {
  final VoidCallback? onMentorshipChat;
  final VoidCallback? onMyMentors;
  final VoidCallback? onMySchedule;

  const MentorshipHomePage({
    super.key,
    this.onMentorshipChat,
    this.onMyMentors,
    this.onMySchedule,
  });

  @override
  State<MentorshipHomePage> createState() => _MentorshipHomePageState();
}

class _MentorshipHomePageState extends State<MentorshipHomePage> {
  final _api = MentorshipApi();
  bool _loading = true;
  String? _error;
  List<MentorshipFieldDto> _fields = [];
  List<MentorshipSessionDto> _upcoming = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fields = await _api.listFields();
      final sessions = await _api.listSessions('upcoming');
      if (!mounted) return;
      setState(() {
        _fields = fields;
        _upcoming = sessions;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load mentorship data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        title: Text(
          'Mentorship',
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
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFBFAE01),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats / Navigation
              Row(
                children: [
                  Expanded(
                    child: _buildNavigationButton(
                      Icons.chat_bubble_outline,
                      'Conversations',
                      surfaceColor,
                      textColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MentorshipConversationsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNavigationButton(
                      Icons.calendar_today_outlined,
                      'Schedule',
                      surfaceColor,
                      textColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MySchedulePage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildNavigationButton(
                      Icons.person_outline,
                      'My Mentors',
                      surfaceColor,
                      textColor,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyMentorsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 24),

              // Professional Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose a professional field',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfessionalFieldsPage(),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFBFAE01),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProfessionalFields(surfaceColor, textColor, secondaryTextColor),
              const SizedBox(height: 24),

              // Upcoming Meetings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming meetings',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MySchedulePage()),
                      );
                    },
                    child: Text(
                      'View',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFBFAE01),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildUpcomingMeetings(surfaceColor, textColor, secondaryTextColor),
              const SizedBox(height: 24),

              // Why Choose Mentorship
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: const Color(0xFFBFAE01), size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Why Choose Mentorship?',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitItem('🎯', 'Personalized Guidance', 'Get tailored advice for your specific goals and challenges', textColor, secondaryTextColor),
                    const SizedBox(height: 12),
                    _buildBenefitItem('🚀', 'Accelerated Growth', 'Learn from experienced professionals and avoid common pitfalls', textColor, secondaryTextColor),
                    const SizedBox(height: 12),
                    _buildBenefitItem('🤝', 'Network Expansion', 'Connect with industry leaders and expand your professional network', textColor, secondaryTextColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    IconData icon,
    String label,
    Color surfaceColor,
    Color textColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 24, color: textColor),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalFields(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    if (_loading && _fields.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: const Color(0xFFBFAE01))),
      );
    }
    if (_error != null && _fields.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            _error!,
            style: GoogleFonts.inter(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final fields = _fields;
    if (fields.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No fields available',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryTextColor),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: fields.length,
        itemBuilder: (context, index) {
          final field = fields[index];
          return Container(
            width: 140,
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 12,
              right: index == fields.length - 1 ? 0 : 0,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfessionalFieldsPage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getFieldColor(field.name).withValues(alpha: 26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(field.icon, style: TextStyle(fontSize: 20, color: _getFieldColor(field.name))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        field.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'MENTORSHIP',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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

  Widget _buildUpcomingMeetings(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    if (_loading && _upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
      );
    }

    final sessions = _upcoming;
    if (sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No upcoming meetings',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: secondaryTextColor,
            ),
          ),
        ),
      );
    }

    return Container(
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
      child: Column(
        children: sessions.take(2).map((session) {
          final idx = sessions.indexOf(session);
          final isLast = idx == sessions.length - 1 || idx == 1;
          final avatar = session.mentorAvatar ??
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(session.mentorName)}';
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: !isLast
                  ? Border(
                      bottom: BorderSide(
                        color: secondaryTextColor.withValues(alpha: 26),
                        width: 1,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatar)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.mentorName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.topic,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(session.scheduledAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFBFAE01),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.videocam, color: Colors.white, size: 20),
                    onPressed: () {
                      // Join meeting
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Widget _buildBenefitItem(
    String icon,
    String title,
    String description,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 20, color: const Color(0xFFBFAE01))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 4),
              Text(description, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryTextColor)),
            ],
          ),
        ),
      ],
    );
  }
}