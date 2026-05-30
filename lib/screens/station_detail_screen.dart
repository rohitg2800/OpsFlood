import 'package:flutter/material.dart';
import '../models/station.dart';
import '../widgets/gauge_bar.dart';

class StationDetailScreen extends StatelessWidget {
  final Station station;
  const StationDetailScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final s = station;
    final statusColor = s.isDanger ? const Color(0xFFFF4757) : (s.isWarning ? const Color(0xFFFFA502) : const Color(0xFF00FF88));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E1A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [statusColor.withOpacity(0.15), const Color(0xFF0A0E1A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            ),
                            _statusBadge(s.status, statusColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${s.river}  ·  ${s.district}, Bihar', style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(s.isLive ? Icons.sensors : Icons.analytics_outlined, size: 12, color: const Color(0xFF4A5568)),
                            const SizedBox(width: 4),
                            Text(s.dataSource.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Current level big card
                  _bigLevelCard(s, statusColor),
                  const SizedBox(height: 16),

                  // ── Gauge
                  _sectionLabel('Water Level Gauge'),
                  const SizedBox(height: 8),
                  _gaugeCard(s, statusColor),
                  const SizedBox(height: 16),

                  // ── Level thresholds
                  _sectionLabel('Level Thresholds'),
                  const SizedBox(height: 8),
                  _thresholdsCard(s),
                  const SizedBox(height: 16),

                  // ── Station info
                  _sectionLabel('Station Info'),
                  const SizedBox(height: 8),
                  _infoCard(s),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
  );

  Widget _bigLevelCard(Station s, Color color) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF141928),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Level', style: TextStyle(color: Color(0xFF8B9CC8), fontSize: 12)),
              const SizedBox(height: 4),
              Text('${s.currentLevel.toStringAsFixed(2)} m', style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 4),
              Text(_trendLabel(s.trend), style: TextStyle(color: _trendColor(s.trend), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _levelChip('${(s.pctToDanger).toStringAsFixed(1)}% to danger', color),
            const SizedBox(height: 8),
            if (s.isDanger && s.aboveDangerM > 0)
              _levelChip('+${s.aboveDangerM.toStringAsFixed(2)}m above danger', const Color(0xFFFF4757)),
          ],
        ),
      ],
    ),
  );

  Widget _levelChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _gaugeCard(Station s, Color statusColor) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF141928),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        GaugeBar(station: s, height: 18, showLabels: true),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _legendDot(const Color(0xFF00FF88), 'Safe ≤${s.safeLevel}m'),
            _legendDot(const Color(0xFFFFA502), 'Warn ${s.warningLevel}m'),
            _legendDot(const Color(0xFFFF4757), 'Danger ${s.dangerLevel}m'),
            _legendDot(const Color(0xFFFF0033), 'HFL ${s.hfl}m'),
          ],
        ),
      ],
    ),
  );

  Widget _legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 10)),
    ],
  );

  Widget _thresholdsCard(Station s) {
    final rows = [
      ('Safe Level',    '${s.safeLevel} m',    const Color(0xFF00FF88)),
      ('Warning Level', '${s.warningLevel} m', const Color(0xFFFFA502)),
      ('Danger Level',  '${s.dangerLevel} m',  const Color(0xFFFF4757)),
      ('HFL (Highest)', '${s.hfl} m',          const Color(0xFFFF0033)),
      ('Current Level', '${s.currentLevel.toStringAsFixed(2)} m', Colors.white),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141928),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          final row = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2840))),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 16, decoration: BoxDecoration(color: row.$3, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Text(row.$1, style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 13)),
                const Spacer(),
                Text(row.$2, style: TextStyle(color: row.$3, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoCard(Station s) {
    final rows = [
      ('Station ID',   s.id),
      ('River',        s.river),
      ('District',     s.district),
      ('Coordinates',  '${s.lat.toStringAsFixed(4)}°N, ${s.lon.toStringAsFixed(4)}°E'),
      ('Data Source',  s.dataSource.replaceAll('_', ' ')),
      ('Last Updated', s.lastUpdated.length > 16 ? s.lastUpdated.substring(0, 16) : s.lastUpdated),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141928),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E2840))),
            ),
            child: Row(
              children: [
                Text(e.value.$1, style: const TextStyle(color: Color(0xFF4A5568), fontSize: 12)),
                const Spacer(),
                Text(e.value.$2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );

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
