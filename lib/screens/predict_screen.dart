// lib/screens/predict_screen.dart
// OpsFlood — Predict Screen v3.1
// FIX: BOTTOM OVERFLOWED errors — GridView.count replaced with Column+Row

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ml/flood_engine.dart';
import '../services/predict.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kCyan    = Color(0xFF00D4FF);
const _kPurple  = Color(0xFF7B50FF);
const _kBg1     = Color(0xFF060D1A);
const _kBg2     = Color(0xFF0A1628);
const _kBg3     = Color(0xFF110A24);
const _kSurface = Color(0x14FFFFFF);
const _kBorder  = Color(0x1AFFFFFF);

const _severityColors = {
  'LOW':      Color(0xFF22C55E),
  'MODERATE': Color(0xFFF59E0B),
  'SEVERE':   Color(0xFFF97316),
  'CRITICAL': Color(0xFFEF4444),
};

const _allStates = [
  'Andhra Pradesh','Arunachal Pradesh','Assam','Bihar','Chhattisgarh',
  'Goa','Gujarat','Haryana','Himachal Pradesh','Jharkhand','Karnataka',
  'Kerala','Madhya Pradesh','Maharashtra','Manipur','Meghalaya',
  'Mizoram','Nagaland','Odisha','Punjab','Rajasthan','Sikkim',
  'Tamil Nadu','Telangana','Tripura','Uttar Pradesh','Uttarakhand',
  'West Bengal','Delhi','Jammu and Kashmir','Puducherry',
  'Andaman and Nicobar','Chandigarh','Lakshadweep',
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});
  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _gaugeCtrl;
  late Animation<double>   _gaugeAnim;

  final _peakCtrl     = TextEditingController(text: '8.5');
  final _durCtrl      = TextEditingController(text: '1');
  final _peakTimeCtrl = TextEditingController(text: '1');
  final _recCtrl      = TextEditingController(text: '1');
  final _stationCtrl  = TextEditingController();
  final List<TextEditingController> _rainCtrl = List.generate(
    7, (i) => TextEditingController(text: ['10','15','20','18','12','8','7'][i]),
  );

  String           _selectedState = 'Maharashtra';
  FloodPrediction? _result;
  bool   _loading      = false;
  String _error        = '';
  bool   _sectionRiver = true;
  bool   _sectionRain  = true;
  bool   _useOffline   = false;

  final _svc = const PredictionService();

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _gaugeAnim = CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _peakCtrl.dispose(); _durCtrl.dispose();
    _peakTimeCtrl.dispose(); _recCtrl.dispose(); _stationCtrl.dispose();
    for (final c in _rainCtrl) c.dispose();
    super.dispose();
  }

  double _v(TextEditingController c, double d) =>
      double.tryParse(c.text.trim()) ?? d;

  FloodPredictionInput _buildInput() => FloodPredictionInput(
    peakFloodLevelM:   _v(_peakCtrl, 8.5),
    eventDurationDays: _v(_durCtrl, 1),
    timeToPeakDays:    _v(_peakTimeCtrl, 1),
    recessionTimeDays: _v(_recCtrl, 1),
    t1d: _v(_rainCtrl[0], 10), t2d: _v(_rainCtrl[1], 15),
    t3d: _v(_rainCtrl[2], 20), t4d: _v(_rainCtrl[3], 18),
    t5d: _v(_rainCtrl[4], 12), t6d: _v(_rainCtrl[5], 8),
    t7d: _v(_rainCtrl[6], 7),
    state:   _selectedState,
    station: _stationCtrl.text.trim().isEmpty ? null : _stationCtrl.text.trim(),
  );

  Future<void> _predict() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    _gaugeCtrl.reset();
    try {
      final input = _buildInput();
      final prediction = _useOffline
          ? _svc.predictOffline(input)
          : await _svc.predict(input);
      if (!mounted) return;
      setState(() { _result = prediction; _loading = false; });
      _gaugeCtrl.forward();
    } on PredictionException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Unexpected error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg1,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3, _kBg1],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                  children: [
                    _buildTopRow(),
                    const SizedBox(height: 14),
                    _buildCollapsible(
                      title: '🌊  River Parameters',
                      expanded: _sectionRiver,
                      onToggle: () => setState(() => _sectionRiver = !_sectionRiver),
                      child: _buildRiverForm(),
                    ),
                    const SizedBox(height: 12),
                    _buildCollapsible(
                      title: '🌧️  7-Day Rainfall (mm/day)',
                      expanded: _sectionRain,
                      onToggle: () => setState(() => _sectionRain = !_sectionRain),
                      child: _buildRainfallGrid(),
                    ),
                    const SizedBox(height: 18),
                    _buildOfflineToggle(),
                    const SizedBox(height: 14),
                    _buildPredictButton(),
                    if (_error.isNotEmpty) _buildErrorBanner(),
                    if (_result != null) ...[const SizedBox(height: 22), _buildResults()],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kCyan.withValues(alpha: 0.08), _kPurple.withValues(alpha: 0.06)],
        ),
        border: Border(bottom: BorderSide(color: _kCyan.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kCyan, _kPurple]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_alt, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_kCyan, _kPurple],
                ).createShader(b),
                child: const Text('Flood Risk Predictor',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              ),
              const Text('Live CWC · OpsFlood ML Engine',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const Spacer(),
          _LiveBadge(isLive: !_useOffline),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('State',
                  style: TextStyle(color: Colors.white54, fontSize: 10,
                      fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              _GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedState,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0D1E35),
                    iconEnabledColor: _kCyan,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    items: _allStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedState = v); },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _InputField(
            ctrl: _stationCtrl, label: 'Station (opt.)',
            hint: 'e.g. Kolhapur', tooltip: 'CWC station for live autofill',
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsible({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return _GlassCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildRiverForm() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _InputField(ctrl: _peakCtrl,     label: 'Peak Level (m)',      hint: '8.5', tooltip: 'CWC gauge level')),
          const SizedBox(width: 10),
          Expanded(child: _InputField(ctrl: _durCtrl,      label: 'Duration (days)',     hint: '1',   tooltip: 'Event duration')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InputField(ctrl: _peakTimeCtrl, label: 'Time to Peak (days)', hint: '1',   tooltip: 'Hours to peak')),
          const SizedBox(width: 10),
          Expanded(child: _InputField(ctrl: _recCtrl,      label: 'Recession (days)',    hint: '1',   tooltip: 'Recession time')),
        ]),
      ],
    );
  }

  // ── FIX: replaced GridView.count (childAspectRatio overflow) with Column+Row ──
  Widget _buildRainfallGrid() {
    const labels = ['D-7','D-6','D-5','D-4','D-3','D-2','D-1'];

    Expanded cell(int i) => Expanded(
      child: _InputField(
        ctrl: _rainCtrl[i], label: labels[i],
        hint: '0', tooltip: 'T${i + 1}d rainfall mm', compact: true,
      ),
    );

    return Column(
      children: [
        // Row 1: D-7 D-6 D-5 D-4
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(0), const SizedBox(width: 8),
            cell(1), const SizedBox(width: 8),
            cell(2), const SizedBox(width: 8),
            cell(3),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: D-3 D-2 D-1  + invisible spacer to keep same width
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(4), const SizedBox(width: 8),
            cell(5), const SizedBox(width: 8),
            cell(6), const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildOfflineToggle() {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: _useOffline ? Colors.orange : Colors.white24, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _useOffline ? 'Offline Rule Engine' : 'Live OpsFlood API  •  CWC Auto-fill',
                  style: TextStyle(
                      color: _useOffline ? Colors.orange : _kCyan,
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  _useOffline
                      ? 'Using on-device thresholds — no real data'
                      : 'Fetches real CWC river levels from OpsFlood backend',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: _useOffline,
            onChanged: (v) => setState(() => _useOffline = v),
            activeColor: Colors.orange,
            inactiveThumbColor: _kCyan,
            inactiveTrackColor: _kCyan.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictButton() {
    return GestureDetector(
      onTap: _loading ? null : _predict,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: _loading
              ? LinearGradient(colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.06)])
              : const LinearGradient(colors: [_kCyan, _kPurple]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading ? [] : [
            BoxShadow(color: _kCyan.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text('Run Flood Prediction',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 15, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API Error',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_error, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _useOffline = true),
                  child: const Text('→ Switch to offline mode',
                      style: TextStyle(color: Colors.orange, fontSize: 11,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final r   = _result!;
    final col = _severityColors[r.severity] ?? const Color(0xFFF59E0B);
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: r.isOfflineFallback
                  ? Colors.orange.withValues(alpha: 0.12)
                  : _kCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: r.isOfflineFallback
                      ? Colors.orange.withValues(alpha: 0.4)
                      : _kCyan.withValues(alpha: 0.4)),
            ),
            child: Text(
              r.isOfflineFallback
                  ? '📱  On-Device Engine  •  ${r.algorithm}'
                  : '☁️  OpsFlood Live API  •  ${r.algorithm}',
              style: TextStyle(
                  color: r.isOfflineFallback ? Colors.orange : _kCyan,
                  fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (r.liveRiverLevelM != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
              ),
              child: Text('📡  Live CWC River Level: ${r.liveRiverLevelM!.toStringAsFixed(2)} m',
                  style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _gaugeAnim,
          builder: (_, __) {
            final progress = _gaugeAnim.value * (r.riskScore / 100.0);
            return _GlassCard(
              borderColor: col.withValues(alpha: 0.45),
              shadowColor: col.withValues(alpha: 0.18),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('${r.alert}  ', style: const TextStyle(fontSize: 34)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FLOOD SEVERITY', style: TextStyle(color: Colors.white38, fontSize: 9,
                              fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                          Text(r.severity, style: TextStyle(
                              color: col, fontSize: 26, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('CONFIDENCE', style: TextStyle(color: Colors.white38, fontSize: 9,
                              fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                          Text('${r.confidencePercent.toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.white, fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress, minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(col),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Risk Score', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Text('${(progress * 100).round()} / 100',
                          style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        _buildStatsGrid(r),
        const SizedBox(height: 14),
        _buildProbChart(r),
        const SizedBox(height: 14),
        _buildMonitoringCard(r),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── FIX: replaced GridView.count (childAspectRatio overflow) with Column+Row ──
  Widget _buildStatsGrid(FloodPrediction r) {
    final items = [
      _StatItem(Icons.speed,    'Risk Score',  '${r.riskScore}/100',                         _kCyan),
      _StatItem(Icons.verified, 'Confidence',  '${r.confidencePercent.toStringAsFixed(1)}%', _kPurple),
      _StatItem(Icons.hub,      'Algorithm',   r.algorithm,                                  const Color(0xFF22C55E)),
      _StatItem(Icons.sensors,  'Data Source', r.dataSource,                                 const Color(0xFFF59E0B)),
    ];

    Widget card(_StatItem s) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(s.icon, color: s.accent, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.label, style: const TextStyle(color: Colors.white38, fontSize: 9,
                      fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  const SizedBox(height: 2),
                  Text(s.value, style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        Row(children: [card(items[0]), const SizedBox(width: 10), card(items[1])]),
        const SizedBox(height: 10),
        Row(children: [card(items[2]), const SizedBox(width: 10), card(items[3])]),
      ],
    );
  }

  Widget _buildProbChart(FloodPrediction r) {
    const labels = ['LOW','MODERATE','SEVERE','CRITICAL'];
    final bars = labels.asMap().entries.map((e) {
      final val = (r.probabilities[e.value] ?? 0).toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(
          toY: val,
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [_severityColors[e.value]!.withValues(alpha: 0.6), _severityColors[e.value]!],
          ),
          width: 30,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        )],
      );
    }).toList();

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 10),
            child: Text('Severity Probabilities',
                style: TextStyle(color: Colors.white54, fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          ),
          SizedBox(
            height: 160,
            child: BarChart(BarChartData(
              maxY: 100,
              barGroups: bars,
              gridData: FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: 25,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    const abbr = ['LOW','MOD','SEV','CRIT'];
                    final i = v.toInt();
                    if (i < 0 || i >= abbr.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(abbr[i],
                          style: const TextStyle(color: Colors.white38, fontSize: 9)),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 30, interval: 25,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                      style: const TextStyle(color: Colors.white24, fontSize: 9)),
                )),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                    '${rod.toY.toStringAsFixed(1)}%',
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringCard(FloodPrediction r) {
    final col = _severityColors[r.severity] ?? const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_active, color: col, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monitoring: ${r.monitoringLevel}',
                    style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                Text(r.monitoringAction,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final Color? shadowColor;
  const _GlassCard({required this.child, this.padding, this.borderColor, this.shadowColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? EdgeInsets.zero,
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? _kBorder),
      boxShadow: shadowColor != null
          ? [BoxShadow(color: shadowColor!, blurRadius: 24, spreadRadius: 2)]
          : null,
    ),
    child: child,
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint, tooltip;
  final bool compact;
  const _InputField({
    required this.ctrl, required this.label,
    required this.hint, required this.tooltip,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,   // FIX: don't stretch beyond content
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white54,
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: TextStyle(color: Colors.white, fontSize: compact ? 12 : 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            isDense: true,                              // FIX: removes extra internal padding
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kCyan, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: compact ? 8 : 11,              // FIX: explicit vertical padding
            ),
          ),
        ),
      ],
    ),
  );
}

class _LiveBadge extends StatefulWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLive ? const Color(0xFF22C55E) : Colors.orange;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: color.withValues(alpha: _anim.value),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
            Text(widget.isLive ? 'LIVE' : 'OFFLINE',
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label, value;
  final Color accent;
  const _StatItem(this.icon, this.label, this.value, this.accent);
}
