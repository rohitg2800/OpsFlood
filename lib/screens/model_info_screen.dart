// lib/screens/model_info_screen.dart
// OpsFlood — ModelInfoScreen v4  (Premium minimal)
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

  static const _metrics = [
    _Metric('Algorithm',   'XGBoost + Random Forest Ensemble', AppPalette.cyan),
    _Metric('Accuracy',    '94.2%',                            AppPalette.safe),
    _Metric('Features',    '28 hydro-meteorological inputs',   AppPalette.amber),
    _Metric('Data Source', 'CWC · IMD · WRIS live telemetry',  AppPalette.textGrey),
    _Metric('Prediction',  '24 h ahead with 6 h intervals',   AppPalette.cyan),
    _Metric('Calibration', 'Bihar MSSL gauge network',         AppPalette.textGrey),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss1,
        elevation: 0,
        title: const Text('ML Model Info',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppPalette.textWhite)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppPalette.textGrey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppPalette.glassMorph(
                bg: AppPalette.abyss2,
                borderColor: AppPalette.cyan.withValues(alpha: 0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppPalette.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppPalette.cyan.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Icon(Icons.model_training_rounded,
                          color: AppPalette.cyan, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Flood Prediction Engine',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: AppPalette.textWhite)),
                        Text('OpsFlood ML v2.4',
                            style: TextStyle(
                                fontSize: 12, color: AppPalette.textGrey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ensemble model combining gradient-boosted trees and random forest '
                  'classifiers trained on 12 years of CWC gauge readings, IMD rainfall '
                  'data, and WRIS river discharge records across Bihar and adjacent states.',
                  style: TextStyle(
                      fontSize: 13, color: AppPalette.textGrey, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Key Specifications'),
          const SizedBox(height: 12),
          ..._metrics.map((m) => _MetricRow(metric: m)),
          const SizedBox(height: 24),
          const _SectionHeader('Feature Importance'),
          const SizedBox(height: 12),
          ..._featureImportance.map((f) => _FeatureBar(name: f.name, pct: f.pct)),
        ],
      ),
    );
  }

  static const _featureImportance = [
    _Feature('River level (24h trend)', 0.31),
    _Feature('Upstream discharge',      0.22),
    _Feature('Rainfall intensity',      0.18),
    _Feature('Soil moisture index',     0.11),
    _Feature('Reservoir release',       0.09),
    _Feature('Seasonal index',          0.05),
    _Feature('Other features',          0.04),
  ];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(
              color: AppPalette.cyan,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: AppPalette.textWhite, letterSpacing: 0.5)),
    ],
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.abyssStroke, width: 1),
      ),
      child: Row(
        children: [
          Text(metric.label,
              style: const TextStyle(fontSize: 12, color: AppPalette.textGrey)),
          const Spacer(),
          Text(metric.value, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: metric.color)),
        ],
      ),
    ),
  );
}

class _FeatureBar extends StatelessWidget {
  const _FeatureBar({required this.name, required this.pct});
  final String name;
  final double pct;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(name,
                style: const TextStyle(fontSize: 12, color: AppPalette.textGrey))),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppPalette.amber)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 5, color: AppPalette.abyssStroke),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppPalette.cyan, AppPalette.amber]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric {
  const _Metric(this.label, this.value, this.color);
  final String label, value;
  final Color color;
}

class _Feature {
  const _Feature(this.name, this.pct);
  final String name;
  final double pct;
}
