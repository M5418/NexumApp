import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;

import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/analytics_repository.dart';
import 'post_page.dart';

class InsightsPage extends StatefulWidget {
  final bool? isDarkMode;

  const InsightsPage({super.key, this.isDarkMode});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnalyticsRepository _analyticsRepo;
  String? _currentUserId;
  Period _selectedPeriod = Period.weekly;
  SortBy _selectedSortBy = SortBy.views;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _selectedPeriod = [Period.weekly, Period.monthly, Period.yearly][_tabController.index];
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _analyticsRepo = Provider.of<AnalyticsRepository>(context, listen: false);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}k';
    return number.toString();
  }

  String _formatChange(double change) {
    if (change == 0) return '0%';
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final lang = context.watch<LanguageProvider>();

    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(cardColor, textColor, lang),
        body: Center(child: Text(lang.t('insights.no_data'), style: GoogleFonts.inter(color: textColor))),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(cardColor, textColor, lang),
      body: Column(
        children: [
          _buildTabBar(cardColor, isDark, lang, isDesktop),
          Expanded(
            child: StreamBuilder<PerformanceMetrics>(
              stream: _analyticsRepo.performanceMetricsStream(uid: _currentUserId!, period: _selectedPeriod),
              builder: (context, metricsSnapshot) {
                if (metricsSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading(lang, textColor);
                }
                if (metricsSnapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${metricsSnapshot.error}', style: GoogleFonts.inter(color: textColor)),
                      ],
                    ),
                  );
                }
                
                if (!metricsSnapshot.hasData) {
                  return Center(child: Text(lang.t('insights.no_data'), style: GoogleFonts.inter(color: textColor)));
                }
                return _buildContent(context, isDark, cardColor, textColor, isDesktop, metricsSnapshot.data!, lang);
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(Color cardColor, Color textColor, LanguageProvider lang) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(lang.t('insights.title'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
      centerTitle: true,
    );
  }

  Widget _buildTabBar(Color cardColor, bool isDark, LanguageProvider lang, bool isDesktop) {
    return Container(
      color: cardColor,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 12),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
          decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(25)),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(color: const Color(0xFFBFAE01), borderRadius: BorderRadius.circular(20)),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.black,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [Tab(text: lang.t('insights.weekly')), Tab(text: lang.t('insights.monthly')), Tab(text: lang.t('insights.yearly'))],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(LanguageProvider lang, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01))),
          const SizedBox(height: 16),
          Text(lang.t('insights.loading'), style: GoogleFonts.inter(color: textColor)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color cardColor, Color textColor, bool isDesktop, PerformanceMetrics metrics, LanguageProvider lang) {
    final content = SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceCard(isDark, cardColor, textColor, metrics, lang),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildActivityTimeline(isDark, cardColor, textColor, lang)),
                const SizedBox(width: 24),
                Expanded(child: _buildFollowersOverview(isDark, cardColor, textColor, lang)),
              ],
            )
          else ...[
            _buildActivityTimeline(isDark, cardColor, textColor, lang),
            const SizedBox(height: 24),
            _buildFollowersOverview(isDark, cardColor, textColor, lang),
          ],
          const SizedBox(height: 24),
          _buildPostActivity(isDark, cardColor, textColor, lang),
          const SizedBox(height: 24),
          _buildTopPosts(isDark, cardColor, textColor, lang),
        ],
      ),
    );
    return isDesktop ? Center(child: Container(constraints: const BoxConstraints(maxWidth: 1200), child: content)) : content;
  }

  Widget _buildPerformanceCard(bool isDark, Color cardColor, Color textColor, PerformanceMetrics metrics, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('insights.performance'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2,
            children: [
              _buildMetricTile(lang.t('insights.views'), metrics.totalViews, metrics.viewsChange, isDark, textColor),
              _buildMetricTile(lang.t('insights.comments'), metrics.totalComments, metrics.commentsChange, isDark, textColor),
              _buildMetricTile(lang.t('insights.likes'), metrics.totalLikes, metrics.likesChange, isDark, textColor),
              _buildMetricTile(lang.t('insights.shares'), metrics.totalShares, metrics.sharesChange, isDark, textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, int value, double change, bool isDark, Color textColor) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_formatNumber(value), style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          if (change != 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: isPositive ? Colors.green : Colors.red),
                const SizedBox(width: 2),
                Text(_formatChange(change), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isPositive ? Colors.green : Colors.red)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTimeline(bool isDark, Color cardColor, Color textColor, LanguageProvider lang) {
    return FutureBuilder<List<ActivityData>>(
      future: _analyticsRepo.getActivityTimeline(uid: _currentUserId!, period: _selectedPeriod),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
            height: 250,
            child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFBFAE01)))),
          );
        }
        final activityData = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.t('insights.today_activity'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 20),
              SizedBox(
                height: 150,
                child: activityData.isEmpty
                    ? Center(child: Text(lang.t('insights.no_data'), style: GoogleFonts.inter(color: textColor)))
                    : CustomPaint(painter: ActivityChartPainter(activityData, isDark), size: const Size(double.infinity, 150)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowersOverview(bool isDark, Color cardColor, Color textColor, LanguageProvider lang) {
    return FutureBuilder<Map<String, LocationData>>(
      future: _analyticsRepo.getFollowersOverview(uid: _currentUserId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
            height: 250,
            child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFBFAE01)))),
          );
        }
        final locations = snapshot.data!;
        final totalCount = locations.values.fold<int>(0, (sum, loc) => sum + loc.count);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.t('insights.followers_overview'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 12),
              Text(_formatNumber(totalCount), style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 20),
              if (locations.isEmpty)
                Text(lang.t('insights.no_data'), style: GoogleFonts.inter(color: textColor))
              else
                ...locations.entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildLocationBar(entry.value, isDark, textColor))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationBar(LocationData loc, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(loc.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(loc.country, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
            Text(_formatNumber(loc.count), style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: loc.percentage, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)), minHeight: 8),
        ),
      ],
    );
  }

  Widget _buildPostActivity(bool isDark, Color cardColor, Color textColor, LanguageProvider lang) {
    return FutureBuilder<Map<String, int>>(
      future: _analyticsRepo.getPostActivityCalendar(uid: _currentUserId!, period: _selectedPeriod),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
            height: 200,
            child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFBFAE01)))),
          );
        }
        final calendar = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.t('insights.post_activity'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 20),
              _buildCalendarHeatmap(calendar, isDark, textColor, lang),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarHeatmap(Map<String, int> calendar, bool isDark, Color textColor, LanguageProvider lang) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedPeriod == Period.weekly ? 7 : _selectedPeriod == Period.monthly ? 30 : 365));
    final days = <DateTime>[];
    for (var d = startDate; d.isBefore(now); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    final maxPosts = calendar.values.isEmpty ? 1 : calendar.values.reduce(math.max);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map((day) {
        final dateKey = DateTime(day.year, day.month, day.day).toIso8601String();
        final postCount = calendar[dateKey] ?? 0;
        final intensity = maxPosts > 0 ? (postCount / maxPosts) : 0.0;
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: postCount > 0 ? Color(0xFFBFAE01).withValues(alpha: 0.3 + (intensity * 0.7)) : (isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopPosts(bool isDark, Color cardColor, Color textColor, LanguageProvider lang) {
    return FutureBuilder<List<TopPostData>>(
      future: _analyticsRepo.getTopPosts(uid: _currentUserId!, limit: 5, sortBy: _selectedSortBy),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
            height: 200,
            child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFBFAE01)))),
          );
        }
        final topPosts = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(lang.t('insights.your_top_posts'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  _buildSortDropdown(isDark, lang),
                ],
              ),
              const SizedBox(height: 16),
              if (topPosts.isEmpty)
                Text(lang.t('insights.no_data'), style: GoogleFonts.inter(color: textColor))
              else
                ...topPosts.map((post) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildTopPostItem(post, isDark, textColor))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortDropdown(bool isDark, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!), borderRadius: BorderRadius.circular(20)),
      child: DropdownButton<SortBy>(
        value: _selectedSortBy,
        underline: const SizedBox(),
        isDense: true,
        items: [
          DropdownMenuItem(value: SortBy.views, child: Text(lang.t('insights.by_views'), style: GoogleFonts.inter(fontSize: 12))),
          DropdownMenuItem(value: SortBy.likes, child: Text(lang.t('insights.by_likes'), style: GoogleFonts.inter(fontSize: 12))),
          DropdownMenuItem(value: SortBy.comments, child: Text(lang.t('insights.by_comments'), style: GoogleFonts.inter(fontSize: 12))),
        ],
        onChanged: (value) => setState(() => _selectedSortBy = value!),
      ),
    );
  }

  Widget _buildTopPostItem(TopPostData post, bool isDark, Color textColor) {
    final statValue = _selectedSortBy == SortBy.views ? post.views : _selectedSortBy == SortBy.likes ? post.likes : post.comments;
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PostPage(postId: post.postId)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            if (post.mediaUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(imageUrl: post.mediaUrls.first, width: 60, height: 60, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 60, height: 60, color: Colors.grey[800])),
              )
            else
              Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFFBFAE01).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.article, color: Color(0xFFBFAE01))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.text.isEmpty ? '(No text)' : post.text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${_formatNumber(statValue)} ${_selectedSortBy.name}', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFBFAE01)),
          ],
        ),
      ),
    );
  }
}

class ActivityChartPainter extends CustomPainter {
  final List<ActivityData> data;
  final bool isDark;

  ActivityChartPainter(this.data, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxValue = data.map((d) => d.views).reduce(math.max).toDouble();
    if (maxValue == 0) return;
    final paint = Paint()..color = const Color(0xFFBFAE01)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    final step = size.width / (data.length - 1).clamp(1, double.infinity);
    for (var i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - (data[i].views / maxValue * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    final pointPaint = Paint()..color = const Color(0xFFBFAE01)..style = PaintingStyle.fill;
    for (var i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - (data[i].views / maxValue * size.height);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
