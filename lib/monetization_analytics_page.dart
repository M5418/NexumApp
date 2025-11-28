import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/monetization_repository.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'repositories/models/monetization_models.dart';

class MonetizationAnalyticsPage extends StatelessWidget {
  const MonetizationAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final text = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('monetization.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
        centerTitle: true,
      ),
      body: const MonetizationAnalyticsView(),
    );
  }
}

/// Reusable analytics panel (no AppBar/Scaffold).
class MonetizationAnalyticsView extends StatefulWidget {
  const MonetizationAnalyticsView({super.key});

  @override
  State<MonetizationAnalyticsView> createState() => _MonetizationAnalyticsViewState();
}

class _MonetizationAnalyticsViewState extends State<MonetizationAnalyticsView> {
  final List<String> _periods = ['7d', '30d', '90d', '12m'];
  String _selectedPeriod = '30d';

  final List<String> _types = ['All', 'post', 'podcast', 'book'];
  String _selectedType = 'All';

  List<ContentMonetizationStats> _contentStats = [];
  Map<String, double> _revenueTrend = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authRepo = context.read<AuthRepository>();
    final monetizationRepo = context.read<MonetizationRepository>();

    final user = authRepo.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final days = _selectedPeriod == '7d' ? 7 : _selectedPeriod == '30d' ? 30 : _selectedPeriod == '90d' ? 90 : 365;
      
      // Get content stats
      final stats = await monetizationRepo.getContentStats(
        userId: user.uid,
        contentType: _selectedType == 'All' ? null : _selectedType,
        sortBy: 'totalEarnings',
        limit: 50,
      );

      // Get revenue trend
      final trend = await monetizationRepo.getRevenueTrend(
        userId: user.uid,
        days: days,
      );

      if (!mounted) return;
      setState(() {
        _contentStats = stats;
        _revenueTrend = trend;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading analytics: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final card = isDark ? const Color(0xFF000000) : Colors.white;

    if (_loading) {
      return Container(
        color: background,
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
      );
    }

    final totalEarnings = _contentStats.fold<double>(0.0, (s, e) => s + e.totalEarnings);
    final totalImpressions = _contentStats.fold<int>(0, (s, e) => s + e.impressions);
    final totalEngagement = _contentStats.fold<int>(0, (s, e) => s + e.totalEngagement);

    final cpm = totalImpressions > 0 ? (totalEarnings / (totalImpressions / 1000)).toDouble() : 0.0;

    // Convert trend map to sorted list of values
    final sortedDates = _revenueTrend.keys.toList()..sort();
    final revenueTrend = sortedDates.map((key) => _revenueTrend[key]!).toList();
    
    // Pad with zeros if we have less than 12 data points
    while (revenueTrend.length < 12) {
      revenueTrend.insert(0, 0.0);
    }

    return Container(
      color: background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Filters
          _card(
            color: card,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Period',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedPeriod = v ?? '30d');
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t == 'post' ? 'Post' : t == 'podcast' ? 'Podcast' : t == 'book' ? 'Book' : 'All'))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedType = v ?? 'All');
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // KPIs
          _card(
            color: card,
            child: Row(
              children: [
                _kpi(Provider.of<LanguageProvider>(context, listen: false).t('monetization.revenue'), '\$${totalEarnings.toStringAsFixed(2)}'),
                const SizedBox(width: 12),
                _kpi(Provider.of<LanguageProvider>(context, listen: false).t('monetization.cpm'), '\$${cpm.toStringAsFixed(2)}'),
                const SizedBox(width: 12),
                _kpi(Provider.of<LanguageProvider>(context, listen: false).t('monetization.engagement'), totalEngagement.toString()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Trend
          _card(
            color: card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('monetization.revenue_trend'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _MiniBarChart(values: revenueTrend),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Per-item breakdown
          _card(
            color: card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per-item breakdown',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._contentStats.map((stats) => _realItemTile(stats)),
                if (_contentStats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'No monetized content yet. Create posts and enable monetization to start earning.',
                      style: GoogleFonts.inter(color: const Color(0xFF666666)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF666666),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Color color, required Widget child}) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      );

  Widget _realItemTile(ContentMonetizationStats stats) {
    final icon = stats.contentType == 'podcast'
        ? Icons.podcasts
        : (stats.contentType == 'book'
            ? Icons.menu_book_outlined
            : Icons.article_outlined);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Content ${stats.contentId.substring(0, 8)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Text(
              stats.contentType.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _pill(Provider.of<LanguageProvider>(context, listen: false).t('monetization.earnings'), '\$${stats.totalEarnings.toStringAsFixed(2)}'),
            _pill(Provider.of<LanguageProvider>(context, listen: false).t('monetization.views'), stats.impressions.toString()),
            _pill(Provider.of<LanguageProvider>(context, listen: false).t('monetization.engagement'), stats.totalEngagement.toString()),
          ],
        ),
      ),
    );
  }

  Widget _pill(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text('$k: $v', style: GoogleFonts.inter(fontSize: 12)),
      );
}

class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  const _MiniBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = const Color(0xFFBFAE01);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: 8 + v,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 13),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}