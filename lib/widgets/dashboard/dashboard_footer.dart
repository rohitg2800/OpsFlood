// lib/widgets/dashboard/dashboard_footer.dart
// DashboardFooter — summary stats + last-sync freshness banner.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/river_theme.dart';

class DashboardFooter extends StatelessWidget {
  final int totalStations;
  final int riversCount;
  final int statesAtRisk;
  final DateTime? lastUpdated;

  const DashboardFooter({
    super.key,
    required this.totalStations,
    required this.riversCount,
    required this.statesAtRisk,
    required this.lastUpdated,
  });

  static const _staleHours = 3;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final fmt = lastUpdated != null
        ? DateFormat('dd MMM, HH:mm').format(lastUpdated!)
        : 'Never';
    final isStale = lastUpdated != null &&
        DateTime.now().difference(lastUpdated!).inHours >= _staleHours;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(value: '$totalStations', label: 'stations', t: t),
                _VerticalDivider(t: t),
                _Stat(value: '$riversCount', label: 'rivers', t: t),
                _VerticalDivider(t: t),
                _Stat(value: '$statesAtRisk', label: 'at risk', t: t),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isStale
                    ? const Color(0xFFFFA726).withValues(alpha: 0.07)
                    : t.stroke.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isStale
                        ? Icons.access_time_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 11,
                    color: isStale
                        ? const Color(0xFFFFA726)
                        : AppPalette.safe,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isStale
                        ? 'Data may be stale · last sync $fmt'
                        : 'Last sync $fmt',
                    style: TextStyle(
                      color: isStale
                          ? const Color(0xFFFFA726)
                          : t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sources: WRD Bihar · GloFAS · IMD · CWC',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final RiverColors t;
  const _Stat({required this.value, required this.label, required this.t});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: t.textSecondary, fontSize: 10),
          ),
        ],
      );
}

class _VerticalDivider extends StatelessWidget {
  final RiverColors t;
  const _VerticalDivider({required this.t});

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: t.stroke);
}
