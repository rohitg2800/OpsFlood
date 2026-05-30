// lib/screens/live_stations_screen.dart
// Fixed: FloodData.river → FloodData.riverName
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';

class LiveStationsScreen extends ConsumerStatefulWidget {
  const LiveStationsScreen({super.key});

  @override
  ConsumerState<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends ConsumerState<LiveStationsScreen> {
  String _query = '';

  List<FloodData> _filtered(List<FloodData> stations) {
    if (_query.isEmpty) return stations;
    final q = _query.toLowerCase();
    return stations.where((s) {
      return s.city.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q) ||
          (s.riverName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rt       = ref.watch(realTimeServiceProvider);
    final stations = _filtered(rt.liveLevels);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Stations'),
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
      body: rt.isLoading && stations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : stations.isEmpty
              ? const Center(child: Text('No stations found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: stations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s     = stations[i];
                    final color = s.priorityColor;
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withAlpha(30),
                          child: Icon(Icons.water, color: color),
                        ),
                        title: Text(
                          s.city,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${s.riverName ?? 'N/A'} • ${s.state}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${s.currentLevel.toStringAsFixed(2)} m',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: color),
                            ),
                            Text(
                              s.riskLevel,
                              style: TextStyle(fontSize: 12, color: color),
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
