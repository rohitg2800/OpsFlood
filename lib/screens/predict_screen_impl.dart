// lib/screens/predict_screen_impl.dart  — 3-D UI predict screen
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/flood_provider.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _levelCtl = TextEditingController();
  final _rainCtl  = TextEditingController();
  final _inflow   = TextEditingController();
  bool  _loading  = false;
  Map<String, dynamic>? _result;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _result = null; });
    await Future.delayed(const Duration(seconds: 1));
    final level = double.tryParse(_levelCtl.text) ?? 0;
    final rain  = double.tryParse(_rainCtl.text) ?? 0;
    final risk  = ((level * 0.4) + (rain * 0.01)).clamp(0.0, 1.0);
    setState(() {
      _loading = false;
      _result = {
        'risk': risk,
        'label': risk > 0.8 ? 'CRITICAL' : risk > 0.5 ? 'HIGH' : 'MODERATE',
        'color': risk > 0.8
            ? RiverColors.of(context).danger
            : risk > 0.5
                ? RiverColors.of(context).warning
                : RiverColors.of(context).safe,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Flood Predictor',
            subtitle: 'AI-assisted risk estimation',
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: t.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Td3Card(
                  elevation: Td3.elevMid,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Td3SectionHeader('Input Parameters'),
                          const SizedBox(height: 14),
                          Td3InputField(
                            controller: _levelCtl,
                            label: 'Current Water Level (m)',
                            hint: 'e.g. 5.40',
                            icon: Icons.water_rounded,
                            numeric: true,
                          ),
                          const SizedBox(height: 12),
                          Td3InputField(
                            controller: _rainCtl,
                            label: 'Rainfall (mm/day)',
                            hint: 'e.g. 45',
                            icon: Icons.water_drop_rounded,
                            numeric: true,
                          ),
                          const SizedBox(height: 12),
                          Td3InputField(
                            controller: _inflow,
                            label: 'Upstream Inflow (m³/s)',
                            hint: 'Optional',
                            icon: Icons.trending_up_rounded,
                            numeric: true,
                            required: false,
                          ),
                          const SizedBox(height: 20),
                          Td3Button(
                            label: 'Run Prediction',
                            icon: Icons.auto_graph_rounded,
                            onTap: _predict,
                            loading: _loading,
                            color: t.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_result != null) ...[const SizedBox(height: 16),
                  _ResultCard(result: _result!)],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final color = result['color'] as Color;
    final risk  = result['risk'] as double;
    final label = result['label'] as String;
    return Td3Card(
      accentColor: color,
      elevation: Td3.elevHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Td3SectionHeader('Prediction Result'),
                const Spacer(),
                Td3Chip(label: label, color: color),
              ],
            ),
            const SizedBox(height: 16),
            Td3ProgressBar(value: risk, fillColor: color, height: 12),
            const SizedBox(height: 10),
            Text(
              '${(risk * 100).toStringAsFixed(1)}% flood risk',
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8)
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}
