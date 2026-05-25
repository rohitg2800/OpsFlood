// flood_gauge.dart — DEPRECATED
// Gauge widget removed in UI v4 (Abyss Ops rebuild).
// All gauge usages replaced by horizontal RiskBar or fl_chart BarChart.
// This file is kept as a stub to avoid broken imports during migration.
// TODO: Remove all imports of this file and delete it.

import 'package:flutter/material.dart';

@Deprecated('Use RiskBar or fl_chart BarChart instead. Gauge removed in v4.')
class FloodGauge extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color color;
  const FloodGauge({
    super.key,
    this.value = 0,
    this.maxValue = 100,
    this.color = const Color(0xFF00C6FF),
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
