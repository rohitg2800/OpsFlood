import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _error = '';

  // Form fields matching the backend FloodPredictionInput schema exactly
  final _peakFloodCtrl = TextEditingController(text: '8.5');
  final _eventDurCtrl = TextEditingController(text: '1');
  final _timeToPeakCtrl = TextEditingController(text: '1');
  final _recessionCtrl = TextEditingController(text: '1');
  final _t1Ctrl = TextEditingController(text: '10.0');
  final _t2Ctrl = TextEditingController(text: '15.0');
  final _t3Ctrl = TextEditingController(text: '20.0');
  final _t4Ctrl = TextEditingController(text: '18.0');
  final _t5Ctrl = TextEditingController(text: '12.0');
  final _t6Ctrl = TextEditingController(text: '8.0');
  final _t7Ctrl = TextEditingController(text: '7.0');
  final _stationCtrl = TextEditingController(text: '');

  String _selectedState = 'Maharashtra';

  final List<String> _states = [
    'Maharashtra',
    'Assam',
    'Bihar',
    'Kerala',
    'Odisha',
    'West Bengal',
    'Uttar Pradesh',
    'Rajasthan',
    'Gujarat',
    'Madhya Pradesh',
    'Karnataka',
    'Tamil Nadu',
  ];

  @override
  void dispose() {
    for (final c in [
      _peakFloodCtrl,
      _eventDurCtrl,
      _timeToPeakCtrl,
      _recessionCtrl,
      _t1Ctrl,
      _t2Ctrl,
      _t3Ctrl,
      _t4Ctrl,
      _t5Ctrl,
      _t6Ctrl,
      _t7Ctrl,
      _stationCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim()) ?? fallback;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = '';
      _result = null;
    });

    final body = {
      'Peak_Flood_Level_m': _d(_peakFloodCtrl, 8.5),
      'Event_Duration_days': _d(_eventDurCtrl, 1),
      'Time_to_Peak_days': _d(_timeToPeakCtrl, 1),
      'Recession_Time_day': _d(_recessionCtrl, 1),
      'T1d': _d(_t1Ctrl, 10.0),
      'T2d': _d(_t2Ctrl, 15.0),
      'T3d': _d(_t3Ctrl, 20.0),
      'T4d': _d(_t4Ctrl, 18.0),
      'T5d': _d(_t5Ctrl, 12.0),
      'T6d': _d(_t6Ctrl, 8.0),
      'T7d': _d(_t7Ctrl, 7.0),
      'state': _selectedState,
      if (_stationCtrl.text.trim().isNotEmpty)
        'station': _stationCtrl.text.trim(),
    };

    try {
      // Use /predict/v2 — auto-fills Peak_Flood_Level_m from live CWC
      // telemetry when station is provided; falls back to manual values.
      final res = await ApiService().predictV2(body);
      setState(() {
        _loading = false;
        if (res.containsKey('status') && res['status'] == 'error') {
          _error = res['message']?.toString() ?? 'Prediction failed';
        } else {
          _result = res;
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Color _severityColor(String? s) {
    final colorInt = AppConstants.riskColors[s ?? 'MODERATE'] ??
        AppConstants.riskColors['MODERATE']!;
    return Color(colorInt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Prediction',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- State selector ----
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: const InputDecoration(
                labelText: 'State',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              items: _states
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedState = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _stationCtrl,
              decoration: const InputDecoration(
                labelText: 'Station / City (optional — enables CWC auto-fill)',
                prefixIcon: Icon(Icons.place),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Text('Flood Event Parameters',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 10),

            _numField(_peakFloodCtrl, 'Peak Flood Level (m)', Icons.waves),
            _numField(
                _eventDurCtrl, 'Event Duration (days)', Icons.calendar_today),
            _numField(
                _timeToPeakCtrl, 'Time to Peak (days)', Icons.trending_up),
            _numField(
                _recessionCtrl, 'Recession Time (days)', Icons.trending_down),

            const SizedBox(height: 16),
            Text('7-Day Rainfall (mm/day)',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(
                  child: _numField(_t1Ctrl, 'Day 1', Icons.water_drop,
                      compact: true)),
              const SizedBox(width: 8),
              Expanded(
                  child: _numField(_t2Ctrl, 'Day 2', Icons.water_drop,
                      compact: true)),
              const SizedBox(width: 8),
              Expanded(
                  child: _numField(_t3Ctrl, 'Day 3', Icons.water_drop,
                      compact: true)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _numField(_t4Ctrl, 'Day 4', Icons.water_drop,
                      compact: true)),
              const SizedBox(width: 8),
              Expanded(
                  child: _numField(_t5Ctrl, 'Day 5', Icons.water_drop,
                      compact: true)),
              const SizedBox(width: 8),
              Expanded(
                  child: _numField(_t6Ctrl, 'Day 6', Icons.water_drop,
                      compact: true)),
            ]),
            const SizedBox(height: 8),
            _numField(_t7Ctrl, 'Day 7 Rainfall (mm)', Icons.water_drop),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _loading ? null : _predict,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bolt),
              label: Text(_loading ? 'Predicting...' : 'Run Prediction'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),

            // ---- Error ----
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            ],

            // ---- Result ----
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultCard(
                  result: _result!,
                  severityColor: _severityColor),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, IconData icon,
      {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: compact ? null : Icon(icon),
          border: const OutlineInputBorder(),
          isDense: compact,
          contentPadding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
              : null,
        ),
        validator: (v) =>
            (double.tryParse(v ?? '') == null) ? 'Enter a number' : null,
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final Color Function(String?) severityColor;

  const _ResultCard(
      {required this.result, required this.severityColor});

  String _s(String key) => (result[key] ?? '--').toString();

  @override
  Widget build(BuildContext context) {
    final severity = _s('severity');
    final color = severityColor(severity);
    final probs =
        result['probabilities'] as Map<String, dynamic>? ?? {};
    final monitoring =
        result['monitoring'] as Map<String, dynamic>? ?? {};
    final autofillApplied = result['autofill_applied'] == true;
    final liveLevel = result['live_river_level_m'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      color: color.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CWC auto-fill banner ─────────────────────────────────────
            if (autofillApplied && liveLevel != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0DA7C2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF0DA7C2)
                          .withValues(alpha: 0.4)),
                ),
                // FIX: wrap banner text in Expanded to prevent overflow
                child: Row(
                  children: [
                    const Icon(Icons.sensors,
                        size: 14, color: Color(0xFF0DA7C2)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CWC auto-fill: live river level ${liveLevel}m used',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF0DA7C2)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Severity row ──────────────────────────────────────────
            // FIX: middle Column (severity label + risk score) must be
            // Expanded so it fills the space between emoji and confidence
            // instead of overflowing to the right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  AppConstants.riskIcons[severity] ?? '\u26a0\ufe0f',
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        severity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                      Text(
                        'Risk Score: ${_s("risk_score")}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_s("confidence_percent")}%',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    const Text('Confidence',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Probabilities ──────────────────────────────────────────
            if (probs.isNotEmpty) ...[
              const Text('Probabilities',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ...probs.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (num.tryParse(
                                              e.value.toString()) ??
                                          0) /
                                      100,
                              backgroundColor:
                                  Colors.grey.withValues(alpha: 0.15),
                              color: severityColor(e.key),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${e.value}%',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],

            // ── Monitoring ────────────────────────────────────────────
            if (monitoring.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: color.withValues(alpha: 0.08),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monitor_heart, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${monitoring["level"] ?? ""}: ${monitoring["action"] ?? ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            Text(
              'Algorithm: ${_s("algorithm")}  \u2022  ${_s("data_source")}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
