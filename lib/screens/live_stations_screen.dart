// lib/screens/live_stations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../theme/app_theme.dart';

class LiveStationsScreen extends ConsumerWidget {
  const LiveStationsScreen({super.key});
  static const route = '/live_stations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtAsync = ref.watch(realTimeServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Live CWC Stations',
            style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppTheme.cyan),
        elevation: 0,
      ),
      body: rtAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.cyan)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppTheme.danger))),
        data: (rt) {
          final stations = rt.cwcStations;
          if (stations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_outlined, size: 56, color: AppTheme.cyan),
                  SizedBox(height: 12),
                  Text('No live station data yet',
                      style: TextStyle(color: AppTheme.textMuted)),
                  SizedBox(height: 6),
                  Text('Pull down to refresh',
                      style: TextStyle(color: AppTheme.textFaint, fontSize: 12)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.cyan,
            onRefresh: () => ref.read(realTimeServiceProvider.notifier)
                .refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: stations.length,
              itemBuilder: (context, i) {
                final s = stations[i];
                final city = (s is Map ? s['city'] : null) ??
                    s.toString();
                final risk = (s is Map ? s['riskLevel'] : null) ??
                    'UNKNOWN';
                final level = s is Map ? s['currentLevel'] : null;
                final Color riskColor = risk == 'CRITICAL'
                    ? AppTheme.danger
                    : risk == 'HIGH' || risk == 'SEVERE'
                        ? AppTheme.warning
                        : AppTheme.cyan;
                return Card(
                  color: AppTheme.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: riskColor.withOpacity(0.15),
                      child: Icon(Icons.water_drop,
                          color: riskColor, size: 20),
                    ),
                    title: Text(city.toString(),
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                    subtitle: level != null
                        ? Text('Level: ${level.toStringAsFixed(2)} m',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12))
                        : const Text('Level: N/A',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: riskColor.withOpacity(0.4)),
                      ),
                      child: Text(risk.toString(),
                          style: TextStyle(
                              color: riskColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
