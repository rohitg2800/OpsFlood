// lib/widgets/dashboard/system_stats.dart
// SystemStats — 2×2 grid of data-source health tiles with live pulse dots.
import 'package:flutter/material.dart';
import '../../services/real_time_service.dart';
import '../../theme/river_theme.dart';

// ─── Public: SystemStats ──────────────────────────────────────────────────────
class SystemStats extends StatelessWidget {
  final RealTimeService service;
  final AnimationController pulseCtrl;
  final Animation<double> gaugeAnim;
  final bool reduceMotion;

  const SystemStats({
    super.key,
    required this.service,
    required this.pulseCtrl,
    required this.gaugeAnim,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    final sources = [
      (
        label:   'GloFAS',
        detail:  'Flood Forecast',
        ok:      service.glofasHealthy,
        latency: service.glofasLatencyMs,
      ),
      (
        label:   'WRD Bihar',
        detail:  'River Gauge',
        ok:      service.wrdHealthy,
        latency: service.wrdLatencyMs,
      ),
      (
        label:   'IMD',
        detail:  'Rainfall Data',
        ok:      service.imdHealthy,
        latency: service.imdLatencyMs,
      ),
      (
        label:   'CWC',
        detail:  'Central Water',
        ok:      service.cwcHealthy,
        latency: service.cwcLatencyMs,
      ),
    ];

    final healthyCount = sources.where((s) => s.ok).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_rounded, size: 13, color: t.accent),
                const SizedBox(width: 6),
                Text(
                  'Data Sources',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (healthyCount == sources.length
                            ? AppPalette.safe
                            : AppPalette.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$healthyCount/${sources.length} online',
                    style: TextStyle(
                      color: healthyCount == sources.length
                          ? AppPalette.safe
                          : AppPalette.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: sources
                  .map((s) => _SourceTile(
                        source: s,
                        pulseCtrl: pulseCtrl,
                        reduceMotion: reduceMotion,
                        t: t,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Private: _SourceTile ─────────────────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final ({
    String label,
    String detail,
    bool ok,
    int? latency
  }) source;
  final AnimationController pulseCtrl;
  final bool reduceMotion;
  final RiverColors t;

  const _SourceTile({
    required this.source,
    required this.pulseCtrl,
    required this.reduceMotion,
    required this.t,
  });

  static const _amber = Color(0xFFE6A817);

  Color get _dotColor {
    if (source.ok) return AppPalette.safe;
    if (source.latency == null) return _amber;
    return AppPalette.critical;
  }

  String? get _latencyLabel {
    final ms = source.latency;
    if (ms == null) return null;
    return ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s';
  }

  @override
  Widget build(BuildContext context) {
    final col = _dotColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final pulse =
                  source.ok && !reduceMotion ? 0.5 + pulseCtrl.value * 0.5 : 0.9;
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: pulse),
                  boxShadow: source.ok
                      ? [
                          BoxShadow(
                            color: col.withValues(
                                alpha: pulseCtrl.value * 0.45),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        source.label,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_latencyLabel != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _latencyLabel!,
                          style: TextStyle(
                            color: col,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  source.detail,
                  style:
                      TextStyle(color: t.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
