import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mentor.dart';
import '../data/mentorship_data.dart';

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          'Schedule',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFBFAE01),
          unselectedLabelColor: secondaryTextColor,
          indicatorColor: const Color(0xFFBFAE01),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingTab(surfaceColor, textColor, secondaryTextColor),
          _buildCompletedTab(surfaceColor, textColor, secondaryTextColor),
          _buildCancelledTab(surfaceColor, textColor, secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final upcomingSessions = MentorshipData.getUpcomingSessions();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingSessions.length,
      itemBuilder: (context, index) {
        final session = upcomingSessions[index];
        return _buildSessionCard(
          session,
          surfaceColor,
          textColor,
          secondaryTextColor,
          showJoinButton: true,
        );
      },
    );
  }

  Widget _buildCompletedTab(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    // Sample completed sessions
    final completedSessions = [
      MentorshipSession(
        id: '10',
        mentorId: '2',
        mentorName: 'Sarah Kim',
        mentorAvatar:
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
        scheduledTime: DateTime.now().subtract(const Duration(days: 3)),
        duration: const Duration(hours: 1),
        topic: 'Startup Strategy Discussion',
        status: SessionStatus.completed,
      ),
      MentorshipSession(
        id: '11',
        mentorId: '4',
        mentorName: 'Emily Rodriguez',
        mentorAvatar:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        scheduledTime: DateTime.now().subtract(const Duration(days: 7)),
        duration: const Duration(minutes: 45),
        topic: 'Business Operations Review',
        status: SessionStatus.completed,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedSessions.length,
      itemBuilder: (context, index) {
        final session = completedSessions[index];
        return _buildSessionCard(
          session,
          surfaceColor,
          textColor,
          secondaryTextColor,
          showRatingButton: true,
        );
      },
    );
  }

  Widget _buildCancelledTab(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    // Sample cancelled sessions
    final cancelledSessions = [
      MentorshipSession(
        id: '20',
        mentorId: '3',
        mentorName: 'David Wilson',
        mentorAvatar:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        scheduledTime: DateTime.now().subtract(const Duration(days: 1)),
        duration: const Duration(hours: 1),
        topic: 'Marketing Strategy Session',
        status: SessionStatus.cancelled,
      ),
    ];

    if (cancelledSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No cancelled sessions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cancelledSessions.length,
      itemBuilder: (context, index) {
        final session = cancelledSessions[index];
        return _buildSessionCard(
          session,
          surfaceColor,
          textColor,
          secondaryTextColor,
          showRescheduleButton: true,
        );
      },
    );
  }

  Widget _buildSessionCard(
    MentorshipSession session,
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor, {
    bool showJoinButton = false,
    bool showRatingButton = false,
    bool showRescheduleButton = false,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(session.mentorAvatar),
              ),
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
                  ],
                ),
              ),
              _buildStatusChip(session.status, textColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: secondaryTextColor),
              const SizedBox(width: 8),
              Text(
                _formatSessionDateTime(session.scheduledTime),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '${session.duration.inMinutes} min',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFBFAE01),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showJoinButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Join meeting
                },
                icon: const Icon(Icons.videocam, size: 18, color: Colors.black),
                label: Text(
                  'Join Meeting',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (showRatingButton)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showRatingDialog();
                },
                icon: Icon(Icons.star_outline, size: 18, color: textColor),
                label: Text(
                  'Rate Session',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: textColor.withValues(alpha: 51)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (showRescheduleButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Reschedule session
                },
                icon: const Icon(Icons.schedule, size: 18, color: Colors.black),
                label: Text(
                  'Reschedule',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(SessionStatus status, Color textColor) {
    Color chipColor;
    String statusText;

    switch (status) {
      case SessionStatus.scheduled:
        chipColor = const Color.fromARGB(255, 219, 201, 34);
        statusText = 'Scheduled';
        break;
      case SessionStatus.inProgress:
        chipColor = Colors.green;
        statusText = 'In Progress';
        break;
      case SessionStatus.completed:
        chipColor = Colors.green;
        statusText = 'Completed';
        break;
      case SessionStatus.cancelled:
        chipColor = Colors.red;
        statusText = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: chipColor,
        ),
      ),
    );
  }

  String _formatSessionDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow ${_formatTime(dateTime)}';
    } else if (difference.inDays == -1) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  void _showRatingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          'Rate Session',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How was your mentorship session?',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(Icons.star, color: Colors.amber, size: 32),
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle rating
                  },
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
