// lib/screens/alerts_screen.dart
// OpsFlood — AlertsScreen v6.1 (compile-error fixes)
//
// All alerts are derived directly from liveLevelsProvider (FloodData list).
// No separate polling, no ThresholdAlertService needed.
//
// Alert levels:
//   EXTREME  — currentLevel >= dangerLevel * 1.2  (estimated HFL)
//   DANGER   — currentLevel >= dangerLevel
//   WARNING  — currentLevel >= warningLevel
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

// ── Alert level enum ─────────────────────────────────────────────────────
enum LiveAlertLevel {
  warning,
  danger,
  extreme;

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

  IconData get icon => switch (this) {
    warning => Icons.warning_amber_rounded,
    danger  => Icons.crisis_alert_rounded,
    extreme => Icons.flood_rounded,
  };
}

// ── Derived alert model ──────────────────────────────────────────────────
class LiveAlert {
  final FloodData      data;
  final LiveAlertLevel level;
  final double         aboveMark;

  const LiveAlert({
    required this.data,
    required this.level,
    required this.aboveMark,
  });

  double get fillPct {
    final span = data.dangerLevel - data.warningLevel;
    if (span <= 0) return 100.0;
    return ((data.currentLevel - data.warningLevel) / span * 100)
        .clamp(0.0, 150.0);
  }

  String get trendLabel {
    final r = data.riskLevel;
    if (r == 'CRITICAL' || r == 'HIGH') return 'Rising ↑';
    if (r == 'LOW')                     return 'Falling ↓';
    return 'Steady →';
  }

  Color get trendColor {
    final r = data.riskLevel;
    if (r == 'CRITICAL' || r == 'HIGH') return const Color(0xFFEF4444);
    if (r == 'LOW')                     return const Color(0xFF22C55E);
    return const Color(0xFFD4A843);
  }
}

// ── Riverpod: derive LiveAlert list from liveLevelsProvider ───────────────────
final liveAlertsProvider = Provider<List<LiveAlert>>((ref) {
  final levels = ref.watch(liveLevelsProvider);
  final alerts = <LiveAlert>[];

  for (final d in levels) {
    final cl  = d.currentLevel;
    final wl  = d.warningLevel;
    final dl  = d.dangerLevel;
    // FIX: FloodData has no hfl field — estimate HFL as 120% of dangerLevel.
    final hfl = dl * 1.2;

    LiveAlertLevel? level;
    double          aboveMark = 0;

    if (cl >= hfl) {
      level     = LiveAlertLevel.extreme;
      aboveMark = cl - hfl;
    } else if (cl >= dl) {
      level     = LiveAlertLevel.danger;
      aboveMark = cl - dl;
    } else if (cl >= wl && wl > 0) {
      level     = LiveAlertLevel.warning;
      aboveMark = cl - wl;
    }

    if (level != null) {
      alerts.add(LiveAlert(data: d, level: level, aboveMark: aboveMark));
    }
  }

  alerts.sort((a, b) {
    final lc = b.level.index.compareTo(a.level.index);
    return lc != 0 ? lc : b.aboveMark.compareTo(a.aboveMark);
  });

  return alerts;
});

