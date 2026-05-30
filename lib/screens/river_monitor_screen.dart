// lib/screens/river_monitor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flood_providers.dart';
import '../models/flood_data.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});

  @override
  ConsumerState<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen> {
  String _query = '';

  List<FloodData> _filtered(List<FloodData> levels) {
    if (_query.isEmpty) return levels;
    final q = _query.toLowerCase();
    return levels.where((fd) =>
        fd.city.toLowerCase().contains(q) ||
        fd.state.toLowerCase().contains(q) ||
        (fd.riverName?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rt     = ref.watch(realTimeServiceProvider);
    final levels = _filtered(rt.liveLevels);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rivers'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search city, state or river…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: rt.isLoading && levels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : levels.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? 'No live data available.' : 'No results for "$_query".',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: levels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final fd    = levels[index];
                    final color = fd.priorityColor;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.waves, color: color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${fd.riverName ?? 'N/A'}  •  ${fd.state}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color),
                                  ),
                                ),
                                Chip(
                                  label: Text(fd.riskLevel),
                                  backgroundColor: color.withAlpha(30),
                                  labelStyle: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fd.city,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            _LevelBar(
                              current: fd.currentLevel,
                              warning: fd.warningLevel,
                              danger:  fd.dangerLevel,
                              color:   color,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Level: ${fd.currentLevel.toStringAsFixed(2)} m',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  'Cap: ${fd.capacityPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  'Rain: ${fd.effectiveRainfallMm.toStringAsFixed(1)} mm',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  final double current;
  final double warning;
  final double danger;
  final Color  color;

  const _LevelBar({
    required this.current,
    required this.warning,
    required this.danger,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Safe', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            Text('Warn ${warning.toStringAsFixed(1)} m',
                style: TextStyle(fontSize: 11, color: Colors.orange[700])),
            Text('Danger ${danger.toStringAsFixed(1)} m',
                style: TextStyle(fontSize: 11, color: Colors.red[700])),
          ],
        ),
      ],
    );
  }
}
