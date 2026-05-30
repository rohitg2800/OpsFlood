import 'package:flutter/material.dart';
import '../models/river_station.dart';

class StationCard extends StatelessWidget {
  final RiverStation station;
  final VoidCallback? onDelete;

  const StationCard({super.key, required this.station, this.onDelete});

  Color _dangerColor(DangerClass dc) {
    switch (dc) {
      case DangerClass.normal:      return const Color(0xFF437A22);
      case DangerClass.aboveNormal: return const Color(0xFFD19900);
      case DangerClass.severe:      return const Color(0xFFDA7101);
      case DangerClass.extreme:     return const Color(0xFFA13544);
    }
  }

  Color _dangerBg(DangerClass dc) {
    switch (dc) {
      case DangerClass.normal:      return const Color(0xFF437A22).withOpacity(0.12);
      case DangerClass.aboveNormal: return const Color(0xFFD19900).withOpacity(0.14);
      case DangerClass.severe:      return const Color(0xFFDA7101).withOpacity(0.14);
      case DangerClass.extreme:     return const Color(0xFFA13544).withOpacity(0.14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc  = station.dangerClass;
    final col = _dangerColor(dc);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── top bar ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.city,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${station.state}  ·  ${station.river}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _dangerBg(dc),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dc.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: col,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withOpacity(0.35)),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]
              ],
            ),
          ),

          // ── station name + reading ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.sensors, size: 14, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.station,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ),
                Text(
                  '${station.current.toStringAsFixed(2)} m',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ── threshold row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ThresholdChip(label: 'Warning', value: station.warning, color: const Color(0xFFD19900)),
                const SizedBox(width: 8),
                _ThresholdChip(label: 'Danger',  value: station.danger,  color: const Color(0xFFDA7101)),
                const SizedBox(width: 8),
                _ThresholdChip(label: 'HFL',     value: station.hfl,     color: const Color(0xFFA13544)),
              ],
            ),
          ),

          // ── progress bar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 10,
                    child: LinearProgressIndicator(
                      value: station.progressPct,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(col),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // FIX: wrap each label in Expanded so the Row never overflows
                // on narrow screens. FittedBox lets text shrink if needed.
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text('0 m', style: _scaleStyle),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.center,
                        fit: BoxFit.scaleDown,
                        child: Text('Warning', style: _scaleStyle),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.center,
                        fit: BoxFit.scaleDown,
                        child: Text('Danger', style: _scaleStyle),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'HFL ${station.hfl.toStringAsFixed(1)} m',
                          style: _scaleStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _scaleStyle = TextStyle(
    fontSize: 10,
    color: Color(0xFF7B8A99),
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class _ThresholdChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ThresholdChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.85))),
            const SizedBox(height: 2),
            Text(
              '${value.toStringAsFixed(2)} m',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
