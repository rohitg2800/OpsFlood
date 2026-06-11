// lib/screens/predict_screen.dart
// OpsFlood — PredictScreen v5  (live data table after prediction)
//
// New in v5:
//   • After "Run Prediction" completes, a _LiveDataTable card appears below
//     the result card, pulling the matched FloodData from liveLevelsProvider.
//   • Shows: River Level, Warning, Danger, Capacity %, Rainfall 24h,
//     Flow Rate, Risk Level, Status, Last Updated.
//   • Row values are colour-coded by danger proximity.
//   • Table auto-scrolls into view via a scroll controller.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../l10n/context_l10n.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});
  static const String route = '/predict';

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _scrollCtrl   = ScrollController();

  final _cityCtrl      = TextEditingController();
  final _peakLevelCtrl = TextEditingController();
  final _rainfallCtrl  = TextEditingController();
  final _dischargeCtrl = TextEditingController();

  bool _loading      = false;
  bool _autoFilled   = false;
  bool _didPrefill   = false;
  bool _didAutoFetch = false;

  _PredictResult? _result;
  String?         _error;
  FloodData?      _liveData;   // populated from liveLevelsProvider on predict

  late final AnimationController _resultAnim;
  late final Animation<double>   _resultFade;
  late final Animation<Offset>   _resultSlide;

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
    if (_didPrefill) return;
    _didPrefill = true;

    String? argCity;
    double? argLevel;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      argCity  = args['city']  as String?;
      final lv = args['river_level'];
      if (lv != null) argLevel = double.tryParse(lv.toString());
    }

    final providerCity = ref.read(selectedCityProvider);
    final city = argCity ?? providerCity;

    if (city != null && city.isNotEmpty) {
      _fillFromCity(city, overrideLevel: argLevel);
    }
  }

  static FloodData _emptyFloodData(String city) => FloodData(
    city:                city,
    district:            '',
    state:               '',
    riverName:           '',
    currentLevel:        0.0,
    warningLevel:        0.0,
    dangerLevel:         0.0,
    safeLevel:           0.0,
    capacityPercent:     0.0,
    riskLevel:           'UNKNOWN',
    status:              'UNKNOWN',
    effectiveRainfallMm: 0.0,
    lastUpdated:         DateTime.now(),
  );

  FloodData _matchCity(String city) {
    final liveList = ref.read(liveLevelsProvider);
    return liveList.firstWhere(
      (d) => d.city.toLowerCase() == city.toLowerCase(),
      orElse: () => liveList.firstWhere(
        (d) => d.city.toLowerCase().contains(city.toLowerCase()),
        orElse: () => _emptyFloodData(city),
      ),
    );
  }

  void _fillFromCity(String city, {double? overrideLevel}) {
    final match    = _matchCity(city);
    final level    = overrideLevel ?? match.currentLevel;
    final rainfall = match.effectiveRainfallMm > 0
        ? (match.effectiveRainfallMm * 7).toStringAsFixed(1)
        : '';

    setState(() {
      _cityCtrl.text      = city;
      _peakLevelCtrl.text = level > 0 ? level.toStringAsFixed(2) : '';
      _rainfallCtrl.text  = rainfall;
      _dischargeCtrl.text =
          match.flowRate != null ? match.flowRate!.toStringAsFixed(0) : '';
      _autoFilled = level > 0;
    });

    if (!_didAutoFetch && level > 0) {
      _didAutoFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _predict();
      });
    }
  }

  @override
  void dispose() {
    _resultAnim.dispose();
    _scrollCtrl.dispose();
    _cityCtrl.dispose();
    _peakLevelCtrl.dispose();
    _rainfallCtrl.dispose();
    _dischargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    // Snapshot live data for the table BEFORE the API call
    final city = _cityCtrl.text.trim();
    final live = city.isNotEmpty ? _matchCity(city) : null;

    setState(() {
      _loading  = true;
      _result   = null;
      _error    = null;
      _liveData = live?.currentLevel != null && live!.currentLevel > 0
          ? live
          : null;
    });
    _resultAnim.reset();

    final payload = {
      'state':          city,
      'peak_level_m':   double.tryParse(_peakLevelCtrl.text.trim()) ?? 0.0,
      'rainfall_7d_mm': double.tryParse(_rainfallCtrl.text.trim())  ?? 0.0,
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
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final level = (body['risk_level'] ?? body['riskLevel'] ?? 'UNKNOWN')
            .toString().toUpperCase();
        final prob  = body['probability'] as double? ??
            (body['confidence'] as num?)?.toDouble();
        setState(() {
          _result = _PredictResult(riskLevel: level, confidence: prob);
        });
      } else {
        setState(() => _error = 'Backend HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _resultAnim.forward();
        // Scroll down so table is visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          slivers: [

            SliverToBoxAdapter(child: _Header(t: t)),

            if (_loading && _autoFilled)
              SliverToBoxAdapter(
                child: _AutoFetchBanner(t: t, city: _cityCtrl.text),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _SectionLabel('Input Parameters', t: t),
                      const SizedBox(height: 10),

                      _CityField(
                        ctrl:       _cityCtrl,
                        autoFilled: _autoFilled,
                        t:          t,
                        onClear:    () => setState(() {
                          _autoFilled   = false;
                          _didAutoFetch = false;
                          _cityCtrl.clear();
                          _peakLevelCtrl.clear();
                          _rainfallCtrl.clear();
                          _dischargeCtrl.clear();
                          _result   = null;
                          _error    = null;
                          _liveData = null;
                        }),
                      ),
                      const SizedBox(height: 12),

                      _DarkField(
                        ctrl: _peakLevelCtrl, label: 'River Level (m)',
                        hint: 'e.g. 12.50', icon: Icons.water_rounded,
                        numeric: true, t: t,
                      ),
                      const SizedBox(height: 12),

                      _DarkField(
                        ctrl: _rainfallCtrl, label: 'Rainfall 7d (mm)',
                        hint: 'e.g. 450', icon: Icons.grain_rounded,
                        numeric: true, t: t,
                      ),
                      const SizedBox(height: 12),

                      _DarkField(
                        ctrl: _dischargeCtrl,
                        label: 'Discharge m³/s (optional)',
                        hint: 'e.g. 8500', icon: Icons.waves_rounded,
                        numeric: true, required: false, t: t,
                      ),
                      const SizedBox(height: 24),

                      _GlowButton(loading: _loading, onTap: _predict, t: t),
                      const SizedBox(height: 20),

                      // ─ ML Result / Error card
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

                      // ─ Live station data table (shown after any prediction)
                      if ((_result != null || _error != null) &&
                          _liveData != null) ...[
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _resultFade,
                          child: _LiveDataTable(data: _liveData!, t: t),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _TipBox(t: t, autoFilled: _autoFilled),
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
// _LiveDataTable — live station data card with key/value rows
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDataTable extends StatelessWidget {
  final FloodData   data;
  final RiverColors t;
  const _LiveDataTable({required this.data, required this.t});

  @override
  Widget build(BuildContext context) {
    final riskCol = data.priorityColor;

    // Colour-code the river level relative to thresholds
    Color levelColor() {
      if (data.dangerLevel > 0 && data.currentLevel >= data.dangerLevel)
        return AppPalette.critical;
      if (data.warningLevel > 0 && data.currentLevel >= data.warningLevel)
        return AppPalette.warning;
      return AppPalette.safe;
    }

    final lvlCol = levelColor();

    final rows = [
      _Row('River',          data.riverName ?? '—',                null),
      _Row('District',       data.district.isNotEmpty ? data.district : '—', null),
      _Row('State',          data.state.isNotEmpty ? data.state : '—',       null),
      _Row('Current Level',  '${data.currentLevel.toStringAsFixed(2)} m',   lvlCol),
      _Row('Warning Level',  '${data.warningLevel.toStringAsFixed(2)} m',   AppPalette.warning),
      _Row('Danger Level',   '${data.dangerLevel.toStringAsFixed(2)} m',    AppPalette.danger),
      _Row('Capacity',       '${data.capacityPercent.toStringAsFixed(1)} %',
          data.capacityPercent >= 90
              ? AppPalette.critical
              : data.capacityPercent >= 70
                  ? AppPalette.warning
                  : AppPalette.safe),
      _Row('Rainfall 24h',
          data.effectiveRainfallMm > 0
              ? '${data.effectiveRainfallMm.toStringAsFixed(1)} mm'
              : '—',
          null),
      if (data.flowRate != null)
        _Row('Flow Rate',
            '${data.flowRate!.toStringAsFixed(0)} m³/s', null),
      _Row('IMD Severity',   data.imdSeverity ?? '—',               null),
      _Row('Risk Level',     data.riskLevel,                        riskCol),
      _Row('Status',         data.status,                           null),
      _Row('Last Updated',
          '${data.lastUpdated.day.toString().padLeft(2,'0')}/'  
          '${data.lastUpdated.month.toString().padLeft(2,'0')}/'  
          '${data.lastUpdated.year}  '
          '${data.lastUpdated.hour.toString().padLeft(2,'0')}:'  
          '${data.lastUpdated.minute.toString().padLeft(2,'0')}',
          null),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
              color: t.accent.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Header row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                  bottom: BorderSide(
                      color: t.stroke.withValues(alpha: 0.5), width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sensors_rounded,
                      color: t.accent, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE STATION DATA',
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8),
                    ),
                    Text(
                      data.city,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                // Live pulse dot
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: AppPalette.safe,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppPalette.safe.withValues(alpha: 0.5),
                          blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text('LIVE',
                    style: TextStyle(
                        color: AppPalette.safe,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),

          // ─ Data rows
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            final row    = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: e.key.isEven
                    ? Colors.transparent
                    : t.cardBgElevated.withValues(alpha: 0.4),
                borderRadius: isLast
                    ? const BorderRadius.vertical(
                        bottom: Radius.circular(18))
                    : null,
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                            color: t.stroke.withValues(alpha: 0.25),
                            width: 0.5)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      row.label,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: row.valueColor ?? t.textPrimary,
                        fontSize: 12,
                        fontWeight: row.valueColor != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(this.label, this.value, this.valueColor);
}

// ─────────────────────────────────────────────────────────────────────────────
// _AutoFetchBanner
// ─────────────────────────────────────────────────────────────────────────────

class _AutoFetchBanner extends StatelessWidget {
  final RiverColors t;
  final String city;
  const _AutoFetchBanner({required this.t, required this.city});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: t.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Auto-fetching prediction for $city…',
              style: TextStyle(
                  color: t.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CityField
// ─────────────────────────────────────────────────────────────────────────────

class _CityField extends StatefulWidget {
  final TextEditingController ctrl;
  final bool autoFilled;
  final RiverColors t;
  final VoidCallback onClear;
  const _CityField({
    required this.ctrl,
    required this.autoFilled,
    required this.t,
    required this.onClear,
  });

  @override
  State<_CityField> createState() => _CityFieldState();
}

class _CityFieldState extends State<_CityField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final borderColor = widget.autoFilled
        ? t.accent.withValues(alpha: 0.55)
        : _focused ? t.accent.withValues(alpha: 0.7) : t.stroke;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: borderColor,
            width: (widget.autoFilled || _focused) ? 1.5 : 1),
        boxShadow: widget.autoFilled
            ? [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextFormField(
          controller: widget.ctrl,
          readOnly: widget.autoFilled,
          style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
          decoration: InputDecoration(
            labelText: 'City / Station',
            hintText: 'e.g. Patna',
            labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
            hintStyle:  TextStyle(color: t.stroke,        fontSize: 13),
            prefixIcon:
                Icon(Icons.location_on_rounded, color: t.textSecondary, size: 18),
            suffixIcon: widget.autoFilled
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: t.accent.withValues(alpha: 0.40)),
                        ),
                        child: Text('LIVE',
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8)),
                      ),
                      GestureDetector(
                        onTap: widget.onClear,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(Icons.close,
                              color: t.textSecondary, size: 16),
                        ),
                      ),
                    ],
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Header
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
            bottom: BorderSide(
                color: t.stroke.withValues(alpha: 0.5), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: t.accent.withValues(alpha: 0.10),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.28), width: 1.5),
            ),
            child: Icon(Icons.psychology_rounded, color: t.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [t.accent, t.accent.withValues(alpha: 0.65)],
                ).createShader(b),
                child: const Text(
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
    final t           = widget.t;
    final borderColor = _focused ? t.accent.withValues(alpha: 0.7) : t.stroke;

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
            hintText:  widget.hint,
            labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
            hintStyle:  TextStyle(color: t.stroke,        fontSize: 13),
            prefixIcon:
                Icon(widget.icon, color: t.textSecondary, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          validator: widget.required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ),
    );
  }
}

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
                  width: 20, height: 20,
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

// ── Result model ──

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
    final col   = _riskColor(result.riskLevel);
    final ico   = _riskIcon(result.riskLevel);
    final pct   = ((result.confidence ?? 0) * 100).clamp(0.0, 100.0);
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
              if (hasCf)
                SizedBox(
                  width: 54, height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(54, 54),
                        painter: _RingPainter(value: pct / 100, color: col),
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

class _RingPainter extends CustomPainter {
  final double value;
  final Color  color;
  const _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = (size.width - 6) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false,
        Paint()
          ..color       = color.withValues(alpha: 0.15)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false,
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
                  color: t.textPrimary, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  final RiverColors t;
  final bool autoFilled;
  const _TipBox({required this.t, required this.autoFilled});

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
              autoFilled
                  ? 'Fields auto-filled from live station data. '
                    'Tap × on the city field to switch to a different city.'
                  : 'Tip: Tap a city on the Dashboard to auto-fill all '
                    'fields and run the prediction instantly.',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
