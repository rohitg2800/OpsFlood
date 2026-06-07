// lib/screens/river_detail_screen.dart
// OpsFlood — River detail screen  (v3 — district row added)
library;

import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../theme/river_theme.dart';
import '../widgets/ops_area_chart.dart';
import '../widgets/probability_bar_widget.dart';
import '../widgets/risk_bar.dart';

class RiverDetailScreen extends StatelessWidget {
  final FloodData data;
  const RiverDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final col = data.priorityColor;
    return Scaffold(
      backgroundColor: AppPalette.abyss,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss2,
        foregroundColor: AppPalette.textWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.city,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: AppPalette.textWhite,
              ),
            ),
            // River · District · State
            Text(
              _headerSub,
              style: const TextStyle(
                fontSize: 11, color: AppPalette.textGrey,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _RiskBadge(risk: data.riskLevel, color: col),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Location meta card ──────────────────────────────────
            _MetaCard(
              river:    data.riverName ?? '—',
              district: data.district,
              state:    data.state,
              color:    col,
            ),
            const SizedBox(height: 14),

            // ── Level stats ─────────────────────────────────────────
            _SectionTitle('Water Level'),
            _LevelGrid(data: data, col: col),
            const SizedBox(height: 14),

            // ── Risk bar ────────────────────────────────────────────
            _SectionTitle('Risk Gauge'),
            RiskBar(
              currentLevel: data.currentLevel,
              warningLevel: data.warningLevel,
              dangerLevel:  data.dangerLevel,
            ),
            const SizedBox(height: 14),

            // ── Rainfall ────────────────────────────────────────────
            _SectionTitle('Rainfall & Flow'),
            _RainfallCard(data: data, col: col),
            const SizedBox(height: 14),

            // ── Probability bar ─────────────────────────────────────
            _SectionTitle('Flood Probability'),
            ProbabilityBarWidget(
              probability: data.capacityPercent / 100,
              riskLevel:   data.riskLevel,
            ),
            const SizedBox(height: 14),

            // ── Trend chart ─────────────────────────────────────────
            _SectionTitle('Recent Trend'),
            OpsAreaChart(
              floodData: data,
              height:    180,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String get _headerSub {
    final parts = <String>[];
    if ((data.riverName ?? '').isNotEmpty) parts.add(data.riverName!);
    if (data.district.isNotEmpty)          parts.add(data.district);
    if (data.state.isNotEmpty)             parts.add(data.state);
    return parts.join('  ·  ');
  }
}

// ── Meta card ─────────────────────────────────────────────────────────────────
class _MetaCard extends StatelessWidget {
  final String river;
  final String district;
  final String state;
  final Color  color;
  const _MetaCard({
    required this.river, required this.district,
    required this.state, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppPalette.abyss2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          _MetaRow(
            icon:  Icons.water_outlined,
            label: 'River',
            value: river,
            color: color,
          ),
          if (district.isNotEmpty) ...[
            const Divider(color: AppPalette.abyss4, height: 14),
            _MetaRow(
              icon:  Icons.location_city_outlined,
              label: 'District (Zila)',
              value: district,
              color: color,
            ),
          ],
          const Divider(color: AppPalette.abyss4, height: 14),
          _MetaRow(
            icon:  Icons.map_outlined,
            label: 'State',
            value: state,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _MetaRow({
    required this.icon, required this.label,
    required this.value, required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: color.withValues(alpha: 0.80)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 11),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color:      AppPalette.textWhite,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

// ── Level grid ────────────────────────────────────────────────────────────────
class _LevelGrid extends StatelessWidget {
  final FloodData data;
  final Color     col;
  const _LevelGrid({required this.data, required this.col});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Current',
            value: '${data.currentLevel.toStringAsFixed(2)} m',
            color: col,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Warning',
            value: '${data.warningLevel.toStringAsFixed(2)} m',
            color: AppPalette.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Danger',
            value: '${data.dangerLevel.toStringAsFixed(2)} m',
            color: AppPalette.danger,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatTile({
    required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color:        AppPalette.abyss2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 10)),
          ],
        ),
      );
}

// ── Rainfall card ─────────────────────────────────────────────────────────────
class _RainfallCard extends StatelessWidget {
  final FloodData data;
  final Color     col;
  const _RainfallCard({required this.data, required this.col});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppPalette.abyss2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _RainStat(
              label: 'Rainfall',
              value: '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
              icon:  Icons.water_drop_outlined,
              color: const Color(0xFF38BDF8),
            ),
            if (data.imdRainfallMm != null)
              _RainStat(
                label: 'IMD Rain',
                value: '${data.imdRainfallMm!.toStringAsFixed(1)} mm',
                icon:  Icons.cloud_outlined,
                color: const Color(0xFF818CF8),
              ),
            if (data.flowRate != null)
              _RainStat(
                label: 'Flow',
                value: '${data.flowRate!.toStringAsFixed(0)} m³/s',
                icon:  Icons.water_outlined,
                color: col,
              ),
          ],
        ),
      );
}

class _RainStat extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _RainStat({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
            color: AppPalette.textGrey, fontSize: 10)),
        ],
      );
}

// ── Misc helpers ──────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color:         AppPalette.textGrey,
            fontSize:      10,
            fontWeight:    FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _RiskBadge extends StatelessWidget {
  final String risk;
  final Color  color;
  const _RiskBadge({required this.risk, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Text(
          risk,
          style: TextStyle(
            color:      color,
            fontSize:   11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
