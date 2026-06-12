// lib/screens/live_stations_screen.dart  (v2.0)
//
// OpsFlood — All-Stations Live Screen
//
// v1.x → v2.0:
//   • Title is now dynamic: 'All Stations (N)'
//   • Summary bar gains: Severe (orange), Safe (green), No-Data (grey) chips
//   • _StationCard shows state field below river·district
//   • Level gauge bar renders 0–150% with a danger-line tick at 100%
//   • Risk colour extracted to _riskColor() — riskLabel='NORMAL' → grey
//   • Source badge shows LIVE (cyan) vs STATIC (grey)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bihar_live_provider.dart';
import '../theme/river_theme.dart';

class LiveStationsScreen extends ConsumerWidget {
  static const String route = '/live-stations';
  const LiveStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(biharLiveProvider);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: async.when(
          loading: () => const Text('Loading Stations…',
              style: TextStyle(
                  color: AppPalette.cyan, fontWeight: FontWeight.bold)),
          error: (_, __) => const Text('Stations',
              style: TextStyle(
                  color: AppPalette.danger, fontWeight: FontWeight.bold)),
          data: (s) => Text(
            'All Stations (${s.stations.length})',
            style: const TextStyle(
                color: AppPalette.cyan, fontWeight: FontWeight.bold),
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.gold),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.cyan),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(biharLiveProvider.notifier).refresh(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppPalette.cyan),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppPalette.danger),
                const SizedBox(height: 12),
                const Text(
                  'Could not load station data',
                  style: TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.cyan),
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('Retry',
                      style: TextStyle(color: Colors.black)),
                  onPressed: () =>
                      ref.read(biharLiveProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          if (state.stations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_outlined,
                      size: 56, color: AppPalette.cyan),
                  const SizedBox(height: 12),
                  const Text('No station data yet',
                      style: TextStyle(color: AppPalette.textGrey)),
                  const SizedBox(height: 4),
                  const Text('Pull to refresh',
                      style: TextStyle(
                          color: AppPalette.textDim, fontSize: 12)),
                ],
              ),
            );
          }

          final lastFetch = state.lastFetched;

          return RefreshIndicator(
            color: AppPalette.cyan,
            onRefresh: () =>
                ref.read(biharLiveProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                // ── Summary header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _statChip(
                              label: '${state.stations.length} Total',
                              color: AppPalette.cyan,
                              icon: Icons.sensors,
                            ),
                            if (state.criticalCount > 0)
                              _statChip(
                                label: '${state.criticalCount} Critical',
                                color: AppPalette.danger,
                                icon: Icons.warning_amber_rounded,
                              ),
                            if (state.severeCount > 0)
                              _statChip(
                                label: '${state.severeCount} Severe',
                                color: Colors.deepOrange,
                                icon: Icons.warning_rounded,
                              ),
                            if (state.warningCount > 0)
                              _statChip(
                                label: '${state.warningCount} Warning',
                                color: AppPalette.warning,
                                icon: Icons.info_outline_rounded,
                              ),
                            if (state.safeCount > 0)
                              _statChip(
                                label: '${state.safeCount} Safe',
                                color: Colors.green,
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            if (state.noDataCount > 0)
                              _statChip(
                                label: '${state.noDataCount} No Data',
                                color: AppPalette.textGrey,
                                icon: Icons.signal_wifi_off_rounded,
                              ),
                          ],
                        ),
                        if (lastFetch != null) ...
                          [
                            const SizedBox(height: 6),
                            Text(
                              'Updated ${DateFormat('HH:mm:ss').format(lastFetch)}',
                              style: const TextStyle(
                                  color: AppPalette.textDim, fontSize: 11),
                            ),
                          ],
                      ],
                    ),
                  ),
                ),

                // ── Station cards ──────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _StationCard(station: state.stations[i]),
                      childCount: state.stations.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Risk colour helper ────────────────────────────────────────────────────────
Color _riskColor(BiharStationData s) {
  if (s.isCritical)  return AppPalette.danger;
  if (s.isSevere)    return Colors.deepOrange;
  if (s.isWarning)   return AppPalette.warning;
  if (s.isSafe)      return Colors.green;
  return AppPalette.textGrey; // NORMAL / NO_DATA
}

