// lib/widgets/map/map_legend.dart
// MapSourceLegend — collapsible overlay showing data sources + risk scale.
import 'package:flutter/material.dart';
import '../../providers/map_command_provider.dart';
import '../../theme/rx.dart';
import 'map_risk_helpers.dart';

class MapSourceLegend extends StatelessWidget {
  final SyncMeta     syncMeta;
  final VoidCallback onClose;

  const MapSourceLegend({
    super.key,
    required this.syncMeta,
    required this.onClose,
  });

  static const _sources = [
    ('WRD_BIHAR', '🏛', 'Bihar Water Resources Dept'),
    ('CWC_FFEM',  '🌊', 'Central Water Commission'),
    ('GLOFAS',    '🛰', 'GloFAS Global Forecast'),
  ];

  static const _legend = [
    (DangerClass.extreme,     'Critical'),
    (DangerClass.severe,      'High'),
    (DangerClass.aboveNormal, 'Moderate'),
    (DangerClass.normal,      'Low'),
  ];

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        rc.cardBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: rc.stroke),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Text(
                'DATA SOURCES',
                style: TextStyle(
                  color:         rc.textPrimary,
                  fontSize:      11,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close,
                    size: 14, color: rc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Source rows
          for (final (src, emoji, label) in _sources) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        src,
                        style: TextStyle(
                          color:         rc.accent,
                          fontSize:      10,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(label,
                          style: TextStyle(
                              color:    rc.textSecondary,
                              fontSize: 10)),
                      Text(
                        'Updated: ${syncMeta.labelFor(src)}',
                        style: TextStyle(
                          color:    rc.textSecondary.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Divider(height: 12, color: rc.stroke),

          // Risk scale
          Text(
            'RISK SCALE',
            style: TextStyle(
              color:         rc.textPrimary,
              fontSize:      11,
              fontWeight:    FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          for (final (dc, lbl) in _legend)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color:        riskColor(dc, opacity: 0.8),
                      borderRadius: BorderRadius.circular(3),
                      border:       Border.all(
                          color: riskColorSolid(dc).withOpacity(0.6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(lbl,
                      style: TextStyle(
                          color:    rc.textSecondary,
                          fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
