import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';

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

  final List<String> _types = ['All', 'Text', 'Image', 'Video', 'Podcast'];
  String _selectedType = 'All';

  // Demo dataset
  final List<_ItemStat> _items = const [
    _ItemStat(
      title: 'Morning routine tips',
      type: 'Text',
      earnings: 26.80,
      impressions: 4820,
      likes: 320,
      comments: 51,
      shares: 22,
      bookmarks: 40,
      ageDays: 5,
    ),
    _ItemStat(
      title: 'Healthy snacks list',
      type: 'Text',
      earnings: 18.30,
      impressions: 3950,
      likes: 270,
      comments: 34,
      shares: 18,
      bookmarks: 27,
      ageDays: 14,
    ),
    _ItemStat(
      title: 'Gym progress photo',
      type: 'Image',
      earnings: 43.10,
      impressions: 8900,
      likes: 860,
      comments: 72,
      shares: 37,
      bookmarks: 66,
      ageDays: 9,
    ),
    _ItemStat(
      title: 'Quick salad ideas',
      type: 'Image',
      earnings: 35.75,
      impressions: 7120,
      likes: 640,
      comments: 41,
      shares: 25,
      bookmarks: 52,
      ageDays: 26,
    ),
    _ItemStat(
      title: '10-min HIIT demo',
      type: 'Video',
      earnings: 59.40,
      impressions: 12040,
      likes: 980,
      comments: 87,
      shares: 61,
      bookmarks: 74,
      ageDays: 3,
    ),
    _ItemStat(
      title: 'Core workout basics',
      type: 'Video',
      earnings: 48.95,
      impressions: 10480,
      likes: 870,
      comments: 64,
      shares: 49,
      bookmarks: 69,
      ageDays: 32,
    ),
    _ItemStat(
      title: 'Mindfulness 101',
      type: 'Podcast',
      earnings: 62.70,
      impressions: 10560,
      likes: 410,
      comments: 56,
      shares: 22,
      bookmarks: 88,
      ageDays: 11,
    ),
    _ItemStat(
      title: 'Sleep hacks ep.3',
      type: 'Podcast',
      earnings: 44.25,
      impressions: 8890,
      likes: 330,
      comments: 39,
      shares: 16,
      bookmarks: 59,
      ageDays: 44,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final card = isDark ? const Color(0xFF000000) : Colors.white;

    final maxDays = _selectedPeriod == '7d'
        ? 7
        : _selectedPeriod == '30d'
            ? 30
            : _selectedPeriod == '90d'
                ? 90
                : 365;

    final filtered = _items.where((e) {
      final within = e.ageDays <= maxDays;
      if (_selectedType == 'All') return within;
      return within && e.type == _selectedType;
    }).toList();

    final totalEarnings = filtered.fold<double>(0.0, (s, e) => s + e.earnings);
    final totalImpressions = filtered.fold<int>(0, (s, e) => s + e.impressions);
    final totalEngagement =
        filtered.fold<int>(0, (s, e) => s + e.likes + e.comments + e.shares + e.bookmarks);

    final cpm = totalImpressions > 0 ? (totalEarnings / (totalImpressions / 1000)).toDouble() : 0.0;

    final revenueTrend = [
      12.0, 18.0, 14.0, 22.0, 26.0, 19.0, 31.0, 28.0, 34.0, 30.0, 36.0, 42.0,
    ];

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
                    onChanged: (v) => setState(() => _selectedPeriod = v ?? '30d'),
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
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _selectedType = v ?? 'All'),
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
                _kpi('Revenue', '\$${totalEarnings.toStringAsFixed(2)}'),
                const SizedBox(width: 12),
                _kpi('CPM', '\$${cpm.toStringAsFixed(2)}'),
                const SizedBox(width: 12),
                _kpi('Engagement', totalEngagement.toString()),
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
                  'Revenue trend',
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
                ...filtered.map((e) => _itemTile(e)),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'No items in this period for selected type.',
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

  Widget _itemTile(_ItemStat e) {
    final engagement = e.likes + e.comments + e.shares + e.bookmarks;
    final icon = e.type == 'Podcast'
        ? Icons.podcasts
        : (e.type == 'Video'
            ? Icons.play_circle_fill
            : (e.type == 'Image' ? Icons.image_outlined : Icons.text_snippet_outlined));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon),
      title: Row(
        children: [
          Expanded(
            child: Text(
              e.title,
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
              e.type,
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
            _pill('Earnings', '\$${e.earnings.toStringAsFixed(2)}'),
            _pill('Views', e.impressions.toString()),
            _pill('Engagement', engagement.toString()),
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

class _ItemStat {
  final String title;
  final String type; // Text, Image, Video, Podcast
  final double earnings;
  final int impressions;
  final int likes;
  final int comments;
  final int shares;
  final int bookmarks;
  final int ageDays; // approximate recency to filter by period
  const _ItemStat({
    required this.title,
    required this.type,
    required this.earnings,
    required this.impressions,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.bookmarks,
    required this.ageDays,
  });
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