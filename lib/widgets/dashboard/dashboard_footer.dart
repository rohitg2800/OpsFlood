// lib/widgets/dashboard/dashboard_footer.dart
// DashboardFooter — fixed "Last sync Never" → live DataFetchEngine timestamp.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/data_fetch_engine.dart';
import '../../theme/river_theme.dart';

class DashboardFooter extends StatelessWidget {
  final int totalStations;
  final int riversCount;
  final int statesAtRisk;
  // lastUpdated kept for backward compat but ignored — engine time used instead.
  final DateTime? lastUpdated;

  const DashboardFooter({
    super.key,
    required this.totalStations,
    required this.riversCount,
    required this.statesAtRisk,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return StreamBuilder<DataFetchSnapshot>(
      stream: DataFetchEngine.instance.stream,
      initialData: DataFetchEngine.instance.last,
      builder: (_, snap) {
        final fetchedAt = snap.data?.fetchedAt;
        final sources   = snap.data?.sources ?? [];
        final liveCount = sources
            .where((s) => s.healthy && !s.isFromSeed)
            .length;

        final syncLabel = fetchedAt == null
            ? 'Last sync  Never'
            : 'Last sync  ${DateFormat('HH:mm:ss').format(fetchedAt)}';

        final dotColor = fetchedAt == null
            ? AppPalette.warning
            : AppPalette.safe;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.stroke),
          ),
          child: Column(
            children: [
              // ── Stats row ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FooterStat(
                    t: t,
                    label: 'stations',
                    value: '$totalStations',
                    icon: Icons.sensors_rounded,
                    color: t.accent,
                  ),
                  _FooterDivider(t: t),
                  _FooterStat(
                    t: t,
                    label: 'rivers',
                    value: '$riversCount',
                    icon: Icons.water_rounded,
                    color: AppPalette.cyan,
                  ),
                  _FooterDivider(t: t),
                  _FooterStat(
                    t: t,
                    label: 'at risk',
                    value: '$statesAtRisk',
                    icon: Icons.warning_amber_rounded,
                    color: statesAtRisk > 0 ? AppPalette.danger : AppPalette.safe,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Sync status row ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dotColor.withValues(alpha: 0.20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      syncLabel,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Sources attribution row ─────────────────────────────
              Text(
                'Sources: WRD Bihar · GloFAS · IMD · CWC'
                '${liveCount > 0 ? "  ·  $liveCount live" : ""}',
                style: TextStyle(
                  color: t.textSecondary.withValues(alpha: 0.50),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FooterStat extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  final IconData icon;
  final Color color;
  const _FooterStat({
    required this.t,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FooterDivider extends StatelessWidget {
  final RiverColors t;
  const _FooterDivider({required this.t});
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: t.stroke);
}
