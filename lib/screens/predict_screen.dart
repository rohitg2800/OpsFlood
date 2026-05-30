// lib/screens/predict_screen.dart
// EQUINOX-BH — ML flood prediction via backend /predict endpoint.
library;

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/ops_client.dart';
import '../theme/river_theme.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});
  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _levelCtrl = TextEditingController(text: '12.5');
  final _rainCtrl  = TextEditingController(text: '300');

  bool    _loading  = false;
  String? _result;
  String? _error;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _result = null; _error = null; });
    try {
      final level = double.parse(_levelCtrl.text.trim());
      final rain  = double.parse(_rainCtrl.text.trim());
      final res   = await OpsClient.instance.post(
        AppConfig.epPredict,
        {
          'peak_level_m':    level,
          'rainfall_7d_mm':  rain,
          'state':           'Bihar',
        },
      );
      final risk = res['risk_level'] ?? res['prediction'] ?? res['severity'] ?? 'UNKNOWN';
      setState(() { _result = risk as String; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _levelCtrl.dispose();
    _rainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = {
      'CRITICAL': Colors.red,
      'SEVERE':   Colors.orange,
      'MODERATE': Colors.yellow,
      'LOW':      Colors.green,
    }[_result] ?? Colors.blueGrey;

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        title: const Text('Flood Prediction'),
        backgroundColor: AppPalette.navy1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter river conditions to get an ML-powered flood risk prediction.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              _field(_levelCtrl, 'Peak Water Level (m)', 'e.g. 12.5'),
              const SizedBox(height: 16),
              _field(_rainCtrl, '7-day Rainfall (mm)', 'e.g. 300'),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loading ? null : _predict,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.model_training),
                label: Text(_loading ? 'Predicting…' : 'Predict Risk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01696F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_error != null) ...
                [
                  const SizedBox(height: 16),
                  Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                ],
              if (_result != null) ...
                [
                  const SizedBox(height: 24),
                  Card(
                    color: AppPalette.navy1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Predicted Risk Level',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 12),
                          Text(
                            _result!,
                            style: TextStyle(
                              color:      resultColor,
                              fontSize:   36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) =>
      TextFormField(
        controller:  ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText:       label,
          hintText:        hint,
          labelStyle:      const TextStyle(color: Colors.white54),
          hintStyle:       const TextStyle(color: Colors.white30),
          enabledBorder:   const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder:   const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4F98A3))),
          errorBorder:     const OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
          focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (double.tryParse(v.trim()) == null) return 'Enter a number';
          return null;
        },
      );
}
