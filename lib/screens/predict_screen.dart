// lib/screens/predict_screen.dart  v6  (full RiverColors token migration)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/india_geodata.dart';
import '../l10n/context_l10n.dart';
import '../ml/flood_engine.dart';
import '../screens/city_detail_screen.dart';
import '../theme/river_theme.dart';

// ────────────────────────────────────────────────────────────────────
// SCREEN
// ────────────────────────────────────────────────────────────────────

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen>
    with SingleTickerProviderStateMixin {

  final _formKey        = GlobalKey<FormState>();
  final _stateCtrl      = TextEditingController(text: 'Bihar');
  final _levelCtrl      = TextEditingController();
  final _rainfallCtrl   = TextEditingController();
  final _dischargeCtrl  = TextEditingController();
  final _durationCtrl   = TextEditingController(text: '3');
  final _timeToPeakCtrl = TextEditingController(text: '1');
  final _recessionCtrl  = TextEditingController(text: '2');

  bool    _argsRead = false;
  String? _city;
  bool    _showAdvanced = false;

  FloodResult? _result;

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
      final city      = args['city']        as String?;
      final level     = args['river_level']  as double?;
      final rainfall  = args['rainfall']     as double?;
      final discharge = args['discharge']    as double?;
      final state     = args['state']        as String?;
      if (city      != null) { _city = city; _stateCtrl.text = city; }
      if (state     != null) { _stateCtrl.text = state; }
      if (level     != null) { _levelCtrl.text    = level.toStringAsFixed(2); }
      if (rainfall  != null) { _rainfallCtrl.text = rainfall.toStringAsFixed(0); }
      if (discharge != null) { _dischargeCtrl.text= discharge.toStringAsFixed(0); }
    }
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    for (final c in [_stateCtrl,_levelCtrl,_rainfallCtrl,_dischargeCtrl,
                     _durationCtrl,_timeToPeakCtrl,_recessionCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  List<double> _splitRainfall(double total) {
    final daily = total / 7.0;
    return List.filled(7, daily);
  }

  String _resolveState(String input) {
    final key = input.trim().toLowerCase();
    final match = IndiaGeodata.monitoredCities
        .cast<Map<String,dynamic>?>()
        .firstWhere(
          (c) => (c!['city'] as String).toLowerCase() == key,
          orElse: () => null,
        );
    if (match != null) return match['state'] as String;
    final stateMatch = IndiaGeodata.states
        .firstWhere(
          (s) => s.toLowerCase() == key,
          orElse: () => '',
        );
    return stateMatch.isNotEmpty ? stateMatch : input;
  }

  void _predict() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    _gaugeCtrl.reset();

    final stateOrCity   = _stateCtrl.text.trim();
    final resolvedState = _resolveState(stateOrCity);
    final rainfall      = double.tryParse(_rainfallCtrl.text.trim()) ?? 0;
    final dailyRain     = _splitRainfall(rainfall);

    final input = FloodInput(
      state:              resolvedState,
      station:            _city,
      peakFloodLevelM:    double.tryParse(_levelCtrl.text.trim()) ?? 0,
      eventDurationDays:  double.tryParse(_durationCtrl.text.trim()) ?? 3,
      timeToPeakDays:     double.tryParse(_timeToPeakCtrl.text.trim()) ?? 1,
      recessionTimeDay:   double.tryParse(_recessionCtrl.text.trim()) ?? 2,
      t1d: dailyRain[0], t2d: dailyRain[1], t3d: dailyRain[2],
      t4d: dailyRain[3], t5d: dailyRain[4], t6d: dailyRain[5],
      t7d: dailyRain[6],
    );

    final result = runOnDeviceEngine(input);
    setState(() => _result = result);
    _gaugeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: t.navBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [t.cardBgElevated, t.accent]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Text(s.tabPredict,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                if (_city != null) ...[
                  const SizedBox(width: 8),
                  _Chip(label: _city!, color: t.accent),
                ],
              ],
            ),
            iconTheme: IconThemeData(color: t.textPrimary),
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
                        hint:  'e.g. Jainagar, Bihar',
                        icon:  Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:    _levelCtrl,
                        label:   '${s.riverLevel} (${s.meters})',
                        hint:    'e.g. 66.28',
                        icon:    Icons.water_rounded,
                        numeric: true,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:    _rainfallCtrl,
                        label:   '${s.rainfall} 7d (${s.mmRainfall})',
                        hint:    'Total last 7 days — e.g. 1290',
                        icon:    Icons.thunderstorm_rounded,
                        numeric: true,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:     _dischargeCtrl,
                        label:    '${s.discharge} (${s.cumecs}) — optional',
                        hint:     'e.g. 8000',
                        icon:     Icons.waves_rounded,
                        numeric:  true,
                        required: false,
                      ),

                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvanced
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: t.textSecondary, size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showAdvanced
                                  ? 'Hide event parameters'
                                  : 'Flood event parameters (optional — improves accuracy)',
                              style: TextStyle(color: t.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      if (_showAdvanced) ...[
                        const SizedBox(height: 10),
                        _DarkField(
                          ctrl:     _durationCtrl,
                          label:    'Event duration (days)',
                          hint:     'e.g. 3',
                          icon:     Icons.timelapse_rounded,
                          numeric:  true,
                          required: false,
                        ),
                        const SizedBox(height: 10),
                        _DarkField(
                          ctrl:     _timeToPeakCtrl,
                          label:    'Time to peak (days)',
                          hint:     'e.g. 1',
                          icon:     Icons.trending_up_rounded,
                          numeric:  true,
                          required: false,
                        ),
                        const SizedBox(height: 10),
                        _DarkField(
                          ctrl:     _recessionCtrl,
                          label:    'Recession time (days)',
                          hint:     'e.g. 2',
                          icon:     Icons.trending_down_rounded,
                          numeric:  true,
                          required: false,
                        ),
                      ],

                      const SizedBox(height: 22),
                      _RunButton(label: s.forecast, onTap: _predict),
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

// ────────────────────────────────────────────────────────────────────
// RESULT CARD
// ────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final FloodResult       result;
  final Animation<double> gaugeAnim;
  final String?           city;
  const _ResultCard({required this.result, required this.gaugeAnim, this.city});

  Color get _color {
    switch (result.severity) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      default:         return AppPalette.safe;
    }
  }

  IconData get _icon {
    switch (result.severity) {
      case 'CRITICAL': return Icons.crisis_alert_rounded;
      case 'SEVERE':   return Icons.warning_rounded;
      case 'MODERATE': return Icons.warning_amber_rounded;
      default:         return Icons.check_circle_outline_rounded;
    }
  }

  double get _gaugeFraction {
    switch (result.severity) {
      case 'CRITICAL': return 1.0;
      case 'SEVERE':   return 0.75;
      case 'MODERATE': return 0.45;
      default:         return 0.15;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final c     = _color;
    final probs = result.probabilities;

    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                          fraction: _gaugeFraction * gaugeAnim.value,
                          color: c),
                      child: Center(child: Icon(_icon, color: c, size: 26)),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flood Risk',
                          style: TextStyle(color: t.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${result.alert}  ${result.severity}',
                        style: TextStyle(
                            color: c, fontSize: 24,
                            fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Chip(
                            label: 'Confidence  ${result.confidencePercent.toStringAsFixed(0)}%',
                            color: c,
                          ),
                          const SizedBox(width: 6),
                          _Chip(
                            label: 'Risk ${result.riskScore}/100',
                            color: c,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Divider(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Probability Distribution',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final label in ['CRITICAL','SEVERE','MODERATE','LOW'])
                  _ProbRow(
                    label: label,
                    percent: probs[label] ?? 0,
                    highlight: label == result.severity,
                  ),
              ],
            ),
          ),

          _Divider(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar_rounded, color: c, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      result.monitoringLevel,
                      style: TextStyle(
                          color: c, fontSize: 12,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.monitoringAction,
                  style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),

          _Divider(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBox(
                  label: 'Proximity to\nDanger Level',
                  value: '${result.proximityToDangerM >= 0 ? '' : '−'}'
                         '${result.proximityToDangerM.abs().toStringAsFixed(2)} m',
                  color: result.proximityToDangerM <= 0 ? AppPalette.critical : c,
                ),
                _StatBox(
                  label: 'Threshold\nSeverity',
                  value: result.thresholdSeverity,
                  color: c,
                ),
                _StatBox(
                  label: 'Algorithm',
                  value: 'Ensemble v1.2',
                  color: t.textSecondary,
                ),
              ],
            ),
          ),

          if (city != null)
            InkWell(
              onTap: () => Navigator.pushNamed(
                  context, CityDetailScreen.route, arguments: city),
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.07),
                  border: Border(top: BorderSide(color: c.withValues(alpha: 0.18))),
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
                            color: c, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Probability row ──────────────────────────────────────────────────────────

class _ProbRow extends StatelessWidget {
  final String label;
  final double percent;
  final bool   highlight;
  const _ProbRow({required this.label, required this.percent, required this.highlight});

  Color get _barColor {
    switch (label) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      default:         return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final c    = _barColor;
    final frac = (percent / 100.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                  color: highlight ? c : t.textSecondary,
                  fontSize: 10,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: highlight ? c : c.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: highlight ? c : t.stroke,
                  fontSize: 10,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat box ─────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Column(
      children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.stroke, fontSize: 9.5, height: 1.3)),
      ],
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color:  color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Divider(height: 1, thickness: 1, color: t.stroke);
  }
}

class _ContextBanner extends StatelessWidget {
  final String city;
  const _ContextBanner({required this.city});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14, top: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: t.accent, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pre-filled from $city live gauge — adjust as needed.',
              style: TextStyle(color: t.accent, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final t = RiverColors.of(context);
    return TextFormField(
      controller:   ctrl,
      style: TextStyle(color: t.textPrimary, fontSize: 14),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(color: t.textSecondary, fontSize: 13),
        hintText:   hint,
        hintStyle:  TextStyle(color: t.stroke, fontSize: 12),
        prefixIcon: Icon(icon, color: t.textSecondary, size: 18),
        filled:     true,
        fillColor:  t.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.stroke, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppPalette.critical.withValues(alpha: 0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? s.noData : null
          : null,
    );
  }
}

class _RunButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _RunButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [t.cardBgElevated, t.accent]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: t.accentGlow,
                blurRadius: 16,
                spreadRadius: 1),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
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
}

// ─── Arc gauge ────────────────────────────────────────────────────────────────

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
    final bg   = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final fg   = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, bg);
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5 * fraction, false, fg);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
