import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/station_provider.dart';
import '../models/station.dart';
import '../widgets/gauge_bar.dart';
import 'station_detail_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<StationProvider>(
        builder: (ctx, prov, _) {
          final danger  = prov.stations.where((s) => s.isDanger).toList();
          final warning = prov.stations.where((s) => s.isWarning).toList();

          return RefreshIndicator(
            color: const Color(0xFF00D4FF),
            backgroundColor: const Color(0xFF141928),
            onRefresh: () => prov.loadAll(),
            child: CustomScrollView(
              slivers: [
                _appBar(danger.length, warning.length),
                if (danger.isEmpty && warning.isEmpty)
                  _allClearSliver()
                else ...
                  [
                    if (danger.isNotEmpty) ...
                      [
                        _sectionHeader('🔴  DANGER — Above Danger Level', const Color(0xFFFF4757), danger.length),
                        _alertList(ctx, danger, const Color(0xFFFF4757)),
                      ],
                    if (warning.isNotEmpty) ...
                      [
                        _sectionHeader('🟠  WARNING — Approaching Danger', const Color(0xFFFFA502), warning.length),
                        _alertList(ctx, warning, const Color(0xFFFFA502)),
                      ],
                  ],
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _appBar(int danger, int warning) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0A0E1A),
      title: Row(
        children: [
          const Text('Bihar Alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (danger > 0)
            _badge('$danger DANGER', const Color(0xFFFF4757)),
          if (danger > 0 && warning > 0)
            const SizedBox(width: 6),
          if (warning > 0)
            _badge('$warning WARN', const Color(0xFFFFA502)),
        ],
      ),
      automaticallyImplyLeading: false,
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  SliverToBoxAdapter _allClearSliver() => SliverToBoxAdapter(
    child: SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 44),
            ),
            const SizedBox(height: 20),
            const Text('All Stations Normal', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('No stations above warning level', style: TextStyle(color: Color(0xFF4A5568), fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Pull down to refresh', style: TextStyle(color: Color(0xFF4A5568), fontSize: 12)),
          ],
        ),
      ),
    ),
  );

  SliverToBoxAdapter _sectionHeader(String title, Color color, int count) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const Spacer(),
          Text('$count stations', style: const TextStyle(color: Color(0xFF4A5568), fontSize: 12)),
        ],
      ),
    ),
  );

  SliverList _alertList(BuildContext ctx, List<Station> stations, Color color) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => _AlertCard(station: stations[i], color: color),
        childCount: stations.length,
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Station station;
  final Color color;
  const _AlertCard({required this.station, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StationDetailScreen(station: station))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF141928),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(station.isDanger ? Icons.dangerous : Icons.warning_amber, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(station.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('${station.river} · ${station.district}', style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${station.currentLevel.toStringAsFixed(2)}m', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(_trendLabel(station.trend), style: TextStyle(color: _trendColor(station.trend), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            // Gauge bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  GaugeBar(station: station, height: 10),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Safe: ${station.safeLevel}m', style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                      Text('Warn: ${station.warningLevel}m', style: const TextStyle(color: Color(0xFFFFA502), fontSize: 11)),
                      Text('Danger: ${station.dangerLevel}m', style: const TextStyle(color: Color(0xFFFF4757), fontSize: 11)),
                    ],
                  ),
                  if (station.isDanger && station.aboveDangerM > 0) ...
                    [
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4757).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
                        ),
                        child: Text(
                          '⚠ ${station.aboveDangerM.toStringAsFixed(2)}m ABOVE danger level — ${station.aboveDangerM >= 1.5 ? "EVACUATE" : (station.aboveDangerM >= 0.5 ? "WARN" : "MONITOR")}',
                          style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                ],
              ),
            ),
            // Source + live badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(station.isLive ? Icons.sensors : Icons.analytics_outlined, size: 12, color: const Color(0xFF4A5568)),
                  const SizedBox(width: 5),
                  Text(station.dataSource.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                  const Spacer(),
                  Text(station.lastUpdated.length > 16 ? station.lastUpdated.substring(0, 16) : station.lastUpdated,
                    style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _trendLabel(String t) => switch (t) {
    'rising'  => '▲ Rising',
    'falling' => '▼ Falling',
    _         => '● Stable',
  };

  Color _trendColor(String t) => switch (t) {
    'rising'  => const Color(0xFFFF4757),
    'falling' => const Color(0xFF00FF88),
    _         => const Color(0xFF8B9CC8),
  };
}
