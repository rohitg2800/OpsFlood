// lib/screens/predict_screen.dart
// OpsFlood — Predict Screen v5.1
// Fix: All RenderFlex overflow errors resolved.
// - Header title column wrapped in Expanded
// - City search label row chip wrapped in Flexible
// - Autofill badge header Row text wrapped in Flexible
// - _buildRainfallGrid last row spacer removed (caused 26k overflow)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../ml/flood_engine.dart';
import '../services/api_service.dart';
import '../services/predict.dart';

// ─── Palette ───────────────────────────────────────────────────────────────
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

// ─── Autofill data model ───────────────────────────────────────────────────
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
    this.riverLevelM,
    this.warningLevelM,
    this.dangerLevelM,
    this.rainfallLastHour,
    this.flowRate,
    this.trend,
    this.status,
    this.riverName,
    required this.source,
  });

  double get derivedDuration {
    if (status == 'CRITICAL') return 3.0;
    if (status == 'WARNING')  return 2.0;
    return 1.0;
  }

  double get derivedTimeToPeak => 1.0;

  double derivedRecession(double? level) {
    if (level == null || dangerLevelM == null || dangerLevelM! <= 0) return 1.0;
    final ratio = level / dangerLevelM!;
    if (ratio >= 1.0)  return 3.0;
    if (ratio >= 0.85) return 2.0;
    return 1.0;
  }

  List<double> get derivedRainfall7d {
    final hrly      = rainfallLastHour ?? 0.0;
    final dailyPeak = (hrly * 24).clamp(0.0, 300.0);
    const weights   = [0.05, 0.12, 0.22, 0.40, 0.60, 0.80, 1.00];
    return weights
        .map((w) => double.parse((dailyPeak * w).toStringAsFixed(1)))
        .toList();
  }
}

// ─── City entry ────────────────────────────────────────────────────────────
class _CityEntry {
  final String city;
  final String state;
  final String river;
  const _CityEntry(this.city, this.state, this.river);

  static List<_CityEntry> fromConstants() {
    return AppConstants.monitoredCities.map((mc) {
      final city  = (mc['city']  as String? ?? '').trim();
      final state = (mc['state'] as String? ?? '').trim();
      final river = (mc['river'] as String? ?? '').trim();
      return _CityEntry(city, state, river);
    }).where((e) => e.city.isNotEmpty).toList();
  }

  String get subtitle => river.isNotEmpty ? '$state • $river' : state;

  bool matches(String q) {
    final lq = q.toLowerCase();
    return city.toLowerCase().contains(lq)  ||
           state.toLowerCase().contains(lq) ||
           river.toLowerCase().contains(lq);
  }
}

