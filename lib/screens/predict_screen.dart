// lib/screens/predict_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final _formKey = GlobalKey<FormState>();

  final _peakLevelCtrl   = TextEditingController();
  final _rainfallCtrl    = TextEditingController();
  final _dischargeCtrl   = TextEditingController();
  final _stateCtrl       = TextEditingController(text: 'Bihar');

  bool   _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _peakLevelCtrl.dispose();
    _rainfallCtrl.dispose();
    _dischargeCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _result = null; _error = null; });

    final payload = {
      'state':            _stateCtrl.value.text.trim(),
      'peak_level_m':     double.parse(_peakLevelCtrl.value.text.trim()),
      'rainfall_7d_mm':   double.parse(_rainfallCtrl.value.text.trim()),
      'discharge_m3s':    double.tryParse(_dischargeCtrl.value.text.trim()) ?? 0.0,
    };

    try {
      final uri = Uri.parse(AppConfig.epPredict);
      final res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload))
          .timeout(AppConfig.coldStartTimeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final level = body['risk_level'] ?? body['riskLevel'] ?? 'UNKNOWN';
        final prob  = body['probability'] ?? body['confidence'];
        setState(() {
          _result = prob != null
              ? '$level  (confidence: ${(prob * 100).toStringAsFixed(1)}%)'
              : level.toString();
        });
      } else {
        // fixed: was '\${res.statusCode}' — escaped dollar sign prevented interpolation
        setState(() => _error = 'Backend returned HTTP ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flood Risk Predictor'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Field(
                  ctrl: _stateCtrl,
                  label: 'State',
                  hint: 'e.g. Bihar'),
              const SizedBox(height: 14),
              _Field(
                  ctrl: _peakLevelCtrl,
                  label: 'Peak Level (m)',
                  hint: 'e.g. 12.5',
                  numeric: true),
              const SizedBox(height: 14),
              _Field(
                  ctrl: _rainfallCtrl,
                  label: '7-day Rainfall (mm)',
                  hint: 'e.g. 450',
                  numeric: true),
              const SizedBox(height: 14),
              _Field(
                  ctrl: _dischargeCtrl,
                  label: 'Discharge (m³/s)  — optional',
                  hint: 'e.g. 8500',
                  numeric: true,
                  required: false),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading ? null : _predict,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.analytics_outlined),
                label: Text(_loading ? 'Predicting…' : 'Predict Risk'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_result != null) ..._resultCard(_result!, isError: false),
              if (_error  != null) ..._resultCard(_error!,  isError: true),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _resultCard(String text, {required bool isError}) => [
    const SizedBox(height: 20),
    Card(
      color: isError ? Colors.red.shade50 : Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isError ? 'Error: $text' : 'Risk Level: $text',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isError ? Colors.red.shade800 : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String  label;
  final String  hint;
  final bool    numeric;
  final bool    required;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.numeric  = false,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:  ctrl,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
