// lib/screens/alerts_screen.dart
// OpsFlood — AlertsScreen v7  (Premium minimal rebuild)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

enum LiveAlertLevel {
  warning, danger, extreme;

  String get label => switch (this) {
    warning => 'WARNING',
    danger  => 'DANGER',
    extreme => 'EXTREME',
  };

  Color get color => switch (this) {
    warning => const Color(0xFFD4A843),
    danger  => const Color(0xFFF97316),
    extreme => const Color(0xFFEF4444),
  };

  Color get bg => color.withValues(alpha: 0.08);
  Color get border => color.withValues(alpha: 0.22);

  IconData get icon => switch (this) {
    warning => Icons.warning_amber_rounded,
    danger  => Icons.crisis_alert_rounded,
    extreme => Icons.flood_rounded,
  };
}

class LiveAlert {
  const LiveAlert({required this.data, required this.level, required this.aboveMark});
  final FloodData data;
  final LiveAlertLevel level;
  final double aboveMark;

  double get fillPct {
    final span = data.dangerLevel - data.warningLevel;
    if (span <= 0) return 1.0;
    return ((data.currentLevel - data.warningLevel) / span).clamp(0.0, 1.0);
  }
}

List<LiveAlert> _buildAlerts(List<FloodData> all) {
  final out = <LiveAlert>[];
  for (final d in all) {
    if (d.currentLevel >= d.dangerLevel * 1.2) {
      out.add(LiveAlert(data: d, level: LiveAlertLevel.extreme,
          aboveMark: d.currentLevel - d.dangerLevel));
    } else if (d.currentLevel >= d.dangerLevel) {
      out.add(LiveAlert(data: d, level: LiveAlertLevel.danger,
          aboveMark: d.currentLevel - d.dangerLevel));
    } else if (d.currentLevel >= d.warningLevel) {
      out.add(LiveAlert(data: d, level: LiveAlertLevel.warning,
          aboveMark: d.currentLevel - d.warningLevel));
    }
  }
  out.sort((a, b) => b.level.index.compareTo(a.level.index));
  return out;
}

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  LiveAlertLevel? _filter;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(liveLevelsProvider);
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(pulse: _pulse),
            const SizedBox(height: 4),
            dataAsync.when(
              loading: () => const Expanded(child: Center(
                  child: CircularProgressIndicator(
                      color: AppPalette.cyan, strokeWidth: 1.5))),
              error:   (e, _) => Expanded(child: _ErrorState(msg: '$e')),
              data: (all) {
                final alerts = _buildAlerts(all);
                final counts = {
                  for (final lv in LiveAlertLevel.values)
                    lv: alerts.where((a) => a.level == lv).length,
                };
                final shown = _filter == null
                    ? alerts
                    : alerts.where((a) => a.level == _filter).toList();

                return Expanded(
                  child: Column(
                    children: [
                      _SummaryRow(counts: counts, filter: _filter,
                          onFilter: (lv) => setState(() =>
                              _filter = _filter == lv ? null : lv)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: shown.isEmpty
                            ? _EmptyState(active: _filter != null)
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: shown.length,
                                itemBuilder: (_, i) => _AlertCard(
                                    alert: shown[i], pulse: _pulse),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text('Flood Alerts',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: AppPalette.textWhite, letterSpacing: 0.3)),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.critical,
                boxShadow: [BoxShadow(
                  color: AppPalette.critical.withValues(alpha: 0.5 * pulse.value),
                  blurRadius: 8,
                )],
              ),
            ),
          ),
          const Spacer(),
          Text(DateFormat('HH:mm').format(DateTime.now()),
              style: const TextStyle(
                  fontSize: 12, color: AppPalette.textGrey)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.counts, required this.filter,
      required this.onFilter});
  final Map<LiveAlertLevel, int> counts;
  final LiveAlertLevel? filter;
  final ValueChanged<LiveAlertLevel> onFilter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: LiveAlertLevel.values.map((lv) {
          final active = filter == lv;
          final c = lv.color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onFilter(lv),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? c.withValues(alpha: 0.16) : AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? c.withValues(alpha: 0.5) : AppPalette.abyssStroke,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(lv.icon, size: 14, color: c),
                    const SizedBox(width: 6),
                    Text('${lv.label}  ${counts[lv] ?? 0}',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: active ? c : AppPalette.textGrey,
                        )),
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.pulse});
  final LiveAlert alert;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final c   = alert.level.color;
    final d   = alert.data;
    final pct = alert.fillPct;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.22), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.withValues(alpha: 0.12 * pulse.value),
                        border: Border.all(color: c.withValues(alpha: 0.35), width: 1),
                      ),
                      child: Icon(alert.level.icon, color: c, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.city,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: AppPalette.textWhite)),
                        Text(d.state,
                            style: const TextStyle(
                                fontSize: 11, color: AppPalette.textGrey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Text(alert.level.label,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: c, letterSpacing: 1.0)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Metric('Current', '${d.currentLevel.toStringAsFixed(1)} m', c),
                      const SizedBox(width: 24),
                      _Metric('Warning', '${d.warningLevel.toStringAsFixed(1)} m',
                          AppPalette.warning),
                      const SizedBox(width: 24),
                      _Metric('Danger', '${d.dangerLevel.toStringAsFixed(1)} m',
                          AppPalette.danger),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 4, color: AppPalette.abyssStroke),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppPalette.safe, c],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('+${alert.aboveMark.toStringAsFixed(2)} m above '
                      '${alert.level == LiveAlertLevel.warning ? "warning" : "danger"} mark',
                      style: TextStyle(fontSize: 11, color: c)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppPalette.textGrey)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.safe.withValues(alpha: 0.08),
            border: Border.all(
                color: AppPalette.safe.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(
            active ? Icons.filter_alt_off_rounded : Icons.check_circle_outline_rounded,
            color: AppPalette.safe, size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(active ? 'No alerts match filter' : 'All rivers normal',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: AppPalette.textWhite)),
        const SizedBox(height: 6),
        Text(active ? 'Try clearing the filter.' : 'No active warnings detected.',
            style: const TextStyle(fontSize: 13, color: AppPalette.textGrey)),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppPalette.critical, size: 36),
          const SizedBox(height: 12),
          const Text('Failed to load alerts',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600, color: AppPalette.textWhite)),
          const SizedBox(height: 6),
          Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppPalette.textGrey)),
        ],
      ),
    ),
  );
}
