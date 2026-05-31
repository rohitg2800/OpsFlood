// lib/screens/model_info_screen.dart
import 'package:flutter/material.dart';
import '../l10n/context_l10n.dart';

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.mlModelInfo),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title:    s.floodPredictionEngine,
            subtitle: 'OpsFlood ML v2.4',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title:    s.predictionModel,
            subtitle: 'XGBoost + Random Forest Ensemble',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title:    s.accuracy,
            subtitle: '94.2%',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title:    s.confidence,
            subtitle: '91.8%',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _InfoCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title:    Text(title,    style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
