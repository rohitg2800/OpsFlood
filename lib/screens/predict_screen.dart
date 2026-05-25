// lib/screens/predict_screen.dart
// OpsFlood — Predict Screen v7.0
// MERGED: River Level Trend chart + Flood Risk Predictor in one screen
// Changes from v6.0:
//   • Added _RiverTrendPanel — inline sparkline with warning/danger lines
//   • Chart uses correct metre values from autofill (NOT discharge m³/s)
//   • Panel appears after autofill badge, collapses when no city selected

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../ml/flood_engine.dart';
import '../services/api_service.dart';
import '../services/predict.dart';

// ─── Military Palette ────────────────────────────────────────────────────────
const _kBg1      = Color(0xFF0A0D08);
const _kBg2      = Color(0xFF111610);
const _kBg3      = Color(0xFF0E1309);
const _kOlive    = Color(0xFF6B8C3A);
const _kOliveL   = Color(0xFF8AAF4A);
const _kKhaki    = Color(0xFFB8A050);
const _kAmber    = Color(0xFFE8A020);
const _kRed      = Color(0xFFCC2A2A);
const _kSurface  = Color(0xFF141A10);
const _kSurface2 = Color(0xFF1A2214);
const _kBorder   = Color(0x336B8C3A);
const _kMuted    = Color(0xFF8A9A7A);
const _kCyan     = Color(0xFF00C2DE);

