// lib/screens/monitors_screen.dart
// Fixed: floodDataForCity → dataForCity, realTimeServiceProvider alias resolved
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flood_providers.dart';

class MonitorsScreen extends ConsumerWidget {
  const MonitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt      = ref.watch(realTimeServiceProvider);
    final monitors = ref.watch(monitoredCitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitors'),
        centerTitle: true,
      ),
      body: monitors.isEmpty
          ? const Center(child: Text('No monitored cities configured.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: monitors.length,
              itemBuilder: (context, index) {
                final city = monitors[index];
                final fd   = rt.dataForCity(city);  // was: floodDataForCity

                if (fd == null) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(city),
                      subtitle: const Text('No data yet'),
                      leading: const Icon(Icons.sensors_off, color: Colors.grey),
                    ),
                  );
                }

                final color = fd.priorityColor;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withAlpha(30),
                          child: Icon(Icons.water_drop, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fd.city,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fd.riverName ?? 'N/A'} • ${fd.currentLevel.toStringAsFixed(2)} m'
                                '  |  rain: ${fd.effectiveRainfallMm.toStringAsFixed(1)} mm',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            fd.riskLevel,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
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
