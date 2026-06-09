// lib/screens/live_stations_screen.dart
//
// OpsFlood — Bihar Live Stations Screen
//
// Wired to biharLiveProvider which calls:
//   • /api/live-levels?state=Bihar  (WRD 31 gauge stations)
//   • /api/glofas                   (river discharge m³/s)
//   • /api/rainfall                 (24h rainfall mm)

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
        title: const Text(
          'Bihar Live Stations',
          style: TextStyle(
            color: AppPalette.cyan,
            fontWeight: FontWeight.bold,
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
                Text(
                  'Could not load Bihar data',
                  style: const TextStyle(
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
                  const Text('No live station data yet',
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
          final critical = state.stations.where((s) => s.isCritical).length;
          final warning  = state.stations.where((s) => s.isWarning).length;

          return RefreshIndicator(
            color: AppPalette.cyan,
            onRefresh: () =>
                ref.read(biharLiveProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                // ── Summary header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _statChip(
                              label: '${state.stations.length} Stations',
                              color: AppPalette.cyan,
                              icon: Icons.sensors,
                            ),
                            const SizedBox(width: 8),
                            if (critical > 0)
                              _statChip(
                                label: '$critical Critical',
                                color: AppPalette.danger,
                                icon: Icons.warning_amber_rounded,
                              ),
                            if (critical > 0) const SizedBox(width: 8),
                            if (warning > 0)
                              _statChip(
                                label: '$warning Warning',
                                color: AppPalette.warning,
                                icon: Icons.info_outline_rounded,
                              ),
                          ],
                        ),
                        if (lastFetch != null) ...
                          [
                            const SizedBox(height: 6),
                            Text(
                              'Updated ${DateFormat('HH:mm').format(lastFetch)}',
                              style: const TextStyle(
                                  color: AppPalette.textDim, fontSize: 11),
                            ),
                          ],
                      ],
                    ),
                  ),
                ),

                // ── Station cards ───────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _StationCard(station: state.stations[i]),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

// ── Station card ─────────────────────────────────────────────────────────────
class _StationCard extends StatelessWidget {
  final BiharStationData station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final s     = station;
    final color = s.isCritical
        ? AppPalette.danger
        : s.isWarning
            ? AppPalette.warning
            : AppPalette.cyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: name + risk badge ──────────────────────────────────
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
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
                _RiskBadge(label: s.riskLabel, color: color),
              ],
            ),

            // ── River + district ─────────────────────────────────────────
            if (s.river.isNotEmpty || s.district.isNotEmpty) ...
              [
                const SizedBox(height: 4),
                Text(
                  [s.river, s.district]
                      .where((v) => v.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 12),
                ),
              ],

            const SizedBox(height: 10),

            // ── Level gauge bar ──────────────────────────────────────────
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.dangerPercent / 100,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 10),
              ],

            // ── Data chips row ───────────────────────────────────────────
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
                        '${s.diff24h! >= 0 ? '+' : ''}${s.diff24h!.toStringAsFixed(2)} m/24h',
                    color: s.diff24h! > 0
                        ? AppPalette.danger
                        : AppPalette.cyan,
                  ),
                if (s.discharge != null)
                  _DataChip(
                    icon: Icons.water,
                    label: '${_fmt(s.discharge!)} m³/s',
                    color: AppPalette.cyan,
                    tooltip: 'GloFAS river discharge',
                  ),
                if (s.rainfall24h != null)
                  _DataChip(
                    icon: Icons.grain,
                    label: '${s.rainfall24h!.toStringAsFixed(1)} mm',
                    color: Colors.lightBlue,
                    tooltip: '24h rainfall',
                  ),
                if (s.forecast24h != null)
                  _DataChip(
                    icon: Icons.trending_up,
                    label:
                        'Fcst ${s.forecast24h!.toStringAsFixed(2)} m',
                    color: AppPalette.gold,
                    tooltip: '24h forecast level',
                  ),
              ],
            ),

            // ── Source tag ───────────────────────────────────────────────
            if (s.source.isNotEmpty) ...
              [
                const SizedBox(height: 8),
                Text(
                  s.source,
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
}

// ── Risk badge ────────────────────────────────────────────────────────────────
class _RiskBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RiskBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
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
  final String label;
  final Color color;
  final String? tooltip;
  const _DataChip(
      {required this.icon,
      required this.label,
      required this.color,
      this.tooltip});

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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: child,
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: wrapped);
    }
    return wrapped;
  }
}
