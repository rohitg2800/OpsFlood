// lib/screens/alerts_screen.dart
// EQUINOX-BH — AlertsScreen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  static const route = '/alerts';

  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  static const _order = ['CRITICAL', 'SEVERE', 'MODERATE', 'LOW'];

  @override
  Widget build(BuildContext context) {
    final svc    = ref.watch(realTimeProvider);
    final levels = svc.liveLevels;

    final sorted = [...levels]
      ..sort((a, b) {
        final ai = _order.indexOf(a.riskLevel ?? 'LOW');
        final bi = _order.indexOf(b.riskLevel ?? 'LOW');
        return ai.compareTo(bi);
      });

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        title: const Text('Alerts'),
        backgroundColor: AppPalette.navy1,
        actions: [
          if (svc.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Text('No active alerts', style: TextStyle(color: Colors.white54)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final fd   = sorted[i];
                final risk = fd.riskLevel ?? 'LOW';
                final color = {
                  'CRITICAL': Colors.red,
                  'SEVERE':   Colors.orange,
                  'MODERATE': Colors.yellow,
                  'LOW':      Colors.green,
                }[risk] ?? Colors.grey;

                return Card(
                  color: AppPalette.navy1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Icon(Icons.water, color: color),
                    ),
                    title: Text(
                      fd.city,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${fd.state} • ${fd.river}  |  ${fd.currentLevel.toStringAsFixed(1)} m',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        border: Border.all(color: color),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(risk,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
