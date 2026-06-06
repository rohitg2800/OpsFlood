// lib/screens/predict_screen.dart  v4
// On-device flood risk prediction — no backend required.
// Uses city danger/warning levels from IndiaGeodata + weighted scoring.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/india_geodata.dart';
import '../l10n/context_l10n.dart';
import '../screens/city_detail_screen.dart';
import '../theme/river_theme.dart';

// ──────────────────────────────────────────────────────────────────
// ON-DEVICE PREDICTION ENGINE
// ──────────────────────────────────────────────────────────────────

class _FloodEngine {
  static _PredictResult run({
    required String  cityOrState,
    required double  peakLevelM,
    required double  rainfall7dMm,
    required double  dischargeM3s,
  }) {
    // Look up city geodata for calibrated thresholds
    final key = cityOrState.trim().toLowerCase();
    final geo = IndiaGeodata.monitoredCities.cast<Map<String,dynamic>?>().firstWhere(
      (c) => (c!['city'] as String).toLowerCase() == key ||
             (c['state'] as String).toLowerCase() == key,
      orElse: () => null,
    );

    final dangerLevel  = (geo?['danger_level']  as num?)?.toDouble() ?? 0.0;
    final warningLevel = (geo?['warning_level'] as num?)?.toDouble() ?? 0.0;
    final floodFreq    = (geo?['flood_freq']    as num?)?.toDouble() ?? 0.5;
    final zone         = (geo?['zone']          as String?) ?? 'plains';

    // ── Feature 1: Level ratio (0–1.5)
    double levelScore;
    if (dangerLevel > 0) {
      levelScore = (peakLevelM / dangerLevel).clamp(0.0, 1.5);
    } else {
      // No geodata — use generic 0–100 % assumption
      levelScore = (peakLevelM / 100.0).clamp(0.0, 1.5);
    }

    // ── Feature 2: Rainfall score (0–1.0)
    // Thresholds: 0mm=0, 200mm=0.3, 500mm=0.6, 1000mm=0.9, 2000mm+=1.0
    final rainScore = _sigmoid(rainfall7dMm, midpoint: 600, steepness: 0.003);

    // ── Feature 3: Discharge score (0–1.0) — optional
    double dischargeScore = 0.0;
    if (dischargeM3s > 0) {
      // Benchmarks: 5000 m³/s moderate, 15000 severe, 50000 critical
      dischargeScore = _sigmoid(dischargeM3s, midpoint: 15000, steepness: 0.00008);
    }

    // ── Zone multiplier
    final zoneMultiplier = _zoneMultiplier(zone);

    // ── Weighted composite score (0–1.0)
    final weights = dischargeM3s > 0
        ? [0.45, 0.30, 0.25]   // level, rain, discharge
        : [0.60, 0.40, 0.00];  // level, rain only

    double score = (
      weights[0] * levelScore.clamp(0.0, 1.0) +
      weights[1] * rainScore +
      weights[2] * dischargeScore
    ) * zoneMultiplier * (0.5 + 0.5 * floodFreq); // historical freq boost

    score = score.clamp(0.0, 1.0);

    // ── Also check absolute level vs warning/danger thresholds (hard rules)
    String hardRule = 'LOW';
    if (dangerLevel > 0) {
      if (peakLevelM >= dangerLevel * 1.10)       hardRule = 'CRITICAL';
      else if (peakLevelM >= dangerLevel)          hardRule = 'SEVERE';
      else if (peakLevelM >= warningLevel)         hardRule = 'MODERATE';
    }

    // ── Map score → risk label
    String scoreLabel;
    if      (score >= 0.80) scoreLabel = 'CRITICAL';
    else if (score >= 0.55) scoreLabel = 'SEVERE';
    else if (score >= 0.30) scoreLabel = 'MODERATE';
    else                    scoreLabel = 'LOW';

    // Take the higher of score-based and hard-rule result
    const order = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
    final finalLabel = order.indexOf(scoreLabel) >= order.indexOf(hardRule)
        ? scoreLabel : hardRule;

    // Confidence: higher when geodata is available, calibrated thresholds
    final confidence = geo != null
        ? (0.72 + 0.18 * score).clamp(0.0, 0.96)
        : (0.55 + 0.15 * score).clamp(0.0, 0.80);

    return _PredictResult(
      riskLevel:  finalLabel,
      confidence: confidence,
      score:      score,
      usedGeodata: geo != null,
    );
  }

