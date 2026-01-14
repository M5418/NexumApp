import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'performance_coordinator.dart';
import 'performance_flags.dart';
import 'local_performance_controller.dart';

/// Debug overlay widget that shows current performance mode and metrics.
/// Only visible in debug builds.
class PerfDebugOverlay extends StatefulWidget {
  final Widget child;

  const PerfDebugOverlay({
    super.key,
    required this.child,
  });

  @override
  State<PerfDebugOverlay> createState() => _PerfDebugOverlayState();
}

class _PerfDebugOverlayState extends State<PerfDebugOverlay> {
  bool _isExpanded = false;
  final PerformanceCoordinator _coordinator = PerformanceCoordinator();

  @override
  void initState() {
    super.initState();
    _coordinator.effectiveFlags.addListener(_onFlagsChanged);
  }

  @override
  void dispose() {
    _coordinator.effectiveFlags.removeListener(_onFlagsChanged);
    super.dispose();
  }

  void _onFlagsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: _buildOverlay(),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    final flags = _coordinator.flags;
    final health = _coordinator.getHealthMetrics();

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getModeColor(flags.perfMode).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isExpanded ? _buildExpandedContent(flags, health) : _buildCollapsedContent(flags),
      ),
    );
  }

  Widget _buildCollapsedContent(PerformanceFlags flags) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getModeIcon(flags.perfMode),
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          flags.perfMode.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(PerformanceFlags flags, HealthMetrics health) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getModeIcon(flags.perfMode), color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'PERF: ${flags.perfMode.name.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildMetricRow('Jank', '${(health.jankRate * 100).toStringAsFixed(1)}%'),
        _buildMetricRow('Feed P95', '${health.feedLoadP95Ms}ms'),
        _buildMetricRow('Chat P95', '${health.chatLoadP95Ms}ms'),
        _buildMetricRow('Video P95', '${health.videoInitP95Ms}ms'),
        const Divider(color: Colors.white38, height: 8),
        _buildFlagRow('Autoplay', flags.videoAutoplayEnabled),
        _buildFlagRow('Prefetch', flags.allowBackgroundPrefetch),
        _buildFlagRow('RT Lists', flags.enableRealtimeListenersForLists),
        _buildMetricRow('Feed Size', '${flags.feedPageSize}'),
        _buildMetricRow('Preload', '${flags.videoPreloadCount}'),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton('Reset', () {
              _coordinator.resetLocalAdaptations();
            }),
            const SizedBox(width: 4),
            _buildActionButton('Lite', () {
              _coordinator.forceLocalMode(PerfMode.lite);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagRow(String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Colors.greenAccent : Colors.redAccent,
            size: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 8),
        ),
      ),
    );
  }

  Color _getModeColor(PerfMode mode) {
    switch (mode) {
      case PerfMode.normal:
        return Colors.green;
      case PerfMode.lite:
        return Colors.orange;
      case PerfMode.ultra:
        return Colors.red;
    }
  }

  IconData _getModeIcon(PerfMode mode) {
    switch (mode) {
      case PerfMode.normal:
        return Icons.speed;
      case PerfMode.lite:
        return Icons.battery_saver;
      case PerfMode.ultra:
        return Icons.warning;
    }
  }
}
