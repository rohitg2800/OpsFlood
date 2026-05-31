// lib/screens/live_stations_screen.dart
// OpsFlood — LiveStationsScreen v2  "Uses real providers"
// Uses liveLevelsProvider (List<FloodData>) from flood_providers.dart.
// StationTile is inlined here — no separate widget file needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class LiveStationsScreen extends ConsumerWidget {
  const LiveStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s        = context.l10n;
    final stations = ref.watch(liveLevelsProvider);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: Text(
          s.liveData,
          style: const TextStyle(
            color: AppPalette.textWhite,
            fontSize: 18, fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textWhite),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppPalette.cyan.withValues(alpha: 0.10),
          ),
        ),
      ),
      body: stations.isEmpty
          ? _EmptyStations(label: s.noStationsFound)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: stations.length,
              itemBuilder: (_, i) => _StationTile(data: stations[i]),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE STATION TILE  (built from FloodData — the real model)
// ─────────────────────────────────────────────────────────────────────────────
class _StationTile extends StatelessWidget {
  final FloodData data;
  const _StationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final col  = data.priorityColor;
    final fill = (data.capacityPercent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: 0.10),
                  border: Border.all(color: col.withValues(alpha: 0.28)),
                ),
                child: Icon(_iconFor(data.riskLevel), color: col, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.city,
                      style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontSize: 13, fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((data.riverName ?? '').isNotEmpty) data.riverName!,
                        if (data.state.isNotEmpty) data.state,
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.currentLevel.toStringAsFixed(2)} m',
                    style: TextStyle(
                      color: col, fontSize: 18,
                      fontWeight: FontWeight.w900, letterSpacing: -0.6,
                    ),
                  ),
                  _RiskBadge(label: data.riskLevel, color: col),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Capacity fill bar
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: AppPalette.abyss4,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [col.withValues(alpha: 0.40), col],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: col.withValues(alpha: 0.40),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _mini('W ${data.warningLevel.toStringAsFixed(1)} m',
                  AppPalette.amber),
              _mini('D ${data.dangerLevel.toStringAsFixed(1)} m',
                  AppPalette.danger),
              _mini('${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                  AppPalette.cyan),
              Text(
                DateFormat('HH:mm').format(data.lastUpdated.toLocal()),
                style: const TextStyle(
                  color: AppPalette.textDim, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(
        color: c, fontSize: 9, fontWeight: FontWeight.w600));

  IconData _iconFor(String r) => switch (r) {
    'CRITICAL' => Icons.crisis_alert_rounded,
    'SEVERE'   => Icons.error_outline_rounded,
    'MODERATE' => Icons.warning_amber_rounded,
    _          => Icons.check_circle_outline_rounded,
  };
}

class _RiskBadge extends StatelessWidget {
  final String label; final Color color;
  const _RiskBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(label,
            style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

class _EmptyStations extends StatelessWidget {
  final String label;
  const _EmptyStations({required this.label});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppPalette.cyan.withValues(alpha: 0.12),
                  AppPalette.abyss2,
                ]),
                border: Border.all(
                    color: AppPalette.cyan.withValues(alpha: 0.20)),
              ),
              child: const Icon(Icons.sensors_off_rounded,
                  color: AppPalette.cyan, size: 32),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
