// lib/screens/live_stations_screen.dart
// EQUINOX-BH — LiveStationsScreen
// Lists live CWC river stations sorted by DangerClass (extreme → normal).
// Uses RealTimeService.cwcStations (List<dynamic> → cast to FloodData).
library;

import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';

class LiveStationsScreen extends StatefulWidget {
  const LiveStationsScreen({super.key});
  @override
  State<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends State<LiveStationsScreen> {
  final RealTimeService _svc = RealTimeService();
  String _query = '';

  static const _order = ['CRITICAL', 'SEVERE', 'MODERATE', 'LOW'];

  List<FloodData> get _filtered {
    final all = _svc.cwcStations
        .whereType<FloodData>()
        .toList()
      ..sort((a, b) {
        final ai = _order.indexOf(a.riskLevel ?? 'LOW');
        final bi = _order.indexOf(b.riskLevel ?? 'LOW');
        return ai.compareTo(bi);
      });
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) =>
        s.city.toLowerCase().contains(q) ||
        s.river.toLowerCase().contains(q) ||
        s.state.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stations = _filtered;
    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        title: const Text('Live Stations'),
        backgroundColor: AppPalette.navy1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search city / river / state…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: AppPalette.navy1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${_svc.cwcStations.length} stations',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _svc.isLoading && stations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : stations.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? 'No stations yet — pull to refresh' : 'No stations match "$_query"',
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _svc.refreshData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: stations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _stationCard(stations[i]),
                  ),
                ),
    );
  }

  Widget _stationCard(FloodData s) {
    final risk  = s.riskLevel ?? 'LOW';
    final color = {
      'CRITICAL': Colors.red,
      'SEVERE':   Colors.orange,
      'MODERATE': Colors.yellow,
      'LOW':      Colors.green,
    }[risk] ?? Colors.green;

    final pct = s.capacityPercent.clamp(0.0, 100.0);

    return Card(
      color: AppPalette.navy1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.city,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(risk,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${s.river} • ${s.state}',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.white12,
                color: color,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${s.currentLevel.toStringAsFixed(2)} m',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if (s.flowRate != null)
                  Text('${s.flowRate!.toStringAsFixed(1)} m³/s',
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