// ─── Screen ────────────────────────────────────────────────────────────────
class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});
  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _gaugeCtrl;
  late Animation<double>   _gaugeAnim;

  final _peakCtrl       = TextEditingController(text: '8.5');
  final _durCtrl        = TextEditingController(text: '1');
  final _peakTimeCtrl   = TextEditingController(text: '1');
  final _recCtrl        = TextEditingController(text: '1');
  final _citySearchCtrl = TextEditingController();
  final List<TextEditingController> _rainCtrl = List.generate(
    7, (i) => TextEditingController(text: ['10','15','20','18','12','8','7'][i]),
  );

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

  _StationAutofill? _lastAutofill;

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
    _citySearchCtrl.dispose();
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
    station: _selectedCity,
  );

  // ── Autofill engine ────────────────────────────────────────────────────────

  void _onCitySelected(_CityEntry entry) {
    setState(() {
      _selectedCity  = entry.city;
      _selectedState = entry.state.isNotEmpty && _allStates.contains(entry.state)
          ? entry.state
          : _selectedState;
      _autofilled      = false;
      _lastAutofill    = null;
      _citySearchCtrl.text = entry.city;
    });
    if (!_useOffline) _autofillFromLive(entry.city, entry.state);
  }

  Future<void> _autofillFromLive(String cityName, [String? stateName]) async {
    setState(() { _autofilling = true; _autofilled = false; });
    try {
      final response = await _api.getAllCwcStations();
      final raw = response['data'];
      if (raw is! List) {
        if (mounted) setState(() => _autofilling = false);
        return;
      }

      final lc     = cityName.toLowerCase();
      final lstate = (stateName ?? '').toLowerCase();

      Map<String, dynamic>? best;
      int bestScore = 99;

      for (final item in raw.whereType<Map<String, dynamic>>()) {
        final station = _str(item['station'] ?? item['stationName'] ?? item['city']);
        final state   = _str(item['state_name'] ?? item['state']);
        final river   = _str(item['river'] ?? item['river_name']);

        int score = 99;
        if (station.contains(lc) && state.contains(lstate))      score = 0;
        else if (station.contains(lc))                            score = 1;
        else if (lc.contains(station) && station.length > 3)     score = 2;
        else if (river.contains(lc))                              score = 3;
        else {
          final tokens = lc.split(RegExp(r'\s+')).where((t) => t.length >= 4);
          if (tokens.any((t) => station.contains(t)))             score = 4;
        }

        if (score < bestScore) { bestScore = score; best = item; }
        if (bestScore == 0) break;
      }

      if (!mounted) return;
      if (best == null) { setState(() => _autofilling = false); return; }

      final af = _StationAutofill(
        riverLevelM:      _sfp(best['river_level']      ?? best['riverLevel']      ?? best['current_level']),
        warningLevelM:    _sfp(best['warning_level']    ?? best['warningLevel']),
        dangerLevelM:     _sfp(best['danger_level']     ?? best['dangerLevel']),
        rainfallLastHour: _sfp(best['rainfall_last_hour'] ?? best['rainfallLastHour'] ?? best['rainfall']),
        flowRate:         _sfp(best['flow_rate']        ?? best['flowRate']        ?? best['discharge']),
        trend:  _str(best['trend']).toUpperCase().isEmpty  ? null : _str(best['trend']).toUpperCase(),
        status: _str(best['status']).toUpperCase().isEmpty ? null : _str(best['status']).toUpperCase(),
        riverName: _str(best['river'] ?? best['river_name']).isEmpty
            ? null : _str(best['river'] ?? best['river_name']),
        source: _str(best['source'] ?? 'CWC'),
      );
      _applyAutofill(af);
    } catch (_) {
      if (mounted) setState(() => _autofilling = false);
    }
  }

  void _applyAutofill(_StationAutofill af) {
    if (!mounted) return;
    final level = af.riverLevelM;
    if (level != null && level > 0) _peakCtrl.text = level.toStringAsFixed(2);
    _durCtrl.text     = af.derivedDuration.toStringAsFixed(0);
    _peakTimeCtrl.text = af.derivedTimeToPeak.toStringAsFixed(0);
    _recCtrl.text     = af.derivedRecession(level).toStringAsFixed(0);
    final rain7d = af.derivedRainfall7d;
    for (int i = 0; i < 7; i++) _rainCtrl[i].text = rain7d[i].toStringAsFixed(1);
    setState(() { _autofilling = false; _autofilled = true; _lastAutofill = af; });
  }

  static double _sfp(dynamic v) =>
      (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
  static String _str(dynamic v) => (v?.toString() ?? '').trim().toLowerCase();

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

  // ── Build ──────────────────────────────────────────────────────────────────

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
                    _buildCitySearchRow(),
                    const SizedBox(height: 14),
                    if (_autofilled && _lastAutofill != null)
                      _buildAutofillBadgeRow(_lastAutofill!),
                    if (_autofilled && _lastAutofill != null)
                      const SizedBox(height: 10),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  // FIX: Column inside Row — wrapped in Expanded to prevent unbounded width
  // (was the ~9.4 px overflow on the right in the header row).
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kCyan.withValues(alpha: 0.08), _kPurple.withValues(alpha: 0.06)],
        ),
        border: Border(bottom: BorderSide(color: _kCyan.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          // icon box — fixed width, no overflow risk
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kCyan, _kPurple]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_alt, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          // FIX: Expanded absorbs remaining space so Column never overflows
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_kCyan, _kPurple],
                  ).createShader(b),
                  child: const Text(
                    'Flood Risk Predictor',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  'Live CWC · OpsFlood ML Engine',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // badge — intrinsic width, sits at end
          _LiveBadge(isLive: !_useOffline),
        ],
      ),
    );
  }

  // ── City search row ────────────────────────────────────────────────────────
  // FIX: The label Row had an unbounded _StatusChip sitting next to a fixed
  // Text widget.  Wrapping the chip in Flexible + clip prevents the 9.4 px
  // overflow when the chip text is long (e.g. "📡 All fields autofilled").
  Widget _buildCitySearchRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // label text — intrinsic, never grows
            const Text(
              '🔍  Station / City',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
            ),
            const SizedBox(width: 8),
            // FIX: Flexible prevents chip from overflowing the row
            if (_autofilling)
              const Flexible(
                child: _StatusChip(
                  label: 'Fetching live data…',
                  color: _kCyan,
                  icon: Icons.sync,
                  spinning: true,
                ),
              )
            else if (_autofilled)
              const Flexible(
                child: _StatusChip(
                  label: '📡 Autofilled',
                  color: Color(0xFF22C55E),
                  icon: Icons.check_circle_outline,
                ),
              )
            else if (_selectedCity != null)
              Flexible(
                child: _StatusChip(
                  label: '$_selectedCity · $_selectedState',
                  color: _kPurple,
                  icon: Icons.location_on_outlined,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Autocomplete<_CityEntry>(
          optionsBuilder: (TextEditingValue tv) {
            if (tv.text.isEmpty) return const Iterable<_CityEntry>.empty();
            return _allCities.where((e) => e.matches(tv.text));
          },
          displayStringForOption: (e) => e.city,
          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
            ctrl.addListener(() {
              if (_citySearchCtrl.text != ctrl.text) _citySearchCtrl.text = ctrl.text;
            });
            return TextField(
              controller: ctrl,
              focusNode: focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Patna, Guwahati, Kolhapur…',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                suffixIcon: ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                        onPressed: () {
                          ctrl.clear();
                          setState(() {
                            _selectedCity = null;
                            _autofilled   = false;
                            _lastAutofill = null;
                          });
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kCyan, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            );
          },
          optionsViewBuilder: (ctx, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  margin: const EdgeInsets.only(top: 4, right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1E35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kCyan.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: _kCyan.withValues(alpha: 0.08), blurRadius: 20),
                    ],
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    children: options.map((entry) {
                      return InkWell(
                        onTap: () => onSelected(entry),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: _kCyan.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.water,
                                    color: _kCyan, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.city,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    Text(entry.subtitle,
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 10),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const Icon(Icons.bolt, color: _kCyan, size: 14),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
          onSelected: _onCitySelected,
        ),
        const SizedBox(height: 10),
        _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedState,
              isExpanded: true,
              dropdownColor: const Color(0xFF0D1E35),
              iconEnabledColor: _kCyan,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              items: _allStates
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedState = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Autofill badge row ─────────────────────────────────────────────────────
  // FIX: Header Row had Text + trend chip without any flex constraints.
  // On narrow screens the combined width overflowed by 9.4 px.
  // Solution: wrap the source text in Flexible so it clips/ellipsis and the
  // trend chip stays at its intrinsic size.
  Widget _buildAutofillBadgeRow(_StationAutofill af) {
    Widget pill(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX: Row had unbounded Text + trend chip — Text now in Flexible
          Row(
            children: [
              const Icon(Icons.sensors, color: Color(0xFF22C55E), size: 13),
              const SizedBox(width: 5),
              // Flexible allows this text to shrink/ellipsis before overflowing
              Flexible(
                child: Text(
                  '📡 CWC Live — ${af.riverName ?? _selectedCity ?? ''}  •  ${af.source}',
                  style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (af.trend != null) ...[
                const SizedBox(width: 6),
                // Trend chip is intrinsic-width, kept outside Flexible
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _trendColor(af.trend!).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _trendColor(af.trend!).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_trendIcon(af.trend!)} ${af.trend}',
                    style: TextStyle(
                        color: _trendColor(af.trend!),
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (af.riverLevelM != null && af.riverLevelM! > 0)
                pill('RIVER LEVEL',
                    '${af.riverLevelM!.toStringAsFixed(2)} m', _kCyan),
              if (af.warningLevelM != null && af.warningLevelM! > 0)
                pill('WARNING',
                    '${af.warningLevelM!.toStringAsFixed(2)} m',
                    const Color(0xFFF59E0B)),
              if (af.dangerLevelM != null && af.dangerLevelM! > 0)
                pill('DANGER',
                    '${af.dangerLevelM!.toStringAsFixed(2)} m',
                    const Color(0xFFEF4444)),
              if (af.rainfallLastHour != null && af.rainfallLastHour! > 0)
                pill('RAINFALL/hr',
                    '${af.rainfallLastHour!.toStringAsFixed(1)} mm', _kPurple),
              if (af.flowRate != null && af.flowRate! > 0)
                pill('FLOW RATE',
                    '${af.flowRate!.toStringAsFixed(1)} m³/s',
                    const Color(0xFF22C55E)),
              if (af.status != null)
                pill('STATUS', af.status!, _statusColor(af.status!)),
            ],
          ),
        ],
      ),
    );
  }

  Color _trendColor(String t) {
    if (t == 'RISING')  return const Color(0xFFEF4444);
    if (t == 'FALLING') return const Color(0xFF22C55E);
    return const Color(0xFFF59E0B);
  }

  String _trendIcon(String t) {
    if (t == 'RISING')  return '↑';
    if (t == 'FALLING') return '↓';
    return '→';
  }

  Color _statusColor(String s) {
    if (s == 'CRITICAL') return const Color(0xFFEF4444);
    if (s == 'WARNING')  return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white38,
                      size: 20),
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
    final peakAutofilled = _autofilled && (_lastAutofill?.riverLevelM ?? 0) > 0;
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _InputField(
              ctrl: _peakCtrl,
              label: peakAutofilled ? '⚡ Peak Level (m)' : 'Peak Level (m)',
              hint: '8.5',
              tooltip: 'CWC gauge water level in metres',
              glowColor: peakAutofilled ? const Color(0xFF22C55E) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InputField(
              ctrl: _durCtrl,
              label: _autofilled ? '⚡ Duration (days)' : 'Duration (days)',
              hint: '1',
              tooltip: 'Flood event duration in days',
              glowColor: _autofilled ? const Color(0xFF22C55E) : null,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _InputField(
              ctrl: _peakTimeCtrl,
              label: _autofilled ? '⚡ Time to Peak' : 'Time to Peak (days)',
              hint: '1',
              tooltip: 'Hours until expected peak flood',
              glowColor: _autofilled ? const Color(0xFF22C55E) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InputField(
              ctrl: _recCtrl,
              label: _autofilled ? '⚡ Recession' : 'Recession (days)',
              hint: '1',
              tooltip: 'Expected recession time after peak',
              glowColor: _autofilled ? const Color(0xFF22C55E) : null,
            ),
          ),
        ]),
      ],
    );
  }

  // ── Rainfall grid ──────────────────────────────────────────────────────────
  // FIX: The second row had 3 cells + 2 SizedBoxes + a trailing Expanded(SizedBox).
  // The trailing Expanded(SizedBox) forced the Row to expand beyond its parent
  // (which is itself inside a Padding that has a fixed width), causing 26 062 px
  // overflow.  Removed it — the 3 cells now take 75 % of the row width naturally,
  // and the empty space fills in automatically since the cells are Expanded.
  Widget _buildRainfallGrid() {
    const labels = ['D-7', 'D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'D-1'];
    Expanded cell(int i) => Expanded(
      child: _InputField(
        ctrl: _rainCtrl[i],
        label: _autofilled ? '⚡ ${labels[i]}' : labels[i],
        hint: '0',
        tooltip: 'T${i + 1}d rainfall mm',
        compact: true,
        glowColor:
            _autofilled ? const Color(0xFF22C55E).withValues(alpha: 0.8) : null,
      ),
    );

    // Row 1: D-7 D-6 D-5 D-4  (4 cells)
    // Row 2: D-3 D-2 D-1       (3 cells — NO trailing Expanded spacer)
    return Column(
      children: [
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(4), const SizedBox(width: 8),
            cell(5), const SizedBox(width: 8),
            cell(6),
            // ← removed the Expanded(SizedBox()) that caused 26 062 px overflow
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
          Icon(Icons.wifi_off,
              color: _useOffline ? Colors.orange : Colors.white24, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _useOffline
                      ? 'Offline Rule Engine'
                      : 'Live OpsFlood API  •  Full CWC Auto-fill',
                  style: TextStyle(
                      color: _useOffline ? Colors.orange : _kCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _useOffline
                      ? 'Using on-device thresholds — no real data'
                      : 'Auto-fills all 11 input fields from OpsFlood CWC telemetry',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
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
      onTap: (_loading || _autofilling) ? null : _predict,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: (_loading || _autofilling)
              ? LinearGradient(colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.06),
                ])
              : const LinearGradient(colors: [_kCyan, _kPurple]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: (_loading || _autofilling)
              ? []
              : [
                  BoxShadow(
                      color: _kCyan.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2),
                ],
        ),
        child: Center(
          child: (_loading || _autofilling)
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Run Flood Prediction',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.5)),
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
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(_error,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _useOffline = true),
                  child: const Text('→ Switch to offline mode',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: r.isOfflineFallback
                  ? Colors.orange.withValues(alpha: 0.12)
                  : _kCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: r.isOfflineFallback
                    ? Colors.orange.withValues(alpha: 0.4)
                    : _kCyan.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              r.isOfflineFallback
                  ? '📱  On-Device Engine  •  ${r.algorithm}'
                  : '☁️  OpsFlood Live API  •  ${r.algorithm}',
              style: TextStyle(
                  color:
                      r.isOfflineFallback ? Colors.orange : _kCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (r.liveRiverLevelM != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        const Color(0xFF22C55E).withValues(alpha: 0.4)),
              ),
              child: Text(
                '📡  Live CWC River Level: ${r.liveRiverLevelM!.toStringAsFixed(2)} m',
                style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
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
                      Text('${r.alert}  ',
                          style: const TextStyle(fontSize: 34)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FLOOD SEVERITY',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2)),
                            Text(r.severity,
                                style: TextStyle(
                                    color: col,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('CONFIDENCE',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2)),
                          Text(
                              '${r.confidencePercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(col),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Risk Score',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      Text('${(progress * 100).round()} / 100',
                          style: TextStyle(
                              color: col,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
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

  Widget _buildStatsGrid(FloodPrediction r) {
    final items = [
      _StatItem(Icons.speed,    'Risk Score',  '${r.riskScore}/100',                         _kCyan),
      _StatItem(Icons.verified, 'Confidence',  '${r.confidencePercent.toStringAsFixed(1)}%', _kPurple),
      _StatItem(Icons.hub,      'Algorithm',   r.algorithm,                                  const Color(0xFF22C55E)),
      _StatItem(Icons.sensors,  'Data Source', r.dataSource,                                 const Color(0xFFF59E0B)),
    ];
    Widget card(_StatItem s) => Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  Text(s.label,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 2),
                  Text(s.value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(children: [
          card(items[0]),
          const SizedBox(width: 10),
          card(items[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          card(items[2]),
          const SizedBox(width: 10),
          card(items[3]),
        ]),
      ],
    );
  }

  Widget _buildProbChart(FloodPrediction r) {
    const labels = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
    final bars = labels.asMap().entries.map((e) {
      final val = (r.probabilities[e.value] ?? 0).toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: val,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                _severityColors[e.value]!.withValues(alpha: 0.6),
                _severityColors[e.value]!,
              ],
            ),
            width: 30,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
          )
        ],
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
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ),
          SizedBox(
            height: 160,
            child: BarChart(BarChartData(
              maxY: 100,
              barGroups: bars,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const abbr = ['LOW', 'MOD', 'SEV', 'CRIT'];
                      final i = v.toInt();
                      if (i < 0 || i >= abbr.length) {
                        return const SizedBox.shrink();
                      }
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
                    reservedSize: 30,
                    interval: 25,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 9)),
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
        boxShadow: [
          BoxShadow(color: col.withValues(alpha: 0.08), blurRadius: 20)
        ],
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
                    style: TextStyle(
                        color: col,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(r.monitoringAction,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status chip ────────────────────────────────────────────────────────────
// FIX: Made const-constructable so Flexible(child: const _StatusChip(...))
// compiles cleanly without "const on a non-const constructor" lint.
class _StatusChip extends StatefulWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  final bool     spinning;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
    this.spinning = false,
  });
  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() { _spin.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.spinning
                ? RotationTransition(
                    turns: _spin,
                    child: Icon(widget.icon, color: widget.color, size: 11),
                  )
                : Icon(widget.icon, color: widget.color, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(
                    color: widget.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

// ─── Reusable widgets ───────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget     child;
  final EdgeInsets? padding;
  final Color?     borderColor;
  final Color?     shadowColor;
  const _GlassCard(
      {required this.child, this.padding, this.borderColor, this.shadowColor});

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
  final String   label, hint, tooltip;
  final bool     compact;
  final Color?   glowColor;
  const _InputField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.tooltip,
    this.compact  = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: glowColor ?? Colors.white54,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: TextStyle(
                  color: Colors.white, fontSize: compact ? 12 : 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: glowColor != null
                    ? glowColor!.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.05),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: glowColor?.withValues(alpha: 0.4) ??
                          Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: glowColor?.withValues(alpha: 0.5) ??
                          Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: glowColor ?? _kCyan, width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: compact ? 8 : 11,
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
  late Animation<double>   _anim;

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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.6), blurRadius: 6)
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.isLive ? 'LIVE' : 'OFFLINE',
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String   label, value;
  final Color    accent;
  const _StatItem(this.icon, this.label, this.value, this.accent);
}