// ── Station card ──────────────────────────────────────────────────────────────
class _StationCard extends StatelessWidget {
  final BiharStationData station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final s     = station;
    final color = _riskColor(s);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: dot + name + risk badge + source tag ───────────────
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.city,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                _SourceTag(live: s.source == 'LIVE'),
                const SizedBox(width: 6),
                _RiskBadge(label: s.riskLabel, color: color),
              ],
            ),

            // ── River · district · state ──────────────────────────────────
            if ([s.river, s.district, s.state]
                .any((v) => v.isNotEmpty)) ...
              [
                const SizedBox(height: 4),
                Text(
                  [s.river, s.district, s.state]
                      .where((v) => v.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 12),
                ),
              ],

            const SizedBox(height: 10),

            // ── Level gauge (0 – 150%) ────────────────────────────────────
            if (s.currentLevel != null && s.dangerLevel != null) ...
              [
                Row(
                  children: [
                    const Text('Level',
                        style: TextStyle(
                            color: AppPalette.textDim, fontSize: 11)),
                    const Spacer(),
                    Text(
                      '${s.currentLevel!.toStringAsFixed(2)} m  /  '
                      '${s.dangerLevel!.toStringAsFixed(2)} m danger',
                      style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Gauge bar: fill = pct/150 so that 100% (danger) is at 2/3
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (s.dangerPercent / 150).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    // Danger-line tick at the 2/3 mark
                    FractionallySizedBox(
                      widthFactor: 2 / 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 2, height: 7,
                          color: AppPalette.danger.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

            // ── Data chips ────────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (s.diff24h != null)
                  _DataChip(
                    icon: s.trend == '↑'
                        ? Icons.arrow_upward
                        : s.trend == '↓'
                            ? Icons.arrow_downward
                            : Icons.remove,
                    label:
                        '${s.diff24h! >= 0 ? '+' : ''}'  
                        '${s.diff24h!.toStringAsFixed(2)} m/24h',
                    color: s.diff24h! > 0
                        ? AppPalette.danger
                        : AppPalette.cyan,
                  ),
                if (s.discharge != null)
                  _DataChip(
                    icon:    Icons.water,
                    label:   '${_fmt(s.discharge!)} m³/s',
                    color:   AppPalette.cyan,
                    tooltip: 'GloFAS river discharge',
                  ),
                if (s.rainfall24h != null && s.rainfall24h! > 0)
                  _DataChip(
                    icon:    Icons.grain,
                    label:   '${s.rainfall24h!.toStringAsFixed(1)} mm',
                    color:   Colors.lightBlue,
                    tooltip: '24h rainfall',
                  ),
                if (s.forecast24h != null)
                  _DataChip(
                    icon:    Icons.trending_up,
                    label:   'Fcst ${s.forecast24h!.toStringAsFixed(2)} m',
                    color:   AppPalette.gold,
                    tooltip: '24h forecast level',
                  ),
              ],
            ),

            // ── Source + time ─────────────────────────────────────────────
            if (s.source.isNotEmpty || s.fetchedAt.isNotEmpty) ...
              [
                const SizedBox(height: 8),
                Text(
                  [
                    s.source,
                    if (s.fetchedAt.isNotEmpty)
                      _shortTs(s.fetchedAt),
                  ].join('  '),
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 10),
                ),
              ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  static String _shortTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

// ── Source tag ────────────────────────────────────────────────────────────────
class _SourceTag extends StatelessWidget {
  final bool live;
  const _SourceTag({required this.live});

  @override
  Widget build(BuildContext context) {
    final color = live ? AppPalette.cyan : AppPalette.textGrey;
    final label = live ? '● LIVE' : '○ STATIC';
    return Text(label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.bold));
  }
}

// ── Risk badge ────────────────────────────────────────────────────────────────
class _RiskBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _RiskBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Data chip ─────────────────────────────────────────────────────────────────
class _DataChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final String?  tooltip;
  const _DataChip({
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
    final wrapped = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: child,
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: wrapped);
    }
    return wrapped;
  }
}
