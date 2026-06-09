// lib/screens/predict_screen.dart
// OpsFlood — PredictScreen v2  (full RiverColors restyle)
//
// Changes from v1:
//   • Full RiverColors token theming — dark/light/sunset/ocean all work
//   • Header matches CityDetailScreen / PredictionScreen style
//   • Input fields: dark card style with accent border on focus
//   • Animated gradient CTA button with glow (matches DashboardScreen)
//   • Result card: animated entry, colour-coded risk level, confidence ring
//   • City+level pre-fill support (route args: {city, river_level})
//   • Auto-populates fields when navigated from CityDetailScreen
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../l10n/context_l10n.dart';
import '../theme/river_theme.dart';

class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});
  static const String route = '/predict';

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _stateCtrl     = TextEditingController(text: 'Bihar');
  final _peakLevelCtrl = TextEditingController();
  final _rainfallCtrl  = TextEditingController();
  final _dischargeCtrl = TextEditingController();

  bool _loading = false;
  _PredictResult? _result;
  String? _error;

  // Animation controller for result card entry
  late final AnimationController _resultAnim;
  late final Animation<double>    _resultFade;
  late final Animation<Offset>    _resultSlide;

  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultFade = CurvedAnimation(
        parent: _resultAnim, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _resultAnim, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill from CityDetailScreen args: {city, river_level}
    if (!_didPrefill) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final city  = args['city']  as String?;
        final level = args['river_level'];
        if (city  != null) _stateCtrl.text     = city;
        if (level != null) _peakLevelCtrl.text = level.toString();
      }
      _didPrefill = true;
    }
  }

  @override
  void dispose() {
    _resultAnim.dispose();
    _stateCtrl.dispose();
    _peakLevelCtrl.dispose();
    _rainfallCtrl.dispose();
    _dischargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _result = null; _error = null; });
    _resultAnim.reset();

    final payload = {
      'state':          _stateCtrl.text.trim(),
      'peak_level_m':   double.parse(_peakLevelCtrl.text.trim()),
      'rainfall_7d_mm': double.parse(_rainfallCtrl.text.trim()),
      'discharge_m3s':  double.tryParse(_dischargeCtrl.text.trim()) ?? 0.0,
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
        final level = (body['risk_level'] ?? body['riskLevel'] ?? 'UNKNOWN')
            .toString()
            .toUpperCase();
        final prob = body['probability'] as double? ??
            (body['confidence'] as num?)?.toDouble();
        setState(() {
          _result = _PredictResult(riskLevel: level, confidence: prob);
        });
        _resultAnim.forward();
      } else {
        setState(() => _error = 'Backend HTTP ${res.statusCode}: ${res.body}');
        _resultAnim.forward();
      }
    } catch (e) {
      setState(() => _error = e.toString());
      _resultAnim.forward();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final s = context.l10n;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Header ──────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(t: t),
            ),

            // ── Form ────────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ─ section label
                      _SectionLabel('Input Parameters', t: t),
                      const SizedBox(height: 10),

                      // ─ State / City
                      _DarkField(
                        ctrl:  _stateCtrl,
                        label: 'State / City',
                        hint:  'e.g. Bihar',
                        icon:  Icons.location_on_rounded,
                        t:     t,
                      ),
                      const SizedBox(height: 12),

                      // ─ Peak level
                      _DarkField(
                        ctrl:    _peakLevelCtrl,
                        label:   'River Level (m)',
                        hint:    'e.g. 12.50',
                        icon:    Icons.water_rounded,
                        numeric: true,
                        t:       t,
                      ),
                      const SizedBox(height: 12),

                      // ─ Rainfall 7d
                      _DarkField(
                        ctrl:    _rainfallCtrl,
                        label:   'Rainfall 7d (mm)',
                        hint:    'e.g. 450',
                        icon:    Icons.grain_rounded,
                        numeric: true,
                        t:       t,
                      ),
                      const SizedBox(height: 12),

                      // ─ Discharge (optional)
                      _DarkField(
                        ctrl:     _dischargeCtrl,
                        label:    'Discharge m³/s (optional)',
                        hint:     'e.g. 8500',
                        icon:     Icons.waves_rounded,
                        numeric:  true,
                        required: false,
                        t:        t,
                      ),
                      const SizedBox(height: 24),

                      // ─ CTA button
                      _GlowButton(
                        loading: _loading,
                        onTap:   _predict,
                        t:       t,
                      ),
                      const SizedBox(height: 20),

                      // ─ Result / Error card
                      if (_result != null || _error != null)
                        FadeTransition(
                          opacity: _resultFade,
                          child: SlideTransition(
                            position: _resultSlide,
                            child: _error != null
                                ? _ErrorCard(message: _error!, t: t)
                                : _ResultCard(result: _result!, t: t),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // ─ Tip box
                      _TipBox(t: t),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final RiverColors t;
  const _Header({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: t.scaffoldBg,
        border: Border(
            bottom:
                BorderSide(color: t.stroke.withValues(alpha: 0.5), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.28), width: 1.5),
            ),
            child:
                Icon(Icons.psychology_rounded, color: t.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [t.accent, t.accent.withValues(alpha: 0.65)],
                ).createShader(b),
                child: Text(
                  'FLOOD PREDICTION',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                'ML model · risk level + confidence',
                style: TextStyle(
                    fontSize: 10,
                    color: t.textSecondary.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final RiverColors t;
  const _SectionLabel(this.text, {required this.t});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: t.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

// Dark-styled text field with leading icon and accent border on focus
class _DarkField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool numeric, required;
  final RiverColors t;

  const _DarkField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.t,
    this.numeric  = false,
    this.required = true,
  });

  @override
  State<_DarkField> createState() => _DarkFieldState();
}

class _DarkFieldState extends State<_DarkField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final borderColor =
        _focused ? t.accent.withValues(alpha: 0.7) : t.stroke;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: _focused ? 1.5 : 1),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.ctrl,
          keyboardType: widget.numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle:
                TextStyle(color: t.textSecondary, fontSize: 12),
            hintStyle:
                TextStyle(color: t.stroke, fontSize: 13),
            prefixIcon:
                Icon(widget.icon, color: t.textSecondary, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          validator: widget.required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ),
    );
  }
}

