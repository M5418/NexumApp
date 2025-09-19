import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InsightsPage extends StatefulWidget {
  final bool? isDarkMode;

  const InsightsPage({super.key, this.isDarkMode});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedActivityFilter = 'Last 7 days';
  String _selectedLocationFilter = 'Top Location';
  String _selectedPostFilter = 'By Views';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Insights',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab Navigation
          Container(
            color: cardColor,
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.black : Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
                Tab(text: 'Yearly'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInsightsContent(isDark, cardColor, textColor),
                _buildInsightsContent(isDark, cardColor, textColor),
                _buildInsightsContent(isDark, cardColor, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsContent(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Indicators
          _buildPerformanceIndicators(isDark, cardColor, textColor),
          const SizedBox(height: 24),

          // Today Activity
          _buildTodayActivity(isDark, cardColor, textColor),
          const SizedBox(height: 24),

          // Followers Overview
          _buildFollowersOverview(isDark, cardColor, textColor),
          const SizedBox(height: 24),

          // Post Activity
          _buildPostActivity(isDark, cardColor, textColor),
          const SizedBox(height: 24),

          // Your Top Post
          _buildYourTopPost(isDark, cardColor, textColor),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicators(
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Indicators',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '328k',
                  'Views',
                  '+8%',
                  true,
                  isDark,
                  textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '3.2k',
                  'Comments',
                  '+4%',
                  true,
                  isDark,
                  textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '178k',
                  'Likes',
                  '+12%',
                  true,
                  isDark,
                  textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    String change,
    bool isPositive,
    bool isDark,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          change,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayActivity(bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today Activity',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              _buildDropdown(
                _selectedActivityFilter,
                ['Last 7 days', 'Last 30 days', 'Last 90 days'],
                (value) {
                  setState(() => _selectedActivityFilter = value!);
                },
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: LineChartPainter(),
              size: const Size(double.infinity, 120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowersOverview(
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Followers Overview',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              _buildDropdown(
                _selectedLocationFilter,
                ['Top Location', 'All Locations'],
                (value) {
                  setState(() => _selectedLocationFilter = value!);
                },
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '89,827',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildCountryItem(
            '🇺🇸',
            'United States',
            '102.6k',
            0.6,
            isDark,
            textColor,
          ),
          const SizedBox(height: 12),
          _buildCountryItem('🇫🇷', 'France', '86.7k', 0.5, isDark, textColor),
          const SizedBox(height: 12),
          _buildCountryItem(
            '🇰🇷',
            'South Korea',
            '34.7k',
            0.2,
            isDark,
            textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCountryItem(
    String flag,
    String country,
    String count,
    double progress,
    bool isDark,
    Color textColor,
  ) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    country,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    count,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFBFAE01),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostActivity(bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Post Activity',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '328',
                  'Reached',
                  '',
                  false,
                  isDark,
                  textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '178',
                  'Likes',
                  '',
                  false,
                  isDark,
                  textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '3',
                  'Posts',
                  '',
                  false,
                  isDark,
                  textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarGrid(isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark, Color textColor) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final weeks = [
      [null, null, null, null, null, 1, 2],
      [3, 4, 5, 6, 7, 8, 9],
      [10, 11, 12, 13, 14, 15, 16],
      [17, 18, 19, 20, 21, 22, 23],
      [24, 25, 26, 27, 28, 29, 30],
      [31, null, null, null, null, null, null],
    ];

    return Column(
      children: [
        Row(
          children: days
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...weeks
            .map(
              (week) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: week
                      .map(
                        (day) => Expanded(
                          child: Container(
                            height: 32,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: day != null
                                  ? (day % 3 == 0
                                        ? const Color(0xFFBFAE01)
                                        : isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[100])
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: day != null
                                ? Center(
                                    child: Text(
                                      day.toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: day % 3 == 0
                                            ? Colors.white
                                            : textColor,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            )
            ,
      ],
    );
  }

  Widget _buildYourTopPost(bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Top Post',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              _buildDropdown(
                _selectedPostFilter,
                ['By Views', 'By Likes', 'By Comments'],
                (value) {
                  setState(() => _selectedPostFilter = value!);
                },
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTopPostItem(
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=60&h=60&fit=crop',
            'Just had the most incredible adventure. Endless destinations. 🌍✈️',
            '#IncredibleJourney #Moments',
            '2.3k views',
            isDark,
            textColor,
          ),
          const SizedBox(height: 12),
          _buildTopPostItem(
            'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=60&h=60&fit=crop',
            'Chasing sunsets, finding peace 🌅 #WanderlustMoments',
            '',
            '1.8k views',
            isDark,
            textColor,
          ),
          const SizedBox(height: 12),
          _buildTopPostItem(
            'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=60&h=60&fit=crop',
            'Warm it up, bite into joy — Pop-Tarts just hit different toasted.',
            '',
            '1.2k views',
            isDark,
            textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPostItem(
    String imageUrl,
    String text,
    String hashtags,
    String views,
    bool isDark,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFBFAE01),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (hashtags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  hashtags,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFBFAE01),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                views,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.grey[400]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: GoogleFonts.inter(fontSize: 12)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        underline: Container(),
        isDense: true,
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFAE01)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.1, size.height * 0.6),
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.3, size.height * 0.4),
      Offset(size.width * 0.4, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.6, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.4),
      Offset(size.width * 0.8, size.height * 0.1),
      Offset(size.width * 0.9, size.height * 0.3),
      Offset(size.width, size.height * 0.5),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = const Color(0xFFBFAE01)
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