const _severityColors = {
  'LOW':      Color(0xFF4CAF50),
  'MODERATE': Color(0xFFB8A050),
  'SEVERE':   Color(0xFFE8A020),
  'CRITICAL': Color(0xFFCC2A2A),
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

// ─── Autofill model ──────────────────────────────────────────────────────────
class _StationAutofill {
  final double? riverLevelM;
  final double? warningLevelM;
  final double? dangerLevelM;
  final double? rainfallLastHour;
  final double? flowRate;
  final String? trend;
  final String? status;
  final String? riverName;
  final String  source;

  const _StationAutofill({
    this.riverLevelM, this.warningLevelM, this.dangerLevelM,
    this.rainfallLastHour, this.flowRate, this.trend,
    this.status, this.riverName, required this.source,
  });

  double get derivedDuration    => status == 'CRITICAL' ? 3.0 : status == 'WARNING' ? 2.0 : 1.0;
  double get derivedTimeToPeak  => 1.0;
  double derivedRecession(double? level) {
    if (level == null || dangerLevelM == null || dangerLevelM! <= 0) return 1.0;
    final r = level / dangerLevelM!;
    return r >= 1.0 ? 3.0 : r >= 0.85 ? 2.0 : 1.0;
  }
  List<double> get derivedRainfall7d {
    final daily = ((rainfallLastHour ?? 0.0) * 24).clamp(0.0, 300.0);
    return [0.05,0.12,0.22,0.40,0.60,0.80,1.00]
        .map((w) => double.parse((daily * w).toStringAsFixed(1))).toList();
  }
}

// ─── City entry ──────────────────────────────────────────────────────────────
class _CityEntry {
  final String city, state, river;
  const _CityEntry(this.city, this.state, this.river);
  static List<_CityEntry> fromConstants() => AppConstants.monitoredCities.map((mc) =>
    _CityEntry((mc['city'] as String? ?? '').trim(),
               (mc['state'] as String? ?? '').trim(),
               (mc['river'] as String? ?? '').trim()),
  ).where((e) => e.city.isNotEmpty).toList();
  String get subtitle => river.isNotEmpty ? '$state • $river' : state;
  bool matches(String q) {
    final lq = q.toLowerCase();
    return city.toLowerCase().contains(lq) ||
           state.toLowerCase().contains(lq) ||
           river.toLowerCase().contains(lq);
  }
}

// ─── River Trend Panel (NEW) ─────────────────────────────────────────────────
/// Inline sparkline card shown between autofill badge and river parameters.
/// Uses the autofilled riverLevelM / warningLevelM / dangerLevelM (metres)
/// to draw a synthetic 8-point trend with correct reference lines.
class _RiverTrendPanel extends StatelessWidget {
  final _StationAutofill af;
  final String cityName;

  const _RiverTrendPanel({required this.af, required this.cityName});

  /// Build a plausible 8-point history from a single snapshot.
  /// Trend: RISING → levels increase toward current; FALLING → decrease; else flat.
  List<double> _buildPoints() {
    final level   = af.riverLevelM ?? 0.0;
    final warning = af.warningLevelM ?? level * 0.8;
    final trend   = af.trend ?? 'STABLE';
    if (level <= 0) return List.filled(8, 0.0);
    // spread over ±15% based on trend direction
    return List.generate(8, (i) {
      final t = i / 7.0; // 0..1
      if (trend == 'RISING') {
        // start low, end at current
        return warning * 0.6 + (level - warning * 0.6) * t;
      } else if (trend == 'FALLING') {
        // start high, end at current
        final peak = math.max(level * 1.15, (af.dangerLevelM ?? level * 1.2));
        return peak - (peak - level) * t;
      } else {
        // stable: gentle oscillation ±3%
        final osc = level * 0.03 * math.sin(i * 0.9);
        return level + osc;
      }
    });
  }

  Color _levelColor(double level) {
    final w = af.warningLevelM ?? double.infinity;
    final d = af.dangerLevelM  ?? double.infinity;
    if (level >= d) return _kRed;
    if (level >= w) return _kAmber;
    return _kOliveL;
  }

  @override
  Widget build(BuildContext context) {
    final level   = af.riverLevelM ?? 0.0;
    final warning = af.warningLevelM;
    final danger  = af.dangerLevelM;
    final safe    = warning != null ? warning * 0.85 : null;
    final points  = _buildPoints();
    final col     = _levelColor(level);
    final trendIcon = af.trend == 'RISING'  ? '↑' :
                      af.trend == 'FALLING' ? '↓' : '→';

    // Y axis range — pad 20% above max reference line
    final allVals = [
      ...points,
      if (warning != null) warning,
      if (danger  != null) danger,
    ];
    final minY = allVals.reduce(math.min) * 0.85;
    final maxY = allVals.reduce(math.max) * 1.20;

    // Build fl_chart line spots
    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: col.withOpacity(0.08), blurRadius: 16)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Title row ──────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.show_chart, color: _kCyan, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(
            'River Level Trend  ·  $cityName',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 12, letterSpacing: 0.5),
            overflow: TextOverflow.ellipsis,
          )),
          // Current level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: col.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: col.withOpacity(0.5)),
            ),
            child: Text(
              '$trendIcon  ${level.toStringAsFixed(2)} m',
              style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Sparkline chart ────────────────────────────────────────────────
        SizedBox(
          height: 110,
          child: LineChart(LineChartData(
            minY: minY,
            maxY: maxY,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: _kBorder, strokeWidth: 0.8),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(color: _kMuted, fontSize: 8),
                ),
              )),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            // ── Reference lines (warning / danger / safe) ──────────────
            extraLinesData: ExtraLinesData(horizontalLines: [
              if (warning != null)
                HorizontalLine(
                  y: warning,
                  color: _kAmber.withOpacity(0.7),
                  strokeWidth: 1.2,
                  dashArray: [5, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    labelResolver: (_) => 'W ${warning.toStringAsFixed(1)}m',
                    style: const TextStyle(color: _kAmber, fontSize: 8, fontWeight: FontWeight.w700),
                  ),
                ),
              if (danger != null)
                HorizontalLine(
                  y: danger,
                  color: _kRed.withOpacity(0.8),
                  strokeWidth: 1.2,
                  dashArray: [5, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    labelResolver: (_) => 'D ${danger.toStringAsFixed(1)}m',
                    style: const TextStyle(color: _kRed, fontSize: 8, fontWeight: FontWeight.w700),
                  ),
                ),
              if (safe != null)
                HorizontalLine(
                  y: safe,
                  color: _kOliveL.withOpacity(0.5),
                  strokeWidth: 1.0,
                  dashArray: [3, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    labelResolver: (_) => 'S ${safe.toStringAsFixed(1)}m',
                    style: const TextStyle(color: _kOliveL, fontSize: 8, fontWeight: FontWeight.w700),
                  ),
                ),
            ]),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: col,
                barWidth: 2.2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, i) {
                    final isLast = i == spots.length - 1;
                    return FlDotCirclePainter(
                      radius: isLast ? 4.0 : 2.0,
                      color: col,
                      strokeWidth: isLast ? 2.0 : 0.0,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [col.withOpacity(0.20), col.withOpacity(0.02)],
                  ),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 10),

        // ── Threshold legend ───────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (warning != null)
            _ThresholdBadge('Warning', '${warning.toStringAsFixed(1)} m', _kAmber),
          if (danger != null)
            _ThresholdBadge('Danger',  '${danger.toStringAsFixed(1)} m', _kRed),
          if (safe != null)
            _ThresholdBadge('Safe',    '${safe.toStringAsFixed(1)} m',   _kOliveL),
          if (af.source == 'LIVE_LEVELS' || af.source == 'CWC_API')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _kCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kCyan.withOpacity(0.3)),
              ),
              child: const Text('LIVE', style: TextStyle(
                  color: _kCyan, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
        ]),
      ]),
    );
  }
}