// Gradient glow button matching DashboardScreen CTA style
class _GlowButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final RiverColors t;
  const _GlowButton({
    required this.loading,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : LinearGradient(
                  colors: [
                    t.accent.withValues(alpha: 0.7),
                    t.accent,
                  ],
                ),
          color: loading ? t.cardBgElevated : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: t.accentGlow,
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: t.accent),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 9),
                    const Text(
                      'Run Prediction',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Result card ────────────────────────────────────────────────────────────────────────

class _PredictResult {
  final String  riskLevel;
  final double? confidence;
  const _PredictResult({required this.riskLevel, this.confidence});
}

Color _riskColor(String r) {
  switch (r) {
    case 'CRITICAL': return AppPalette.critical;
    case 'HIGH':
    case 'SEVERE':   return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}

IconData _riskIcon(String r) {
  switch (r) {
    case 'CRITICAL': return Icons.crisis_alert_rounded;
    case 'HIGH':
    case 'SEVERE':   return Icons.warning_rounded;
    case 'MODERATE': return Icons.warning_amber_rounded;
    default:         return Icons.check_circle_rounded;
  }
}

class _ResultCard extends StatelessWidget {
  final _PredictResult result;
  final RiverColors t;
  const _ResultCard({required this.result, required this.t});

  @override
  Widget build(BuildContext context) {
    final col  = _riskColor(result.riskLevel);
    final ico  = _riskIcon(result.riskLevel);
    final pct  = ((result.confidence ?? 0) * 100).clamp(0.0, 100.0);
    final hasCf = result.confidence != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: col.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: col.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // ─ Risk level row
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: col.withValues(alpha: 0.25),
                        blurRadius: 14),
                  ],
                ),
                child: Icon(ico, color: col, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FLOOD RISK',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.riskLevel,
                      style: TextStyle(
                        color: col,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence ring (if available)
              if (hasCf)
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(54, 54),
                        painter: _RingPainter(
                            value: pct / 100, color: col),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: col,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (hasCf) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: col.withValues(alpha: 0.20)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: t.textSecondary, size: 12),
                const SizedBox(width: 6),
                Text(
                  'Model confidence: ${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Circular arc confidence ring painter
class _RingPainter extends CustomPainter {
  final double value; // 0.0 – 1.0
  final Color  color;
  const _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = (size.width  - 6) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2,
        false,
        Paint()
          ..color       = color.withValues(alpha: 0.15)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 4);
    // Arc
    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2 * value,
        false,
        Paint()
          ..color       = color
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap   = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

// ── Error card ──────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String    message;
  final RiverColors t;
  const _ErrorCard({required this.message, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.critical.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppPalette.critical.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppPalette.critical, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tip box ─────────────────────────────────────────────────────────────────────────────

class _TipBox extends StatelessWidget {
  final RiverColors t;
  const _TipBox({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              color: AppPalette.amber, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tip: Navigate from a City Detail screen to '
              'auto-fill the river level and city name.',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
