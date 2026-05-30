// lib/screens/river_monitor_screen.dart
// EQUINOX-BH — Live river level monitor for all Bihar cities.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class RiverMonitorScreen extends ConsumerWidget {
  const RiverMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc    = ref.watch(realTimeProvider);
    final levels = svc.liveLevels;

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        title: const Text('River Monitor'),
        backgroundColor: AppPalette.navy1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: svc.refreshData,
          ),
        ],
      ),
      body: svc.isLoading && levels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : levels.isEmpty
              ? const Center(
                  child: Text('No river data', style: TextStyle(color: Colors.white54)),
                )
              : RefreshIndicator(
                  onRefresh: svc.refreshData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: levels.length,
                    itemBuilder: (_, i) {
                      final fd    = levels[i];
                      final pct   = fd.capacityPercent.clamp(0.0, 100.0);
                      final risk  = fd.riskLevel ?? 'LOW';
                      final color = {
                        'CRITICAL': Colors.red,
                        'SEVERE':   Colors.orange,
                        'MODERATE': Colors.yellow,
                        'LOW':      Colors.green,
                      }[risk] ?? Colors.green;

                      return Card(
                        color: AppPalette.navy1,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(fd.city,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      border: Border.all(color: color),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(risk,
                                        style: TextStyle(
                                            color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${fd.river}  •  ${fd.state}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  backgroundColor: Colors.white12,
                                  color: color,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Level: ${fd.currentLevel.toStringAsFixed(2)} m',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('${pct.toStringAsFixed(1)}% of danger',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
