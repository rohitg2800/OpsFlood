// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/context_l10n.dart';
import '../providers/flood_providers.dart';
import '../widgets/alert_card.dart';

class AlertsScreen extends ConsumerWidget {
  static const route = '/alerts';
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s       = context.l10n;
    final alerts  = ref.watch(floodAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.floodAlerts),
        centerTitle: true,
      ),
      body: alerts.when(
        loading: () => Center(child: Text(s.loading)),
        error:   (e, _) => Center(child: Text('${s.noData}: $e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(s.noAlerts))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => AlertCard(alert: list[i]),
              ),
      ),
    );
  }
}