// ── Screen ────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends ConsumerStatefulWidget {
  static const route = '/alerts';
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  LiveAlertLevel? _filterLevel;

  List<LiveAlert> _filtered(List<LiveAlert> all) {
    if (_filterLevel == null) return all;
    return all.where((a) => a.level == _filterLevel).toList();
  }

  // FIX: RealTimeService has .refreshData(), not .refresh()
  Future<void> _refresh() async {
    await ref.read(realTimeProvider).refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final all      = ref.watch(liveAlertsProvider);
    final filtered = _filtered(all);
    // FIX: RealTimeService getter is .isLoading, not .loading
    final loading  = ref.watch(realTimeProvider).isLoading;
    final extreme  = all.where((a) => a.level == LiveAlertLevel.extreme).length;
    final danger   = all.where((a) => a.level == LiveAlertLevel.danger).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(all.length, extreme, danger),
              if (extreme > 0) _buildExtremeBanner(extreme),
              _buildFilterBar(all),
              Expanded(
                child: loading && all.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                                Color(0xFF00B4C8))))
                    : filtered.isEmpty
                        ? _buildEmpty(all.isEmpty)
                        : RefreshIndicator(
                            color: const Color(0xFF00B4C8),
                            backgroundColor: AppPalette.abyss2,
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 40),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) =>
                                  _AlertCard(alert: filtered[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int total, int extreme, int danger) {
    final hasCritical = extreme > 0 || danger > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.critical.withValues(alpha: hasCritical ? 0.07 : 0.0),
            AppPalette.abyss0,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        border: Border(
            bottom: BorderSide(color: AppPalette.abyssStroke, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppPalette.critical.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppPalette.critical.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.notifications_rounded,
                color: AppPalette.critical, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Flood Alerts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.textWhite,
                      letterSpacing: -0.6,
                    )),
                Text(
                  '$total active alert${total != 1 ? 's' : ''} • live data',
                  style: const TextStyle(
                      fontSize: 11, color: AppPalette.textGrey),
                ),
              ],
            ),
          ),
          if (extreme > 0)
            _badge('$extreme EXTREME', AppPalette.critical)
          else if (danger > 0)
            _badge('$danger DANGER', const Color(0xFFF97316)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.40)),
    ),
    child: Text(text,
        style: TextStyle(
          color: color, fontSize: 10,
          fontWeight: FontWeight.w900, letterSpacing: 0.3,
        )),
  );

  Widget _buildExtremeBanner(int n) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    color: AppPalette.critical.withValues(alpha: 0.12),
    child: Row(children: [
      const Icon(Icons.flood_rounded, color: AppPalette.critical, size: 18),
      const SizedBox(width: 10),
      Text(
        '$n station${n > 1 ? 's' : ''} above Highest Flood Level — EVACUATE',
        style: const TextStyle(
          color: AppPalette.critical,
          fontWeight: FontWeight.w700, fontSize: 12,
        ),
      ),
    ]),
  );

  Widget _buildFilterBar(List<LiveAlert> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(
                label:  'All (${all.length})',
                active: _filterLevel == null,
                color:  const Color(0xFF00B4C8),
                onTap:  () => setState(() => _filterLevel = null),
              ),
              ...LiveAlertLevel.values.reversed.map((l) {
                final cnt = all.where((a) => a.level == l).length;
                return _FilterChip(
                  label:  '${l.label} ($cnt)',
                  active: _filterLevel == l,
                  color:  l.color,
                  onTap:  () => setState(
                      () => _filterLevel = _filterLevel == l ? null : l),
                );
              }),
            ]),
          ),
        ),
        GestureDetector(
          onTap: _refresh,
          child: Container(
            width: 34, height: 34,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: AppPalette.abyss2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.abyssStroke),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: AppPalette.textGrey, size: 17),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmpty(bool noData) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF22C55E).withValues(alpha: 0.08),
            border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.20)),
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              size: 32, color: Color(0xFF22C55E)),
        ),
        const SizedBox(height: 14),
        Text(
          noData ? 'Loading live data…' : 'All rivers within safe levels',
          style: const TextStyle(
              color: AppPalette.textGrey,
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (noData) ...[
          const SizedBox(height: 8),
          const Text('Pull down to refresh',
              style: TextStyle(color: AppPalette.textDim, fontSize: 11)),
        ],
      ],
    ),
  );
}

// ── Alert Card ──────────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final LiveAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final d   = alert.data;
    final col = alert.level.color;
    final pct = alert.fillPct.clamp(0.0, 100.0) / 100.0;
    // FIX: d.lastUpdated is non-nullable DateTime — no null check needed
    final ts  = DateFormat('dd MMM  HH:mm').format(d.lastUpdated.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: 0.06),
            blurRadius: 18, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: icon + city + level badge
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(alert.level.icon, color: col, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.city,
                      style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontWeight: FontWeight.w800, fontSize: 14,
                      )),
                  Text(
                    '${d.state}  ·  ${d.riverName ?? 'River'}',
                    style: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: col.withValues(alpha: 0.38)),
              ),
              child: Text(alert.level.label,
                  style: TextStyle(
                    color: col, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ]),

          const SizedBox(height: 12),

          // Row 2: water level bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Water Level',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10)),
                  Text(
                    '+${alert.aboveMark.toStringAsFixed(2)} m above threshold',
                    style: TextStyle(
                        color: col, fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(col),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: current / danger / warning metrics + trend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric('${d.currentLevel.toStringAsFixed(2)} m',
                  'Current', col),
              _metric('${d.dangerLevel.toStringAsFixed(2)} m',
                  'Danger', AppPalette.critical),
              _metric('${d.warningLevel.toStringAsFixed(2)} m',
                  'Warning', const Color(0xFFD4A843)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: alert.trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(alert.trendLabel,
                    style: TextStyle(
                      color: alert.trendColor,
                      fontSize: 10, fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 4: status tag + timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FIX: d.source doesn't exist — use d.status instead
              Text(d.status,
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9)),
              Text(ts,
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String val, String label, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: TextStyle(
          color: c, fontSize: 12, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(
          color: AppPalette.textGrey, fontSize: 9)),
    ],
  );
}

// ── Filter chip widget ──────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final Color        color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.14) : AppPalette.abyss2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.42)
              : AppPalette.abyssStroke,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? color : AppPalette.textGrey,
        ),
      ),
    ),
  );
}