  static double _sigmoid(double x, {required double midpoint, required double steepness}) =>
      1.0 / (1.0 + math.exp(-steepness * (x - midpoint)));

  static double _zoneMultiplier(String zone) {
    switch (zone) {
      case 'himalayan':  return 1.15;
      case 'northeast':  return 1.10;
      case 'coastal':    return 1.05;
      case 'arid':       return 0.90;
      default:           return 1.00;
    }
  }
}

// ──────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _peakLevelCtrl = TextEditingController();
  final _rainfallCtrl  = TextEditingController();
  final _dischargeCtrl = TextEditingController();
  final _stateCtrl     = TextEditingController(text: 'Bihar');

  bool    _argsRead = false;
  String? _city;

  _PredictResult? _result;

  late final AnimationController _gaugeCtrl;
  late final Animation<double>    _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _gaugeAnim = CurvedAnimation(
        parent: _gaugeCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final city     = args['city']       as String?;
      final level    = args['river_level'] as double?;
      final rainfall = args['rainfall']    as double?;
      final discharge= args['discharge']   as double?;
      if (city      != null) { _stateCtrl.text    = city; _city = city; }
      if (level     != null) { _peakLevelCtrl.text = level.toStringAsFixed(2); }
      if (rainfall  != null) { _rainfallCtrl.text  = rainfall.toStringAsFixed(0); }
      if (discharge != null) { _dischargeCtrl.text = discharge.toStringAsFixed(0); }
    }
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    _peakLevelCtrl.dispose();
    _rainfallCtrl.dispose();
    _dischargeCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  void _predict() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    _gaugeCtrl.reset();

    final result = _FloodEngine.run(
      cityOrState:  _stateCtrl.text.trim(),
      peakLevelM:   double.tryParse(_peakLevelCtrl.text.trim()) ?? 0,
      rainfall7dMm: double.tryParse(_rainfallCtrl.text.trim())  ?? 0,
      dischargeM3s: double.tryParse(_dischargeCtrl.text.trim()) ?? 0,
    );

    setState(() => _result = result);
    _gaugeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppPalette.abyss0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF005C6E), AppPalette.cyan],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Text(s.tabPredict,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
                if (_city != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppPalette.cyan.withValues(alpha: 0.4)),
                    ),
                    child: Text(_city!,
                        style: const TextStyle(
                            color: AppPalette.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            iconTheme: const IconThemeData(color: AppPalette.textWhite),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_city != null) _ContextBanner(city: _city!),
                      const SizedBox(height: 8),
                      _DarkField(
                        ctrl:  _stateCtrl,
                        label: 'City / State',
                        hint:  'e.g. Jainagar or Bihar',
                        icon:  Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:    _peakLevelCtrl,
                        label:   '${s.riverLevel} (${s.meters})',
                        hint:    'e.g. 66.28',
                        icon:    Icons.water_rounded,
                        numeric: true,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:    _rainfallCtrl,
                        label:   '${s.rainfall} 7d (${s.mmRainfall})',
                        hint:    'e.g. 450',
                        icon:    Icons.thunderstorm_rounded,
                        numeric: true,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:     _dischargeCtrl,
                        label:    '${s.discharge} (${s.cumecs})',
                        hint:     'e.g. 8500  (optional)',
                        icon:     Icons.waves_rounded,
                        numeric:  true,
                        required: false,
                      ),
                      const SizedBox(height: 22),
                      _RunButton(
                        label: s.forecast,
                        onTap: _predict,
                      ),
                    ],
                  ),
                ),

                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _ResultCard(
                    result:    _result!,
                    gaugeAnim: _gaugeAnim,
                    city:      _city,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ────────────────────────────────────────────────────────────────────

class _PredictResult {
  final String  riskLevel;
  final double  confidence;
  final double  score;
  final bool    usedGeodata;
  const _PredictResult({
    required this.riskLevel,
    required this.confidence,
    required this.score,
    required this.usedGeodata,
  });

  Color get color {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      default:         return AppPalette.safe;
    }
  }

  double get riskFraction {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL': return 1.0;
      case 'SEVERE':   return 0.75;
      case 'MODERATE': return 0.45;
      default:         return 0.15;
    }
  }

  IconData get icon {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL': return Icons.crisis_alert_rounded;
      case 'SEVERE':   return Icons.warning_rounded;
      case 'MODERATE': return Icons.warning_amber_rounded;
      default:         return Icons.check_circle_outline_rounded;
    }
  }
}

