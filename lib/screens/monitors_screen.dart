// lib/screens/monitors_screen.dart
// EQUINOX-BH — Multi-location monitoring dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class MonitorsScreen extends ConsumerWidget {
  const MonitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc      = ref.watch(realTimeProvider);
    final monitor  = svc.monitoringData;
    final levels   = svc.liveLevels;

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        title: const Text('Multi-Location Monitor'),
        backgroundColor: AppPalette.navy1,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: svc.refreshData)],
      ),
      body: RefreshIndicator(
        onRefresh: svc.refreshData,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Summary row
            Card(
              color: AppPalette.navy1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _kpi('Locations',  '${monitor.totalLocations}',  Colors.blueAccent),
                    _kpi('Critical',   '${monitor.criticalCount}',   Colors.red),
                    _kpi('Severe',     '${monitor.severeCount}',     Colors.orange),
                    _kpi('Moderate',   '${monitor.moderateCount}',   Colors.yellow),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (svc.isLoading && levels.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ))
            else if (levels.isEmpty)
              const Center(
                child: Text('No data available', style: TextStyle(color: Colors.white54)),
              )
            else
              ...levels.map((fd) {
                final risk  = fd.riskLevel ?? 'LOW';
                final color = {
                  'CRITICAL': Colors.red,
                  'SEVERE':   Colors.orange,
                  'MODERATE': Colors.yellow,
                  'LOW':      Colors.green,
                }[risk] ?? Colors.green;

                return Card(
                  color: AppPalette.navy1,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: color),
                    title: Text(fd.city,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${fd.river} • ${fd.currentLevel.toStringAsFixed(2)} m'
                      '  |  rain: ${fd.rainfall24h != null ? "${fd.rainfall24h!.toStringAsFixed(1)} mm" : "—"}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        border: Border.all(color: color),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(risk,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ],
  );
}
