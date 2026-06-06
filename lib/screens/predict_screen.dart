// lib/screens/predict_screen.dart  v3
// Phase 4 — full dark-theme polish + route-arg pre-fill + rich result card
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../l10n/context_l10n.dart';
import '../screens/city_detail_screen.dart';
import '../theme/river_theme.dart';

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

  bool    _loading  = false;
  bool    _argsRead = false;
  String? _city;

  _PredictResult? _result;
  String?         _error;

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
      final city  = args['city']  as String?;
      final level = args['river_level'] as double?;
      if (city  != null) { _stateCtrl.text = city; _city = city; }
      if (level != null) { _peakLevelCtrl.text = level.toStringAsFixed(2); }
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

  Future<void> _predict() async {
    // currentState is guaranteed non-null because the Form widget is mounted
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    setState(() { _loading = true; _result = null; _error = null; });
    _gaugeCtrl.reset();

    final payload = {
      'state':          _stateCtrl.text.trim(),
      'peak_level_m':   double.parse(_peakLevelCtrl.text.trim()),
      'rainfall_7d_mm': double.parse(_rainfallCtrl.text.trim()),
      'discharge_m3s':  double.tryParse(_dischargeCtrl.text.trim()) ?? 0.0,
    };

    try {
      // FIX: prepend baseUrl so the URI has a valid host
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.epPredict}');
      final res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload))
          .timeout(AppConfig.coldStartTimeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final level = (body['risk_level'] ??
                body['riskLevel'] ??
                'UNKNOWN')
            .toString();
        final prob = (body['probability'] ?? body['confidence']) as num?;
        setState(() {
          _result = _PredictResult(
            riskLevel:  level,
            confidence: prob?.toDouble(),
          );
        });
        _gaugeCtrl.forward();
      } else {
        setState(() =>
            _error = 'Backend returned HTTP ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                // ── Form wraps ALL validated fields ────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_city != null) _ContextBanner(city: _city!),
                      const SizedBox(height: 8),
                      _DarkField(
                        ctrl:  _stateCtrl,
                        label: 'State / City',
                        hint:  'e.g. Bihar',
                        icon:  Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 12),
                      _DarkField(
                        ctrl:    _peakLevelCtrl,
                        label:   '${s.riverLevel} (${s.meters})',
                        hint:    'e.g. 12.5',
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
                        loading: _loading,
                        label:   s.forecast,
                        onTap:   _predict,
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
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: _error!),
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
  final double? confidence;
  const _PredictResult({required this.riskLevel, this.confidence});

  Color get color {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL': return AppPalette.critical;
      case 'HIGH':
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      default:         return AppPalette.safe;
    }
  }

  double get riskFraction {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL': return 1.0;
      case 'HIGH':
      case 'SEVERE':   return 0.75;
      case 'MODERATE': return 0.45;
      default:         return 0.15;
    }
  }

  IconData get icon {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL': return Icons.crisis_alert_rounded;
      case 'HIGH':
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
  final bool       loading;
  final String     label;
  final VoidCallback onTap;
  const _RunButton(
      {required this.loading, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: loading
                ? const LinearGradient(
                    colors: [Color(0xFF1A2A35), Color(0xFF1A2A35)])
                : const LinearGradient(
                    colors: [Color(0xFF005C6E), AppPalette.cyan]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: loading
                ? []
                : [
                    BoxShadow(
                        color: AppPalette.cyan.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1),
                  ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppPalette.cyan))
                : Row(
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

// ─── Result card with animated gauge arc ────────────────────────────────────────────

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
                      if (result.confidence != null) ...[
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
                            'Confidence  ${(result.confidence! * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: c,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
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

// ─── Error card ────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.critical.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppPalette.critical.withValues(alpha: 0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppPalette.critical, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 12,
                      height: 1.5)),
            ),
          ],
        ),
      );
}
