// lib/widgets/dashboard/river_pulse_card.dart
// Extracted from dashboard_screen.dart — single river status card with trend arrow.
import 'package:flutter/material.dart';
import '../../models/flood_data.dart';

class RiverPulseCard extends StatelessWidget {
  final FloodData data;
  final VoidCallback? onTap;

  const RiverPulseCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor(data.riskLevel);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: riskColor.withOpacity(0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Risk indicator dot
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.city,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (data.riverName != null)
                      Text(data.riverName!,
                          style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
              // Capacity %
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.capacityPercent.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.w800, color: riskColor, fontSize: 16),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_trendIcon(data.trend), size: 13, color: _trendColor(data.trend)),
                      const SizedBox(width: 2),
                      Text(
                        data.riskLevel,
                        style: TextStyle(fontSize: 10, color: riskColor, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'CRITICAL': return Colors.red;
      case 'SEVERE':   return Colors.orange;
      case 'MODERATE': return Colors.amber;
      default:         return Colors.green;
    }
  }

  IconData _trendIcon(String? trend) {
    if (trend == 'RISING')  return Icons.trending_up;
    if (trend == 'FALLING') return Icons.trending_down;
    return Icons.trending_flat;
  }

  Color _trendColor(String? trend) {
    if (trend == 'RISING')  return Colors.red;
    if (trend == 'FALLING') return Colors.green;
    return Colors.white38;
  }
}
