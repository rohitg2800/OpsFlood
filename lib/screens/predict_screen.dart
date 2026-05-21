import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/flood_engine.dart';
import '../services/predict.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PREDICT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});
  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen>
    with SingleTickerProviderStateMixin {
  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _gaugeCtrl;
  late Animation<double> _gaugeAnim;

  // ── Form controllers ─────────────────────────────────────────────────────
  final _peakCtrl     = TextEditingController(text: '8.5');
  final _durCtrl      = TextEditingController(text: '1');
  final _peakTimeCtrl = TextEditingController(text: '1');
  final _recCtrl      = TextEditingController(text: '1');
  final List<TextEditingController> _rainCtrl = List.generate(
      7,
      (i) => TextEditingController(
          text: ['10', '15', '20', '18', '12', '8', '7'][i]));

  String  _selectedState   = 'Maharashtra';
  String? _selectedStation;

  // ── State ─────────────────────────────────────────────────────────────────
  FloodResult? _result;
  bool   _loading          = false;
  String _error            = '';
  bool   _usedApi          = false;
  bool   _sectionRiver     = true;
  bool   _sectionRain      = true;

  // ── Service ───────────────────────────────────────────────────────────────
  final _svc = const PredictionService();

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _gaugeAnim =
        CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _peakCtrl.dispose();
    _durCtrl.dispose();
    _peakTimeCtrl.dispose();
    _recCtrl.dispose();
    for (final c in _rainCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Build FloodPredictionInput from form ──────────────────────────────────
  FloodPredictionInput _buildInput() {
    double v(TextEditingController c, double d) =>
        double.tryParse(c.text.trim()) ?? d;
    return FloodPredictionInput(
      peakFloodLevelM:   v(_peakCtrl, 8.5),
      eventDurationDays: v(_durCtrl, 1),
      timeToPeakDays:    v(_peakTimeCtrl, 1),
      recessionTimeDays: v(_recCtrl, 1),
      t1d: v(_rainCtrl[0], 10),
      t2d: v(_rainCtrl[1], 15),
      t3d: v(_rainCtrl[2], 20),
      t4d: v(_rainCtrl[3], 18),
      t5d: v(_rainCtrl[4], 12),
      t6d: v(_rainCtrl[5], 8),
      t7d: v(_rainCtrl[6], 7),
      state:   _selectedState,
      station: _selectedStation,
    );
  }

  // ── Map FloodPrediction → FloodResult (used by existing UI widgets) ───────
  FloodResult _toFloodResult(FloodPrediction p) => FloodResult(
        severity:            p.severity,
        confidencePercent:   p.confidencePercent,
        probabilities:       p.probabilities
            .map((k, v) => MapEntry(k, v.toDouble())),
        riskScore:           p.riskScore,
        proximityToDangerM:  0,
        algorithm:           p.algorithm,
        alert:               p.alert,
        monitoringLevel:     p.monitoringLevel,
        monitoringAction:    p.monitoringAction,
        usedApi:             !p.isOfflineFallback,
        ruleProbs:           const {},
        mlProbs:             const {},
        thresholdSeverity:   '',
      );

  // ── Run prediction via PredictionService (v2 → offline fallback) ──────────
  Future<void> _predict() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    _gaugeCtrl.reset();

    try {
      final input = _buildInput();
      final prediction = await _svc.predict(input);
      if (!mounted) return;
      setState(() {
        _result  = _toFloodResult(prediction);
        _usedApi = !prediction.isOfflineFallback;
        _loading = false;
      });
      _gaugeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Prediction failed: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05141E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07283D), Color(0xFF05141E), Color(0xFF02080E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(state: _selectedState),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
                  children: [
                    _StateSelector(
                      selected: _selectedState,
                      onChanged: (s) => setState(() => _selectedState = s),
                    ),
                    const SizedBox(height: 12),
                    _CollapsibleSection(
                      title:    'River Parameters',
                      icon:     Icons.water,
                      expanded: _sectionRiver,
                      onToggle: () =>
                          setState(() => _sectionRiver = !_sectionRiver),
                      child: _RiverParamsForm(
                        peakCtrl:     _peakCtrl,
                        durCtrl:      _durCtrl,
                        peakTimeCtrl: _peakTimeCtrl,
                        recCtrl:      _recCtrl,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CollapsibleSection(
                      title:    '7-Day Rainfall (mm/day)',
                      icon:     Icons.grain,
                      expanded: _sectionRain,
                      onToggle: () =>
                          setState(() => _sectionRain = !_sectionRain),
                      child: _RainfallForm(controllers: _rainCtrl),
                    ),
                    const SizedBox(height: 16),
                    _PredictButton(
                        loading: _loading,
                        onPressed: _loading ? null : _predict),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      ),
                    if (_result != null) ...[const SizedBox(height: 20),
                      _ResultPanel(
                          result:    _result!,
                          gaugeAnim: _gaugeAnim,
                          usedApi:   _usedApi)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String state;
  const _Header({required this.state});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Color(0xFF0DA7C2), size: 22),
          const SizedBox(width: 8),
          const Text('Flood Risk Prediction',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0DA7C2).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF0DA7C2).withValues(alpha: 0.4)),
            ),
            child: const Text('OpsFlood ML',
                style: TextStyle(
                    color: Color(0xFF0DA7C2),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE SELECTOR
// ─────────────────────────────────────────────────────────────────────────────
const _allStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
  'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
  'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
  'West Bengal', 'Delhi', 'Jammu and Kashmir', 'Puducherry',
  'Andaman and Nicobar', 'Chandigarh', 'Lakshadweep',
];

class _StateSelector extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  const _StateSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: const Color(0xFF0D2232),
          iconEnabledColor: const Color(0xFF0DA7C2),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          items: _allStates
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLAPSIBLE SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  const _CollapsibleSection(
      {required this.title,
      required this.icon,
      required this.expanded,
      required this.onToggle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF0DA7C2), size: 18),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVER PARAMS FORM
// ─────────────────────────────────────────────────────────────────────────────
class _RiverParamsForm extends StatelessWidget {
  final TextEditingController peakCtrl, durCtrl, peakTimeCtrl, recCtrl;
  const _RiverParamsForm(
      {required this.peakCtrl,
      required this.durCtrl,
      required this.peakTimeCtrl,
      required this.recCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: _FieldTile(
                  label: 'Peak Level (m)',
                  hint: '8.5',
                  ctrl: peakCtrl,
                  tooltip: 'CWC gauge level in metres')),
          const SizedBox(width: 10),
          Expanded(
              child: _FieldTile(
                  label: 'Duration (days)',
                  hint: '1',
                  ctrl: durCtrl,
                  tooltip: 'Flood event duration')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _FieldTile(
                  label: 'Time to Peak (days)',
                  hint: '1',
                  ctrl: peakTimeCtrl,
                  tooltip: 'Hours from event start to peak')),
          const SizedBox(width: 10),
          Expanded(
              child: _FieldTile(
                  label: 'Recession (days)',
                  hint: '1',
                  ctrl: recCtrl,
                  tooltip: 'River recession time after peak')),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RAINFALL FORM
// ─────────────────────────────────────────────────────────────────────────────
class _RainfallForm extends StatelessWidget {
  final List<TextEditingController> controllers;
  const _RainfallForm({required this.controllers});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['D-7', 'D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'D-1'];
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: List.generate(
        7,
        (i) => _FieldTile(
          label:   dayLabels[i],
          hint:    '0',
          ctrl:    controllers[i],
          tooltip: 'T${i + 1}d rainfall mm',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD TILE
// ─────────────────────────────────────────────────────────────────────────────
class _FieldTile extends StatelessWidget {
  final String label, hint, tooltip;
  final TextEditingController ctrl;
  const _FieldTile(
      {required this.label,
      required this.hint,
      required this.ctrl,
      required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF0DA7C2)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREDICT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _PredictButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  const _PredictButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0DA7C2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 18),
                  SizedBox(width: 6),
                  Text('Run Flood Prediction',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ResultPanel extends StatelessWidget {
  final FloodResult result;
  final Animation<double> gaugeAnim;
  final bool usedApi;
  const _ResultPanel(
      {required this.result,
      required this.gaugeAnim,
      required this.usedApi});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: usedApi
                    ? const Color(0xFF0DA7C2).withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: usedApi
                        ? const Color(0xFF0DA7C2).withValues(alpha: 0.5)
                        : Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Text(
                usedApi
                    ? '☁️  OpsFlood API  •  ${result.algorithm}'
                    : '📱  On-Device Engine  •  ${result.algorithm}',
                style: TextStyle(
                    color: usedApi
                        ? const Color(0xFF0DA7C2)
                        : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RiskGauge(result: result, anim: gaugeAnim),
        const SizedBox(height: 16),
        _ProbabilityChart(probs: result.probabilities),
        const SizedBox(height: 14),
        _StatsGrid(result: result),
        const SizedBox(height: 14),
        _MonitoringCard(result: result),
        const SizedBox(height: 14),
        if (result.ruleProbs.isNotEmpty || result.mlProbs.isNotEmpty)
          _EnsemblePanel(result: result),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RISK GAUGE
// ─────────────────────────────────────────────────────────────────────────────
class _RiskGauge extends StatelessWidget {
  final FloodResult result;
  final Animation<double> anim;
  const _RiskGauge({required this.result, required this.anim});

  Color get _color {
    switch (result.severity) {
      case 'CRITICAL': return const Color(0xFFB71C1C);
      case 'SEVERE':   return const Color(0xFFF4511E);
      case 'MODERATE': return const Color(0xFFFB8C00);
      default:         return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final progress = anim.value * (result.riskScore / 100.0);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: _color.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              Text(
                '${result.alert}  ${result.severity}',
                style: TextStyle(
                    color: _color,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.confidencePercent.toStringAsFixed(1)}% confidence',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(_color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Risk Score',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  Text(
                    '${(progress * 100).round()} / 100',
                    style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROBABILITY BAR CHART
// ─────────────────────────────────────────────────────────────────────────────
const _severityColors = {
  'LOW':      Color(0xFF43A047),
  'MODERATE': Color(0xFFFB8C00),
  'SEVERE':   Color(0xFFF4511E),
  'CRITICAL': Color(0xFFB71C1C),
};

class _ProbabilityChart extends StatelessWidget {
  final Map<String, double> probs;
  const _ProbabilityChart({required this.probs});

  @override
  Widget build(BuildContext context) {
    const labels = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
    final bars = labels.asMap().entries.map((e) {
      final val = probs[e.value] ?? 0.0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: val,
            color: _severityColors[e.value],
            width: 28,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: BarChart(
        BarChartData(
          maxY: 100,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const abbr = ['LOW', 'MOD', 'SEV', 'CRIT'];
                  final i = v.toInt();
                  if (i < 0 || i >= abbr.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(abbr[i],
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 25,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}%',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 9),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final FloodResult result;
  const _StatsGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Stat('Risk Score', '${result.riskScore}/100', Icons.speed),
      _Stat('Proximity to Danger',
          '${result.proximityToDangerM.toStringAsFixed(2)} m',
          Icons.social_distance),
      _Stat('Confidence',
          '${result.confidencePercent.toStringAsFixed(1)}%',
          Icons.verified),
      _Stat(
          'Threshold',
          result.thresholdSeverity.isNotEmpty
              ? result.thresholdSeverity
              : '—',
          Icons.rule),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.8,
      children: items
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(s.icon,
                        color: const Color(0xFF0DA7C2), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.label,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9)),
                          Text(s.value,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _Stat {
  final String label, value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// MONITORING CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MonitoringCard extends StatelessWidget {
  final FloodResult result;
  const _MonitoringCard({required this.result});

  Color get _bg {
    switch (result.severity) {
      case 'CRITICAL': return const Color(0xFFB71C1C);
      case 'SEVERE':   return const Color(0xFFF4511E);
      case 'MODERATE': return const Color(0xFFFB8C00);
      default:         return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = result.monitoringLevel.isNotEmpty
        ? result.monitoringLevel
        : result.severity;
    final action = result.monitoringAction.isNotEmpty
        ? result.monitoringAction
        : _defaultAction(result.severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bg.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: _bg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monitoring: $level',
                    style: TextStyle(
                        color: _bg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(action,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _defaultAction(String sev) {
    switch (sev) {
      case 'CRITICAL': return 'Immediate evacuation. Contact NDRF.';
      case 'SEVERE':   return 'Alert district admin. Prepare evacuation routes.';
      case 'MODERATE': return 'Monitor every 6h. Pre-position rescue teams.';
      default:         return 'Standard monitoring. Review 7-day forecast daily.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENSEMBLE PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _EnsemblePanel extends StatelessWidget {
  final FloodResult result;
  const _EnsemblePanel({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree,
                  color: Color(0xFF0DA7C2), size: 14),
              SizedBox(width: 6),
              Text('Ensemble Breakdown',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          _MiniProbRow(label: 'ML (75%)',   probs: result.mlProbs),
          const SizedBox(height: 6),
          _MiniProbRow(label: 'Rule (25%)', probs: result.ruleProbs),
        ],
      ),
    );
  }
}

class _MiniProbRow extends StatelessWidget {
  final String label;
  final Map<String, double> probs;
  const _MiniProbRow({required this.label, required this.probs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10)),
        ),
        ...['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'].map((l) {
          final pct = probs[l] ?? 0.0;
          return Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: _severityColors[l],
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _severityColors[l]!),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