// ─── Context banner ───────────────────────────────────────────────────────────

class _ContextBanner extends StatelessWidget {
  final String city;
  const _ContextBanner({required this.city});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14, top: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppPalette.cyan.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppPalette.cyan, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pre-filled from $city live gauge — adjust as needed.',
                style: const TextStyle(
                    color: AppPalette.cyan, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

// ─── Dark-styled text field ─────────────────────────────────────────────────────────

class _DarkField extends StatelessWidget {
  final TextEditingController ctrl;
  final String   label, hint;
  final IconData icon;
  final bool     numeric, required;

  const _DarkField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.numeric  = false,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return TextFormField(
      controller:   ctrl,
      style: const TextStyle(color: AppPalette.textWhite, fontSize: 14),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: AppPalette.textGrey, fontSize: 13),
        hintText:   hint,
        hintStyle:  const TextStyle(color: AppPalette.textDim, fontSize: 12),
        prefixIcon: Icon(icon, color: AppPalette.textGrey, size: 18),
        filled:     true,
        fillColor:  AppPalette.abyss2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppPalette.abyssStroke, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppPalette.cyan.withValues(alpha: 0.6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppPalette.critical.withValues(alpha: 0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? s.noData : null
          : null,
    );
  }
}

// ─── Run button ────────────────────────────────────────────────────────────────────

class _RunButton extends StatelessWidget {
  final String     label;
  final VoidCallback onTap;
  const _RunButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF005C6E), AppPalette.cyan]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.analytics_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      );
}

// ─── Result card ───────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final _PredictResult    result;
  final Animation<double> gaugeAnim;
  final String?           city;
  const _ResultCard(
      {required this.result, required this.gaugeAnim, this.city});

  @override
  Widget build(BuildContext context) {
    final c = result.color;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: c.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 90, height: 90,
                  child: AnimatedBuilder(
                    animation: gaugeAnim,
                    builder: (_, __) => CustomPaint(
                      painter: _GaugePainter(
                        fraction: result.riskFraction * gaugeAnim.value,
                        color: c,
                      ),
                      child: Center(
                          child: Icon(result.icon, color: c, size: 26)),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Flood Risk',
                          style: TextStyle(
                              color: AppPalette.textGrey, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(result.riskLevel,
                          style: TextStyle(
                              color: c,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: c.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          'Confidence  ${(result.confidence * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: c,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!result.usedGeodata) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Generic thresholds — enter a known city for accuracy',
                          style: TextStyle(
                              color: AppPalette.textDim,
                              fontSize: 9.5,
                              height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (city != null)
            InkWell(
              onTap: () => Navigator.pushNamed(
                context,
                CityDetailScreen.route,
                arguments: city,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.07),
                  border: Border(
                      top: BorderSide(color: c.withValues(alpha: 0.18))),
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_rounded, color: c, size: 14),
                    const SizedBox(width: 7),
                    Text('View $city live gauge  →',
                        style: TextStyle(
                            color: c,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Arc gauge painter ─────────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color  color;
  const _GaugePainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final r    = math.min(cx, cy) - 6;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);

    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5 * fraction, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
