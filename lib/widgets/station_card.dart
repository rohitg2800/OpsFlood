import 'package:flutter/material.dart';
import '../models/station.dart';
import 'gauge_bar.dart';

class StationCard extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;
  final bool compact;

  const StationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = station;
    final color = s.isDanger
      ? const Color(0xFFFF4757)
      : (s.isWarning ? const Color(0xFFFFA502) : const Color(0xFF00FF88));

    if (compact) return _buildCompact(s, color);
    return _buildFull(s, color);
  }

  Widget _buildFull(Station s, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF141928),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: s.isDanger ? color.withOpacity(0.5)
              : (s.isWarning ? color.withOpacity(0.3) : const Color(0xFF1E2840)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.name,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (s.isLive)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('LIVE', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('${s.river} · ${s.district}',
                          style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 11)),
                      ],
                    ),
                  ),
                  // Level + trend
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${s.currentLevel.toStringAsFixed(2)}m',
                        style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(_trendStr(s.trend),
                        style: TextStyle(color: _trendColor(s.trend), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Gauge bar
              GaugeBar(station: s, height: 7),
              const SizedBox(height: 6),
              // Bottom row: pct + danger level
              Row(
                children: [
                  Text('${s.pctToDanger.toStringAsFixed(0)}% to danger',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('DL: ${s.dangerLevel}m',
                    style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(Station s, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.name,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GaugeBar(station: s, height: 5),
            ),
            const SizedBox(width: 10),
            Text('${s.currentLevel.toStringAsFixed(1)}m',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 10, color: const Color(0xFF4A5568)),
          ],
        ),
      ),
    );
  }

  String _trendStr(String t) => switch (t) {
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