class _ThresholdBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ThresholdBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: color.withOpacity(0.7),
          fontSize: 8, fontWeight: FontWeight.w700)),
      Text(value, style: TextStyle(color: color,
          fontSize: 11, fontWeight: FontWeight.w800)),
    ],
  );
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});
  @override State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _gaugeCtrl;
  late Animation<double>   _gaugeAnim;

  final _peakCtrl     = TextEditingController(text: '8.5');
  final _durCtrl      = TextEditingController(text: '1');
  final _peakTimeCtrl = TextEditingController(text: '1');
  final _recCtrl      = TextEditingController(text: '1');
  final _cityCtrl     = TextEditingController();
  final List<TextEditingController> _rainCtrl = List.generate(
    7, (i) => TextEditingController(text: ['10','15','20','18','12','8','7'][i]));

  String           _selectedState = 'Maharashtra';
  String?          _selectedCity;
  FloodPrediction? _result;
  bool   _loading     = false;
  bool   _autofilling = false;
  bool   _autofilled  = false;
  String _error       = '';
  bool   _sectionRiver = true;
  bool   _sectionRain  = true;
  bool   _useOffline   = false;
  _StationAutofill? _lastAF;

  late final List<_CityEntry> _allCities;
  final _svc = const PredictionService();
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _gaugeAnim = CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic);
    _allCities = _CityEntry.fromConstants();
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _peakCtrl.dispose(); _durCtrl.dispose();
    _peakTimeCtrl.dispose(); _recCtrl.dispose();
    _cityCtrl.dispose();
    for (final c in _rainCtrl) c.dispose();
    super.dispose();
  }

  double _v(TextEditingController c, double d) => double.tryParse(c.text.trim()) ?? d;

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
    station: _selectedCity,
  );

  void _onCitySelected(_CityEntry e) {
    setState(() {
      _selectedCity  = e.city;
      _selectedState = e.state.isNotEmpty && _allStates.contains(e.state) ? e.state : _selectedState;
      _autofilled = false; _lastAF = null;
      _cityCtrl.text = e.city;
    });
    _autofillFromLive(e.city, e.state);
  }

  Future<void> _autofillFromLive(String city, [String? state]) async {
    setState(() { _autofilling = true; _autofilled = false; });
    try {
      final r = await _api.getAllCwcStations();
      final raw = r['data'];
      if (raw is List && raw.isNotEmpty) {
        final af = _matchList(raw, city, state, 'CWC_API');
        if (af != null) { _applyAF(af); return; }
      }
    } catch (_) {}
    try {
      final r = await _api.getLiveLevels();
      final raw = _extractList(r);
      if (raw.isNotEmpty) {
        final af = _matchList(raw, city, state, 'LIVE_LEVELS');
        if (af != null) { _applyAF(af); return; }
      }
    } catch (_) {}
    final af = _matchConst(city, state);
    if (af != null) { _applyAF(af); return; }
    if (mounted) setState(() => _autofilling = false);
  }

  _StationAutofill? _matchList(List raw, String city, String? state, String src) {
    final lc = city.toLowerCase(), ls = (state ?? '').toLowerCase();
    Map<String,dynamic>? best; int bs = 99;
    for (final item in raw.whereType<Map<String,dynamic>>()) {
      final sc = _str(item['station'] ?? item['stationName'] ?? item['city'] ?? item['name']);
      final st = _str(item['state_name'] ?? item['state'] ?? item['stateName']);
      final rv = _str(item['river'] ?? item['river_name'] ?? item['riverName']);
      int score = 99;
      if (sc.contains(lc) && st.contains(ls))    score = 0;
      else if (sc.contains(lc))                  score = 1;
      else if (lc.contains(sc) && sc.length > 3) score = 2;
      else if (rv.contains(lc))                  score = 3;
      else {
        final tok = lc.split(RegExp(r'\s+')).where((t) => t.length >= 4);
        if (tok.any((t) => sc.contains(t)))       score = 4;
      }
      if (score < bs) { bs = score; best = item; }
      if (bs == 0) break;
    }
    if (best == null) return null;
    return _StationAutofill(
      riverLevelM:      _sfp(best['river_level']       ?? best['riverLevel']    ?? best['current_level'] ?? best['level'] ?? best['water_level'] ?? best['currentLevel']),
      warningLevelM:    _sfp(best['warning_level']     ?? best['warningLevel']),
      dangerLevelM:     _sfp(best['danger_level']      ?? best['dangerLevel']),
      rainfallLastHour: _sfp(best['rainfall_last_hour']?? best['rainfallLastHour'] ?? best['rainfall']),
      flowRate:         _sfp(best['flow_rate']         ?? best['flowRate'] ?? best['discharge']),
      trend:  _str(best['trend']).toUpperCase().isEmpty  ? null : _str(best['trend']).toUpperCase(),
      status: _str(best['status']).toUpperCase().isEmpty ? null : _str(best['status']).toUpperCase(),
      riverName: _str(best['river'] ?? best['river_name'] ?? best['riverName']).isEmpty ? null
          : _str(best['river'] ?? best['river_name'] ?? best['riverName']),
      source: src,
    );
  }

  _StationAutofill? _matchConst(String city, String? state) {
    final lc = city.toLowerCase(), ls = (state ?? '').toLowerCase();
    Map<String,dynamic>? best; int bs = 99;
    for (final mc in AppConstants.monitoredCities) {
      final c = (mc['city']  as String? ?? '').toLowerCase();
      final s = (mc['state'] as String? ?? '').toLowerCase();
      int score = 99;
      if (c == lc && s.contains(ls)) score = 0;
      else if (c == lc)              score = 1;
      else if (c.contains(lc))       score = 2;
      else if (lc.contains(c) && c.length > 3) score = 3;
      if (score < bs) { bs = score; best = mc; }
      if (bs == 0) break;
    }
    if (best == null) return null;
    final wl = _sfp(best['warning_level']), dl = _sfp(best['danger_level']);
    final synth = wl > 0 ? wl * 0.90 : (dl > 0 ? dl * 0.75 : 8.5);
    return _StationAutofill(
      riverLevelM: synth, warningLevelM: wl > 0 ? wl : null,
      dangerLevelM: dl > 0 ? dl : null,
      riverName: (best['river'] as String? ?? '').isNotEmpty ? best['river'] as String : null,
      source: 'CONSTANTS',
    );
  }

  List _extractList(dynamic p) {
    if (p is List) return p;
    if (p is Map<String,dynamic>) {
      for (final k in ['data','levels','stations','results','items']) {
        final v = p[k];
        if (v is List && v.isNotEmpty) return v;
        if (v is Map<String,dynamic>) { final i = _extractList(v); if (i.isNotEmpty) return i; }
      }
    }
    return [];
  }

  void _applyAF(_StationAutofill af) {
    if (!mounted) return;
    final lv = af.riverLevelM;
    if (lv != null && lv > 0) _peakCtrl.text = lv.toStringAsFixed(2);
    _durCtrl.text      = af.derivedDuration.toStringAsFixed(0);
    _peakTimeCtrl.text = af.derivedTimeToPeak.toStringAsFixed(0);
    _recCtrl.text      = af.derivedRecession(lv).toStringAsFixed(0);
    final r7 = af.derivedRainfall7d;
    for (int i = 0; i < 7; i++) _rainCtrl[i].text = r7[i].toStringAsFixed(1);
    setState(() { _autofilling = false; _autofilled = true; _lastAF = af; });
  }

  static double _sfp(dynamic v) => (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
  static String _str(dynamic v) => (v?.toString() ?? '').trim().toLowerCase();

  Future<void> _predict() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    _gaugeCtrl.reset();
    try {
      final input = _buildInput();
      final pred = _useOffline ? _svc.predictOffline(input) : await _svc.predict(input);
      if (!mounted) return;
      setState(() { _result = pred; _loading = false; });
      _gaugeCtrl.forward();
    } on PredictionException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  String _srcLabel(String? s) {
    switch (s) {
      case 'CWC_API':     return 'LIVE TELEMETRY';
      case 'LIVE_LEVELS': return 'LIVE LEVELS';
      case 'CONSTANTS':   return 'CWC REGISTRY';
      default:            return 'AUTOFILLED';
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg1,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_kBg1, _kBg2, _kBg3, _kBg1],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          child: SafeArea(child: Column(children: [
            _header(),
            Expanded(child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
              children: [
                _citySearchRow(),
                const SizedBox(height: 14),

                // ── Autofill badge ──────────────────────────────────────
                if (_autofilled && _lastAF != null) _autofillBadge(_lastAF!),
                if (_autofilled && _lastAF != null) const SizedBox(height: 12),

                // ── RIVER LEVEL TREND (merged from city_detail_screen) ──
                if (_autofilled && _lastAF != null &&
                    (_lastAF!.riverLevelM ?? 0) > 0) ...[
                  _RiverTrendPanel(
                    af: _lastAF!,
                    cityName: _selectedCity ?? '',
                  ),
                  const SizedBox(height: 12),
                ],

                // ── River parameters ────────────────────────────────────
                _collapsible(
                  title: '  RIVER PARAMETERS',
                  icon: Icons.water_outlined,
                  expanded: _sectionRiver,
                  onToggle: () => setState(() => _sectionRiver = !_sectionRiver),
                  child: _riverForm(),
                ),
                const SizedBox(height: 12),

                // ── 7-day rainfall ──────────────────────────────────────
                _collapsible(
                  title: '  7-DAY RAINFALL  (mm/day)',
                  icon: Icons.cloudy_snowing,
                  expanded: _sectionRain,
                  onToggle: () => setState(() => _sectionRain = !_sectionRain),
                  child: _rainfallGrid(),
                ),
                const SizedBox(height: 18),
                _offlineToggle(),
                const SizedBox(height: 14),
                _predictBtn(),
                if (_error.isNotEmpty) _errorBanner(),
                if (_result != null) ...[const SizedBox(height: 22), _results()],
              ],
            )),
          ])),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_kOlive.withOpacity(0.15), _kBg1],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      border: Border(bottom: BorderSide(color: _kOlive.withOpacity(0.30), width: 1)),
    ),
    child: Row(children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kOlive, Color(0xFF3A5A1A)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _kOliveL.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: _kOlive.withOpacity(0.4), blurRadius: 14, spreadRadius: 1)],
        ),
        child: const Icon(Icons.radar, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
                colors: [_kOliveL, _kKhaki]).createShader(b),
            child: const Text('FLOOD RISK PREDICTOR',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w900, letterSpacing: 1.2),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 2),
          Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: _kOlive, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _kOliveL.withOpacity(0.7), blurRadius: 4)])),
            const SizedBox(width: 6),
            const Text('OpsFlood ML · CWC Intelligence',
                style: TextStyle(color: _kMuted, fontSize: 10, letterSpacing: 0.5)),
          ]),
        ],
      )),
      const SizedBox(width: 8),
      _MilBadge(isLive: !_useOffline),
    ]),
  );

  // ─── City search ─────────────────────────────────────────────────────────────
  Widget _citySearchRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Icon(Icons.my_location, color: _kOlive, size: 12),
      const SizedBox(width: 6),
      const Text('STATION / CITY', style: TextStyle(
          color: _kMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      const SizedBox(width: 8),
      if (_autofilling)
        const Flexible(child: _MilChip(
            label: 'ACQUIRING SIGNAL…', color: _kOliveL, icon: Icons.sync, spinning: true))
      else if (_autofilled)
        Flexible(child: _MilChip(
            label: '▶ ${_srcLabel(_lastAF?.source)}',
            color: Color(0xFF4CAF50), icon: Icons.check))
      else if (_selectedCity != null)
        Flexible(child: _MilChip(
            label: '$_selectedCity · $_selectedState',
            color: _kKhaki, icon: Icons.location_on_outlined)),
    ]),
    const SizedBox(height: 7),
    Autocomplete<_CityEntry>(
      optionsBuilder: (tv) {
        if (tv.text.isEmpty) return const Iterable.empty();
        return _allCities.where((e) => e.matches(tv.text));
      },
      displayStringForOption: (e) => e.city,
      fieldViewBuilder: (ctx, ctrl, fn, _) {
        ctrl.addListener(() { if (_cityCtrl.text != ctrl.text) _cityCtrl.text = ctrl.text; });
        return TextField(
          controller: ctrl, focusNode: fn,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Patna, Guwahati, Nashik…',
            hintStyle: TextStyle(color: _kMuted.withOpacity(0.5), fontSize: 12),
            filled: true, fillColor: _kSurface,
            prefixIcon: const Icon(Icons.search, color: _kOlive, size: 18),
            suffixIcon: ctrl.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, color: _kMuted, size: 16),
                    onPressed: () { ctrl.clear(); setState(() { _selectedCity = null; _autofilled = false; _lastAF = null; }); })
                : null,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kOliveL, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        );
      },
      optionsViewBuilder: (ctx, onSel, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.only(top: 4, right: 16),
            decoration: BoxDecoration(
              color: _kSurface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
              boxShadow: [BoxShadow(color: _kOlive.withOpacity(0.15), blurRadius: 20)],
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6), shrinkWrap: true,
              children: options.map((e) => InkWell(
                onTap: () => onSel(e),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _kOlive.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorder)),
                      child: const Icon(Icons.water, color: _kOliveL, size: 15)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.city, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      Text(e.subtitle, style: TextStyle(color: _kMuted, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ])),
                    const Icon(Icons.chevron_right, color: _kOlive, size: 16),
                  ]),
                ),
              )).toList(),
            ),
          ),
        ),
      ),
      onSelected: _onCitySelected,
    ),
    const SizedBox(height: 10),
    _MilCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState, isExpanded: true,
          dropdownColor: _kSurface2,
          iconEnabledColor: _kOliveL,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          items: _allStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) { if (v != null) setState(() => _selectedState = v); },
        ),
      ),
    ),
  ]);

  // ─── Autofill badge ──────────────────────────────────────────────────────────
  Widget _autofillBadge(_StationAutofill af) {
    final srcColor = af.source == 'CWC_API' ? _kOliveL
        : af.source == 'LIVE_LEVELS' ? const Color(0xFF4CAF50) : _kKhaki;

    Widget pill(String lbl, String val, Color col) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: col.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lbl, style: TextStyle(color: col.withOpacity(0.7), fontSize: 8,
            fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        Text(val, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: srcColor.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: srcColor.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.sensors, color: srcColor, size: 13),
          const SizedBox(width: 5),
          Flexible(child: Text(
            '▶ ${af.source}  —  ${af.riverName ?? _selectedCity ?? ''}',
            style: TextStyle(color: srcColor, fontSize: 10, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis)),
          if (af.trend != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _trendCol(af.trend!).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _trendCol(af.trend!).withOpacity(0.4))),
              child: Text('${_trendIcon(af.trend!)} ${af.trend}',
                  style: TextStyle(color: _trendCol(af.trend!), fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if ((af.riverLevelM ?? 0) > 0)    pill('RIVER LEVEL',  '${af.riverLevelM!.toStringAsFixed(2)} m', _kOliveL),
          if ((af.warningLevelM ?? 0) > 0)  pill('WARNING',     '${af.warningLevelM!.toStringAsFixed(2)} m', _kKhaki),
          if ((af.dangerLevelM ?? 0) > 0)   pill('DANGER',      '${af.dangerLevelM!.toStringAsFixed(2)} m', _kRed),
          if ((af.rainfallLastHour ?? 0) > 0) pill('RAINFALL/hr','${af.rainfallLastHour!.toStringAsFixed(1)} mm', _kAmber),
          if ((af.flowRate ?? 0) > 0)       pill('FLOW RATE',   '${af.flowRate!.toStringAsFixed(1)} m³/s', const Color(0xFF4CAF50)),
          if (af.status != null)             pill('STATUS',      af.status!, _statCol(af.status!)),
          pill('SOURCE', af.source, srcColor),
        ]),
      ]),
    );
  }

  Color _trendCol(String t) => t=='RISING' ? _kRed : t=='FALLING' ? const Color(0xFF4CAF50) : _kKhaki;
  String _trendIcon(String t) => t=='RISING' ? '↑' : t=='FALLING' ? '↓' : '→';
  Color _statCol(String s) => s=='CRITICAL' ? _kRed : s=='WARNING' ? _kAmber : const Color(0xFF4CAF50);

  // ─── Collapsible section ─────────────────────────────────────────────────────
  Widget _collapsible({
    required String title, required IconData icon,
    required bool expanded, required VoidCallback onToggle, required Widget child,
  }) => _MilCard(child: Column(children: [
    GestureDetector(
      onTap: onToggle, behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, color: _kOliveL, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800,
              fontSize: 12, letterSpacing: 0.8), overflow: TextOverflow.ellipsis)),
          Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: _kMuted, size: 20),
        ]),
      ),
    ),
    if (expanded)
      Padding(padding: const EdgeInsets.fromLTRB(14,0,14,14), child: child),
  ]));

  // ─── River form ──────────────────────────────────────────────────────────────
  Widget _riverForm() {
    final af = _autofilled;
    return Column(children: [
      Row(children: [
        Expanded(child: _MilField(ctrl: _peakCtrl, label: af ? '⚡ PEAK LEVEL (m)' : 'PEAK LEVEL (m)',
            hint: '8.5', glowColor: af ? const Color(0xFF4CAF50) : null)),
        const SizedBox(width: 10),
        Expanded(child: _MilField(ctrl: _durCtrl, label: af ? '⚡ DURATION (days)' : 'DURATION (days)',
            hint: '1', glowColor: af ? const Color(0xFF4CAF50) : null)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MilField(ctrl: _peakTimeCtrl, label: af ? '⚡ TIME TO PEAK' : 'TIME TO PEAK (days)',
            hint: '1', glowColor: af ? const Color(0xFF4CAF50) : null)),
        const SizedBox(width: 10),
        Expanded(child: _MilField(ctrl: _recCtrl, label: af ? '⚡ RECESSION' : 'RECESSION (days)',
            hint: '1', glowColor: af ? const Color(0xFF4CAF50) : null)),
      ]),
    ]);
  }

  // ─── Rainfall grid ───────────────────────────────────────────────────────────
  Widget _rainfallGrid() {
    const lbl = ['D-7','D-6','D-5','D-4','D-3','D-2','D-1'];
    Expanded cell(int i) => Expanded(child: _MilField(
      ctrl: _rainCtrl[i],
      label: _autofilled ? '⚡ ${lbl[i]}' : lbl[i],
      hint: '0', compact: true,
      glowColor: _autofilled ? const Color(0xFF4CAF50).withOpacity(0.8) : null));
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        cell(0), const SizedBox(width: 8), cell(1), const SizedBox(width: 8),
        cell(2), const SizedBox(width: 8), cell(3),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        cell(4), const SizedBox(width: 8), cell(5), const SizedBox(width: 8), cell(6),
      ]),
    ]);
  }

  // ─── Offline toggle ──────────────────────────────────────────────────────────
  Widget _offlineToggle() => _MilCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Icon(Icons.wifi_off, color: _useOffline ? _kAmber : _kOlive, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _useOffline ? 'OFFLINE RULE ENGINE' : 'LIVE API · 3-TIER AUTO-FILL',
          style: TextStyle(color: _useOffline ? _kAmber : _kOliveL,
              fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          _useOffline ? 'On-device thresholds — no network required'
              : 'CWC telemetry → live levels → registry fallback',
          style: TextStyle(color: _kMuted, fontSize: 10), overflow: TextOverflow.ellipsis),
      ])),
      Switch(
        value: _useOffline, onChanged: (v) => setState(() => _useOffline = v),
        activeColor: _kAmber,
        inactiveThumbColor: _kOliveL,
        inactiveTrackColor: _kOlive.withOpacity(0.3),
      ),
    ]),
  );

  // ─── Predict button ──────────────────────────────────────────────────────────
  Widget _predictBtn() {
    final busy = _loading || _autofilling;
    return GestureDetector(
      onTap: busy ? null : _predict,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: busy
              ? const LinearGradient(colors: [_kSurface, _kSurface])
              : const LinearGradient(
                  colors: [_kOliveL, _kOlive, Color(0xFF3A5A1A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: busy ? _kBorder : _kOliveL.withOpacity(0.6)),
          boxShadow: busy ? [] : [
            BoxShadow(color: _kOlive.withOpacity(0.45), blurRadius: 22, spreadRadius: 2),
          ],
        ),
        child: Center(child: busy
          ? const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _kOliveL))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.radar, size: 20, color: Colors.white),
              SizedBox(width: 10),
              Text('EXECUTE FLOOD ANALYSIS', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900,
                  fontSize: 14, letterSpacing: 1.2)),
            ]),
        ),
      ),
    );
  }

  // ─── Error banner ────────────────────────────────────────────────────────────
  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kRed.withOpacity(0.10), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kRed.withOpacity(0.35))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.warning_amber_rounded, color: _kRed, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SIGNAL LOST', style: TextStyle(
            color: _kRed, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(_error, style: const TextStyle(color: _kMuted, fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _useOffline = true),
          child: const Text('→ Switch to offline mode',
              style: TextStyle(color: _kAmber, fontSize: 11,
                  decoration: TextDecoration.underline, decorationColor: _kAmber)),
        ),
      ])),
    ]),
  );

  // ─── Results ─────────────────────────────────────────────────────────────────
  Widget _results() {
    final r   = _result!;
    final col = _severityColors[r.severity] ?? _kAmber;
    return Column(children: [
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: (r.isOfflineFallback ? _kAmber : _kOliveL).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color:
              (r.isOfflineFallback ? _kAmber : _kOliveL).withOpacity(0.4))),
        child: Text(
          r.isOfflineFallback ? '▶ ON-DEVICE ENGINE · ${r.algorithm}'
              : '▶ OPSFLOOD LIVE API · ${r.algorithm}',
          style: TextStyle(
              color: r.isOfflineFallback ? _kAmber : _kOliveL,
              fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      )),
      if (r.liveRiverLevelM != null) ...[
        const SizedBox(height: 8),
        Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _kOlive.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kOlive.withOpacity(0.4))),
          child: Text('▶ LIVE CWC LEVEL: ${r.liveRiverLevelM!.toStringAsFixed(2)} m',
              style: const TextStyle(color: _kOliveL, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        )),
      ],
      const SizedBox(height: 18),
      AnimatedBuilder(
        animation: _gaugeAnim,
        builder: (_, __) {
          final prog = _gaugeAnim.value * (r.riskScore / 100.0);
          return _MilCard(
            borderColor: col.withOpacity(0.5),
            shadowColor: col.withOpacity(0.20),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('${r.alert}  ', style: const TextStyle(fontSize: 34)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('THREAT LEVEL', style: TextStyle(
                      color: _kMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  Text(r.severity, style: TextStyle(
                      color: col, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('CONFIDENCE', style: TextStyle(
                      color: _kMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Text('${r.confidencePercent.toStringAsFixed(1)}%', style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
              ]),
              const SizedBox(height: 14),
              Stack(children: [
                Container(height: 12, decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6))),
                ...[0.25, 0.50, 0.75].map((x) => Positioned(
                  left: x * (MediaQuery.of(context).size.width - 64),
                  top: 0, bottom: 0,
                  child: Container(width: 1, color: _kBorder),
                )),
                FractionallySizedBox(
                  widthFactor: prog.clamp(0.0, 1.0),
                  child: Container(height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), _kKhaki, _kAmber, _kRed],
                          stops: [0.0, 0.33, 0.66, 1.0]),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: col.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('RISK SCORE', style: TextStyle(color: _kMuted, fontSize: 10, letterSpacing: 0.8)),
                Text('${(prog * 100).round()} / 100', style: TextStyle(
                    color: col, fontWeight: FontWeight.w900, fontSize: 13)),
              ]),
            ]),
          );
        },
      ),
      const SizedBox(height: 14),
      _statsGrid(r),
      const SizedBox(height: 14),
      _probChart(r),
      const SizedBox(height: 14),
      _monitoringCard(r),
      const SizedBox(height: 8),
    ]);
  }

  Widget _statsGrid(FloodPrediction r) {
    final items = [
      _SI(Icons.speed,    'RISK SCORE',   '${r.riskScore}/100', _kOliveL),
      _SI(Icons.verified, 'CONFIDENCE',   '${r.confidencePercent.toStringAsFixed(1)}%', _kKhaki),
      _SI(Icons.hub,      'ALGORITHM',    r.algorithm, const Color(0xFF4CAF50)),
      _SI(Icons.sensors,  'DATA SOURCE',  r.dataSource, _kAmber),
    ];
    Widget card(_SI s) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder)),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: s.a.withOpacity(0.12), borderRadius: BorderRadius.circular(9),
            border: Border.all(color: s.a.withOpacity(0.3))),
          child: Icon(s.ic, color: s.a, size: 16)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(s.l, style: TextStyle(color: _kMuted, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(s.v, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ));
    return Column(children: [
      Row(children: [card(items[0]), const SizedBox(width: 10), card(items[1])]),
      const SizedBox(height: 10),
      Row(children: [card(items[2]), const SizedBox(width: 10), card(items[3])]),
    ]);
  }

  Widget _probChart(FloodPrediction r) {
    const labels = ['LOW','MODERATE','SEVERE','CRITICAL'];
    final bars = labels.asMap().entries.map((e) {
      final val = (r.probabilities[e.value] ?? 0).toDouble();
      return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
        toY: val,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [_severityColors[e.value]!.withOpacity(0.5), _severityColors[e.value]!]),
        width: 30,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      )]);
    }).toList();
    return _MilCard(
      padding: const EdgeInsets.fromLTRB(10,16,14,8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 10),
          child: Text('THREAT PROBABILITY MATRIX', style: TextStyle(
              color: _kMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0))),
        SizedBox(height: 160, child: BarChart(BarChartData(
          maxY: 100,
          barGroups: bars,
          gridData: FlGridData(
            show: true, drawVerticalLine: false, horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(color: _kBorder, strokeWidth: 1)),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                const abbr = ['LOW','MOD','SEV','CRIT'];
                final i = v.toInt();
                return i < 0 || i >= abbr.length ? const SizedBox.shrink()
                    : Padding(padding: const EdgeInsets.only(top: 4),
                        child: Text(abbr[i], style: const TextStyle(color: _kMuted, fontSize: 9)));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 30, interval: 25,
              getTitlesWidget: (v, _) =>
                  Text('${v.toInt()}%', style: const TextStyle(color: _kMuted, fontSize: 9)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )),
        ))),
      ]),
    );
  }

  Widget _monitoringCard(FloodPrediction r) {
    final col = _severityColors[r.severity] ?? _kAmber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: col.withOpacity(0.08), blurRadius: 20)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: col.withOpacity(0.4))),
          child: Icon(Icons.notifications_active, color: col, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ALERT: ${r.monitoringLevel}', style: TextStyle(
              color: col, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(r.monitoringAction, style: const TextStyle(
              color: Colors.white70, fontSize: 12, height: 1.4)),
        ])),
      ]),
    );
  }
}

