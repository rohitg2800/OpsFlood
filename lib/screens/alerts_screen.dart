// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flood_providers.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  /// Named route used in main.dart route table.
  static const String route = '/alerts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = ref.watch(realTimeServiceProvider);
    final alerts = rt.criticalAlerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Alerts'),
        centerTitle: true,
      ),
      body: alerts.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No active alerts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All monitored stations are within safe levels.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final alert = alerts[index] as Map<String, dynamic>;
                final city      = alert['city']      as String? ?? 'Unknown';
                final riskLevel = alert['riskLevel'] as String? ?? 'UNKNOWN';
                final level     = alert['level']     as double?;

                final isCritical = riskLevel == 'CRITICAL';
                final color      = isCritical ? Colors.red : Colors.orange;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isCritical ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: color,
                      size: 32,
                    ),
                    title: Text(
                      city,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    subtitle: Text(
                      level != null
                          ? '$riskLevel  •  ${level.toStringAsFixed(2)} m'
                          : riskLevel,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Text(
                        riskLevel,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
