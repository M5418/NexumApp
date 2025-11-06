import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Using local placeholder model until repository exposes sessions

class _ScheduleItem {
  final String id;
  final String mentorId;
  final String mentorName;
  final String? mentorAvatarUrl = null;
  final String topic;
  final String status; // scheduled, completed, cancelled
  final DateTime scheduledAt;
  final int durationMinutes = 60;
  final String? meetingLink = null;
  _ScheduleItem({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    required this.topic,
    required this.status,
    required this.scheduledAt,
  });
}

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Upcoming
  bool _loadingUpcoming = true;
  String? _errorUpcoming;
  List<_ScheduleItem> _upcoming = [];

  // Completed
  bool _loadingCompleted = false;
  String? _errorCompleted;
  List<_ScheduleItem> _completed = [];

  // Cancelled
  bool _loadingCancelled = false;
  String? _errorCancelled;
  List<_ScheduleItem> _cancelled = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadStatus('upcoming');
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0:
        if (_upcoming.isEmpty && !_loadingUpcoming) _loadStatus('upcoming');
        break;
      case 1:
        if (_completed.isEmpty && !_loadingCompleted) _loadStatus('completed');
        break;
      case 2:
        if (_cancelled.isEmpty && !_loadingCancelled) _loadStatus('cancelled');
        break;
    }
  }

  Future<void> _loadStatus(String status) async {
    setState(() {
      if (status == 'upcoming') {
        _loadingUpcoming = true;
        _errorUpcoming = null;
      } else if (status == 'completed') {
        _loadingCompleted = true;
        _errorCompleted = null;
      } else {
        _loadingCancelled = true;
        _errorCancelled = null;
      }
    });

    try {
      // Placeholder: repository doesn't expose sessions yet. Clear lists.
      if (mounted) {
        setState(() {
          if (status == 'upcoming') {
            _upcoming = [];
          } else if (status == 'completed') {
            _completed = [];
          } else {
            _cancelled = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final err = 'Failed to load $status sessions: $e';
          if (status == 'upcoming') {
            _errorUpcoming = err;
          } else if (status == 'completed') {
            _errorCompleted = err;
          } else {
            _errorCancelled = err;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (status == 'upcoming') {
            _loadingUpcoming = false;
          } else if (status == 'completed') {
            _loadingCompleted = false;
          } else {
            _loadingCancelled = false;
          }
        });
      }
    }
  }

  // _refreshCurrent removed (unused)

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final surfaceColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
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
    final loading = _loadingUpcoming;
    final error = _errorUpcoming;
    final items = _upcoming;

    return RefreshIndicator(
      color: const Color(0xFFBFAE01),
      onRefresh: () => _loadStatus('upcoming'),
      child: loading && items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
            ])
          : error != null && items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text(error, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _loadStatus('upcoming'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
                        child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 160),
                      Center(
                        child: Text(
                          'No upcoming sessions',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final s = items[index];
                        return _buildSessionCard(
                          s,
                          surfaceColor,
                          textColor,
                          secondaryTextColor,
                          showJoinButton: true,
                        );
                      },
                    ),
    );
  }

  Widget _buildCompletedTab(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final loading = _loadingCompleted;
    final error = _errorCompleted;
    final items = _completed;

    return RefreshIndicator(
      color: const Color(0xFFBFAE01),
      onRefresh: () => _loadStatus('completed'),
      child: loading && items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
            ])
          : error != null && items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text(error, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _loadStatus('completed'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
                        child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 160),
                      Center(
                        child: Text(
                          'No completed sessions',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final s = items[index];
                        return _buildSessionCard(
                          s,
                          surfaceColor,
                          textColor,
                          secondaryTextColor,
                          showRatingButton: true,
                        );
                      },
                    ),
    );
  }

  Widget _buildCancelledTab(
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final loading = _loadingCancelled;
    final error = _errorCancelled;
    final items = _cancelled;

    return RefreshIndicator(
      color: const Color(0xFFBFAE01),
      onRefresh: () => _loadStatus('cancelled'),
      child: loading && items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
            ])
          : error != null && items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text(error, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _loadStatus('cancelled'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
                        child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 160),
                      Center(
                        child: Text(
                          'No cancelled sessions',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final s = items[index];
                        return _buildSessionCard(
                          s,
                          surfaceColor,
                          textColor,
                          secondaryTextColor,
                          showRescheduleButton: true,
                        );
                      },
                    ),
    );
  }

  Widget _buildSessionCard(
    _ScheduleItem session,
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor, {
    bool showJoinButton = false,
    bool showRatingButton = false,
    bool showRescheduleButton = false,
  }) {
    final mentorName = session.mentorName.isNotEmpty ? session.mentorName : 'Mentor';
    final avatar = (session.mentorAvatarUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(mentorName)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
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
                backgroundImage: NetworkImage(avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mentorName,
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
              const Icon(Icons.access_time, size: 16, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                _formatSessionDateTime(session.scheduledAt),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '${session.durationMinutes} min',
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
                  if ((session.meetingLink ?? '').isEmpty) {
                    _snack('Meeting link not available yet.');
                  } else {
                    _snack('Meeting link: ${session.meetingLink}');
                    // Optionally: launch URL with url_launcher if available.
                  }
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
                onPressed: () => _showRatingDialog(session.id),
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
                  side: BorderSide(color: textColor.withAlpha(51)),
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
                  // TODO: Implement reschedule flow
                  _snack('Reschedule flow coming soon');
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

  Widget _buildStatusChip(String status, Color textColor) {
    final s = (status).toLowerCase();
    late Color chipColor;
    late String statusText;

    switch (s) {
      case 'scheduled':
        chipColor = const Color.fromARGB(255, 219, 201, 34);
        statusText = 'Scheduled';
        break;
      case 'in_progress':
        chipColor = Colors.green;
        statusText = 'In Progress';
        break;
      case 'completed':
        chipColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'cancelled':
        chipColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        chipColor = const Color(0xFF666666);
        statusText = s.isEmpty ? 'Unknown' : s;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(26),
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
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (d == today) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (d == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${_formatTime(dateTime)}';
    } else if (d == today.subtract(const Duration(days: 1))) {
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

  void _snack(String m) {
    final s = ScaffoldMessenger.maybeOf(context);
    s?.showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _showRatingDialog(String sessionId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

    int selected = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
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
                children: List.generate(5, (i) {
                  final idx = i + 1;
                  final isOn = idx <= selected;
                  return IconButton(
                    icon: Icon(
                      isOn ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setStateDialog(() => selected = idx),
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
            TextButton(
              onPressed: selected == 0
                  ? null
                  : () {
                      Navigator.pop(context);
                      _snack('Thanks for your feedback!');
                      // Optimistically refresh completed tab after rating
                      _loadStatus('completed');
                    },
              child: Text(
                'Submit',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected == 0 ? textColor.withAlpha(120) : const Color(0xFFBFAE01),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
}