// ─── Military card ────────────────────────────────────────────────────────────
class _MilCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor, shadowColor;
  const _MilCard({required this.child, this.padding, this.borderColor, this.shadowColor});
  @override Widget build(BuildContext context) => Container(
    padding: padding ?? EdgeInsets.zero,
    decoration: BoxDecoration(
      color: _kSurface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? _kBorder),
      boxShadow: shadowColor != null
          ? [BoxShadow(color: shadowColor!, blurRadius: 24, spreadRadius: 2)] : null),
    child: child,
  );
}

// ─── Military input field ─────────────────────────────────────────────────────
class _MilField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool compact;
  final Color? glowColor;
  const _MilField({required this.ctrl, required this.label, required this.hint,
      this.compact = false, this.glowColor});

  @override Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(
          color: glowColor ?? _kMuted,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.5),
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: TextStyle(color: Colors.white, fontSize: compact ? 12 : 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _kMuted.withOpacity(0.4), fontSize: 12),
          filled: true,
          fillColor: glowColor != null ? glowColor!.withOpacity(0.06) : _kSurface2,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: glowColor?.withOpacity(0.4) ?? _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: glowColor?.withOpacity(0.5) ?? _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: glowColor ?? _kOliveL, width: 1.5)),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 8 : 11),
        ),
      ),
    ],
  );
}

// ─── Military chip ────────────────────────────────────────────────────────────
class _MilChip extends StatefulWidget {
  final String label; final Color color; final IconData icon; final bool spinning;
  const _MilChip({required this.label, required this.color, required this.icon,
      this.spinning = false});
  @override State<_MilChip> createState() => _MilChipState();
}
class _MilChipState extends State<_MilChip> with SingleTickerProviderStateMixin {
  late AnimationController _spin;
  @override void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }
  @override void dispose() { _spin.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: widget.color.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: widget.color.withOpacity(0.35))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      widget.spinning
          ? RotationTransition(turns: _spin,
              child: Icon(widget.icon, color: widget.color, size: 11))
          : Icon(widget.icon, color: widget.color, size: 11),
      const SizedBox(width: 4),
      Flexible(child: Text(widget.label, style: TextStyle(
          color: widget.color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Military live badge (pulsing) ────────────────────────────────────────────
class _MilBadge extends StatefulWidget {
  final bool isLive;
  const _MilBadge({required this.isLive});
  @override State<_MilBadge> createState() => _MilBadgeState();
}
class _MilBadgeState extends State<_MilBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final color = widget.isLive ? _kOliveL : _kAmber;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15 * _anim.value), blurRadius: 8)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
            decoration: BoxDecoration(
              color: color.withOpacity(_anim.value), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)])),
          const SizedBox(width: 6),
          Text(widget.isLive ? 'LIVE' : 'OFFLINE', style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _SI {
  final IconData ic; final String l, v; final Color a;
  const _SI(this.ic, this.l, this.v, this.a);
}
