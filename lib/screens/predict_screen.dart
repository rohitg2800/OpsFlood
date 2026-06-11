// lib/screens/predict_screen.dart
// OpsFlood — PredictScreen v7
//
// Full data-wiring fix:
//   • didChangeDependencies prefill now DEFERRED: waits until
//     mergedStationsProvider is non-empty (addPostFrameCallback loop).
//   • _findStations uses ref.read (snapshot) at predict-time, always safe
//     because the build() already ref.watch()es mergedStationsProvider.
//   • Rainfall pre-fill now uses FloodData.effectiveRainfallMm from
//     liveLevelsProvider (city match), falling back to station.rainfallLastHour.
//   • flowRate pre-fill uses RiverStation.flowRate || FloodData.flowRate.
//   • Table shows ALL available RiverStation + FloodData fields per station:
//     district, imdSeverity, imdRainfallMm, effectiveRainfallMm, flowRate,
//     trend, liveStatus, capacityPercent.
//   • No more blank table: stations are always re-searched at _predict() time
//     after data is confirmed loaded.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../providers/flood_providers.dart';
import '../providers/real_time_river_provider.dart';
import '../theme/river_theme.dart';

// ─── combined payload passed to the table ────────────────────────────────────
class _StationPayload {
  final RiverStation rs;
  final FloodData?   fd; // nullable: matched FloodData from liveLevelsProvider
  const _StationPayload(this.rs, this.fd);
}

class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});
  static const String route = '/predict';

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen>
    with SingleTickerProviderStateMixin {
  final _formKey    = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  final _cityCtrl      = TextEditingController();
  final _peakLevelCtrl = TextEditingController();
  final _rainfallCtrl  = TextEditingController();
  final _dischargeCtrl = TextEditingController();

  bool _loading      = false;
  bool _autoFilled   = false;
  bool _didPrefill   = false;
  bool _didAutoFetch = false;

  _PredictResult?        _result;
  String?                _error;
  List<_StationPayload>? _payloads; // table data

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
    _schedulePrefill();
  }

  /// Deferred prefill: keeps re-scheduling until stations are loaded.
  void _schedulePrefill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stations = ref.read(mergedStationsProvider);
      if (stations.isEmpty) {
        // Data not ready yet — try again next frame
        _schedulePrefill();
        return;
      }
      _doPrefill();
    });
  }

  void _doPrefill() {
    String? argCity;
    double? argLevel;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      argCity  = args['city']  as String?;
      final lv = args['river_level'];
      if (lv != null) argLevel = double.tryParse(lv.toString());
    }
    final city = argCity ?? ref.read(selectedCityProvider);
    if (city != null && city.isNotEmpty) {
      _fillFromCity(city, overrideLevel: argLevel);
    }
  }

  // ── 5-tier fuzzy match ───────────────────────────────────────────────
  List<RiverStation> _findStations(String query) {
    if (query.trim().isEmpty) return [];
    final q   = query.toLowerCase().trim();
    final all = ref.read(mergedStationsProvider);

    List<RiverStation> hits;

    // 1. exact station name contains query
    hits = all.where((s) => s.station.toLowerCase().contains(q)).toList();
    if (hits.isNotEmpty) return hits;

    // 2. city field contains query
    hits = all.where((s) => s.city.toLowerCase().contains(q)).toList();
    if (hits.isNotEmpty) return hits;

    // 3. river name contains query
    hits = all.where((s) => s.river.toLowerCase().contains(q)).toList();
    if (hits.isNotEmpty) return hits;

    // 4. any word-token (≥3 chars) appears in station or city
    final tokens = q.split(RegExp(r'\s+'))
        .where((t) => t.length >= 3).toList();
    hits = all.where((s) {
      final low = '${s.station} ${s.city}'.toLowerCase();
      return tokens.any((t) => low.contains(t));
    }).toList();
    if (hits.isNotEmpty) return hits;

    // 5. FloodData city fallback
    final fdList = ref.read(liveLevelsProvider);
    final fdHits = fdList.where((d) => d.city.toLowerCase().contains(q));
    hits = fdHits.expand((d) {
      final match = all.where(
          (s) => s.station.toLowerCase() == d.city.toLowerCase());
      if (match.isNotEmpty) return match;
      // Build a synthetic RiverStation from FloodData
      return [
        RiverStation(
          city:             d.city,
          state:            d.state,
          river:            d.riverName ?? '',
          station:          d.city,
          current:          d.currentLevel,
          warning:          d.warningLevel,
          danger:           d.dangerLevel,
          hfl:              d.dangerLevel + 1.5,
          flowRate:         d.flowRate,
          dataSource:       d.status,
          lastUpdated:
              '${d.lastUpdated.hour.toString().padLeft(2,'0')}:'
              '${d.lastUpdated.minute.toString().padLeft(2,'0')}',
          isLive:           d.status == 'LIVE',
        ),
      ];
    }).toList();
    return hits;
  }

  /// Build combined payloads (RiverStation + matched FloodData) for the table.
  List<_StationPayload> _buildPayloads(List<RiverStation> stations) {
    final fdList = ref.read(liveLevelsProvider);
    return stations.map((rs) {
      final fd = fdList.firstWhereOrNull(
          (d) => d.city.toLowerCase() == rs.station.toLowerCase() ||
                 d.city.toLowerCase() == rs.city.toLowerCase());
      return _StationPayload(rs, fd);
    }).toList();
  }

  // ── Pre-fill form fields from best matched station ───────────────────────
  void _fillFromCity(String city, {double? overrideLevel}) {
    final stations = _findStations(city);
    final first    = stations.isNotEmpty ? stations.first : null;

    final level = overrideLevel ?? first?.current ?? 0.0;

    // Rainfall: prefer FloodData.effectiveRainfallMm, then rainfallLastHour
    double? rainfallVal;
    if (first != null) {
      final fdList = ref.read(liveLevelsProvider);
      final fd = fdList.firstWhereOrNull(
          (d) => d.city.toLowerCase() == first.station.toLowerCase() ||
                 d.city.toLowerCase() == first.city.toLowerCase());
      rainfallVal = (fd?.effectiveRainfallMm ?? 0) > 0
          ? fd!.effectiveRainfallMm
          : ((first.rainfallLastHour ?? 0) > 0
              ? first.rainfallLastHour
              : null);
    }

    // Flow rate
    double? flowVal;
    if (first != null) {
      flowVal = (first.flowRate ?? 0) > 0 ? first.flowRate : null;
      if (flowVal == null) {
        final fdList = ref.read(liveLevelsProvider);
        final fd = fdList.firstWhereOrNull(
            (d) => d.city.toLowerCase() == first.station.toLowerCase() ||
                   d.city.toLowerCase() == first.city.toLowerCase());
        if ((fd?.flowRate ?? 0) > 0) flowVal = fd!.flowRate;
      }
    }

    setState(() {
      _cityCtrl.text      = city;
      _peakLevelCtrl.text = level > 0 ? level.toStringAsFixed(2) : '';
      _rainfallCtrl.text  =
          rainfallVal != null ? rainfallVal.toStringAsFixed(1) : '';
      _dischargeCtrl.text =
          flowVal != null ? flowVal.toStringAsFixed(0) : '';
      _autoFilled         = level > 0;
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

  // ── Predict ─────────────────────────────────────────────────────────
  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final city     = _cityCtrl.text.trim();
    final stations = _findStations(city);
    final payloads = _buildPayloads(stations);

    setState(() {
      _loading  = true;
      _result   = null;
      _error    = null;
      _payloads = payloads.isNotEmpty ? payloads : null;
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
        final prob = body['probability'] as double? ??
            (body['confidence'] as num?)?.toDouble();
        setState(() {
          _result = _PredictResult(riskLevel: level, confidence: prob);
        });
      } else {
        setState(() =>
            _error = 'Backend HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _resultAnim.forward();
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

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    // Watch so widget rebuilds when live data arrives → table refreshes
    ref.watch(mergedStationsProvider);
    ref.watch(liveLevelsProvider);

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
                        onClear: () => setState(() {
                          _autoFilled   = false;
                          _didAutoFetch = false;
                          _cityCtrl.clear();
                          _peakLevelCtrl.clear();
                          _rainfallCtrl.clear();
                          _dischargeCtrl.clear();
                          _result   = null;
                          _error    = null;
                          _payloads = null;
                        }),
                      ),
                      const SizedBox(height: 12),

                      _DarkField(
                        ctrl: _peakLevelCtrl,
                        label: 'River Level (m)',
                        hint: 'e.g. 12.50',
                        icon: Icons.water_rounded,
                        numeric: true, t: t,
                      ),
                      const SizedBox(height: 12),

                      _DarkField(
                        ctrl: _rainfallCtrl,
                        label: 'Rainfall 7d (mm)',
                        hint: 'e.g. 450',
                        icon: Icons.grain_rounded,
                        numeric: true, t: t,
                      ),
                      const SizedBox(height: 12),

                      _DarkField(
                        ctrl: _dischargeCtrl,
                        label: 'Discharge m³/s (optional)',
                        hint: 'e.g. 8500',
                        icon: Icons.waves_rounded,
                        numeric: true, required: false, t: t,
                      ),
                      const SizedBox(height: 24),

                      _GlowButton(
                          loading: _loading, onTap: _predict, t: t),
                      const SizedBox(height: 20),

                      // ML result / error
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

                      // Live station table
                      if ((_result != null || _error != null) &&
                          _payloads != null &&
                          _payloads!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _resultFade,
                          child: _LiveStationTable(
                              payloads: _payloads!, t: t),
                        ),
                      ],

                      // No-match notice
                      if ((_result != null || _error != null) &&
                          (_payloads == null || _payloads!.isEmpty) &&
                          _cityCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _resultFade,
                          child: _NoStationNotice(
                              city: _cityCtrl.text.trim(), t: t),
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
// _LiveStationTable
// ─────────────────────────────────────────────────────────────────────────────

class _LiveStationTable extends StatelessWidget {
  final List<_StationPayload> payloads;
  final RiverColors t;
  const _LiveStationTable({required this.payloads, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.sensors_rounded, color: t.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                'LIVE STATION DATA  •  '
                '${payloads.length} GAUGE'
                '${payloads.length > 1 ? "S" : ""} MATCHED',
                style: TextStyle(
                    color: t.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6),
              ),
            ],
          ),
        ),
        ...payloads.map((p) => _StationCard(payload: p, t: t)),
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  final _StationPayload payload;
  final RiverColors     t;
  const _StationCard({required this.payload, required this.t});

  @override
  Widget build(BuildContext context) {
    final s  = payload.rs;
    final fd = payload.fd;

    Color levelColor() {
      if (s.danger > 0 && s.current >= s.danger)   return AppPalette.critical;
      if (s.warning > 0 && s.current >= s.warning) return AppPalette.warning;
      return AppPalette.safe;
    }
    Color capColor(double pct) {
      if (pct >= 100) return AppPalette.critical;
      if (pct >= 80)  return AppPalette.warning;
      return AppPalette.safe;
    }

    final dangerClassColor = s.dangerClass == DangerClass.extreme
        ? AppPalette.critical
        : s.dangerClass == DangerClass.severe
            ? AppPalette.danger
            : s.dangerClass == DangerClass.aboveNormal
                ? AppPalette.warning
                : AppPalette.safe;

    final capacityPct = s.danger > 0
        ? (s.current / s.danger * 100).clamp(0.0, 200.0)
        : (fd?.capacityPercent ?? 0.0);

    // Rainfall: prefer FloodData effective, else imd, else rainfallLastHour
    final rainfall = (fd?.effectiveRainfallMm ?? 0) > 0
        ? fd!.effectiveRainfallMm
        : (fd?.imdRainfallMm ?? 0) > 0
            ? fd!.imdRainfallMm!
            : (s.rainfallLastHour ?? 0) > 0
                ? s.rainfallLastHour!
                : null;

    // Flow rate: prefer FloodData.flowRate, else RiverStation.flowRate
    final flow = (fd?.flowRate ?? 0) > 0
        ? fd!.flowRate!
        : (s.flowRate ?? 0) > 0
            ? s.flowRate!
            : null;

    // Build row list
    final rows = <_Row>[
      _Row('River',         s.river.isNotEmpty ? s.river : (fd?.riverName ?? '—'), null),
      if (fd?.district != null && fd!.district.isNotEmpty)
        _Row('District',    fd.district, null),
      _Row('State',         s.state.isNotEmpty ? s.state : (fd?.state ?? '—'), null),
      _Row('Current Level', '${s.current.toStringAsFixed(2)} m', levelColor()),
      _Row('Warning Level', s.warning > 0
          ? '${s.warning.toStringAsFixed(2)} m' : '—', AppPalette.warning),
      _Row('Danger Level',  s.danger > 0
          ? '${s.danger.toStringAsFixed(2)} m'  : '—', AppPalette.danger),
      _Row('HFL',           s.hfl > 0
          ? '${s.hfl.toStringAsFixed(2)} m'     : '—', null),
      _Row('Capacity',      capacityPct > 0
          ? '${capacityPct.toStringAsFixed(1)} %' : '—',
          capacityPct > 0 ? capColor(capacityPct) : null),
      if (rainfall != null)
        _Row('Rainfall',    '${rainfall.toStringAsFixed(1)} mm', null),
      if (flow != null)
        _Row('Flow Rate',   '${flow.toStringAsFixed(0)} m³/s',  null),
      if (s.trend != null && s.trend!.isNotEmpty)
        _Row('Trend',       s.trend!.toUpperCase(), null),
      if (fd?.imdSeverity != null && fd!.imdSeverity!.isNotEmpty)
        _Row('IMD Severity', fd.imdSeverity!, null),
      _Row('Risk Level',    fd?.riskLevel ?? s.riskLabel, dangerClassColor),
      _Row('Status',        s.liveStatus ?? fd?.status ?? s.dangerClass.name.toUpperCase(),
          dangerClassColor),
      _Row('Data Source',   s.dataSource ?? fd?.status ?? '—', null),
      _Row('Last Updated',  s.lastUpdated?.isNotEmpty == true
          ? s.lastUpdated! : '—', null),
      _Row('Live',          s.isLive ? 'YES' : 'ESTIMATED',
          s.isLive ? AppPalette.safe : AppPalette.warning),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
              color: dangerClassColor.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: dangerClassColor.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: t.stroke.withValues(alpha: 0.4),
                      width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: dangerClassColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.water_rounded,
                      color: dangerClassColor, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.station,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      if (s.city.isNotEmpty && s.city != s.station)
                        Text(s.city,
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 10)),
                    ],
                  ),
                ),
                // LIVE / EST badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        (s.isLive ? AppPalette.safe : AppPalette.warning)
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color:
                            (s.isLive
                                    ? AppPalette.safe
                                    : AppPalette.warning)
                                .withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    s.isLive ? 'LIVE' : 'EST',
                    style: TextStyle(
                        color: s.isLive
                            ? AppPalette.safe
                            : AppPalette.warning,
                        fontSize: 8,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          if (s.danger > 0 || capacityPct > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Text('0',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 9)),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              (capacityPct / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              t.stroke.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation(
                              levelColor()),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    s.danger > 0
                        ? '${s.danger.toStringAsFixed(1)} m'
                        : '100 %',
                    style: TextStyle(
                        color: AppPalette.danger, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],

          // Data rows
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            final row    = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: e.key.isEven
                    ? Colors.transparent
                    : t.cardBgElevated.withValues(alpha: 0.35),
                borderRadius: isLast
                    ? const BorderRadius.vertical(
                        bottom: Radius.circular(16))
                    : null,
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                            color: t.stroke.withValues(alpha: 0.20),
                            width: 0.5)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      row.label,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: row.valueColor ?? t.textPrimary,
                        fontSize: 11,
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

// ── No-station notice ──

class _NoStationNotice extends StatelessWidget {
  final String city;
  final RiverColors t;
  const _NoStationNotice({required this.city, required this.t});

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
        children: [
          Icon(Icons.info_outline_rounded,
              color: t.textSecondary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No live gauge found for “$city”. '
              'Live data table will appear once a matching station is loaded.',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI helpers
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
        : _focused
            ? t.accent.withValues(alpha: 0.7)
            : t.stroke;

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
            labelStyle:
                TextStyle(color: t.textSecondary, fontSize: 12),
            hintStyle: TextStyle(color: t.stroke, fontSize: 13),
            prefixIcon: Icon(Icons.location_on_rounded,
                color: t.textSecondary, size: 18),
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
                              color:
                                  t.accent.withValues(alpha: 0.40)),
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
    final borderColor =
        _focused ? t.accent.withValues(alpha: 0.7) : t.stroke;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: borderColor, width: _focused ? 1.5 : 1),
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
            labelStyle:
                TextStyle(color: t.textSecondary, fontSize: 12),
            hintStyle: TextStyle(color: t.stroke, fontSize: 13),
            prefixIcon: Icon(widget.icon,
                color: t.textSecondary, size: 18),
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

class _RingPainter extends CustomPainter {
  final double value;
  final Color  color;
  const _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = (size.width - 6) / 2;
    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: r);
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
                    'Tap × to switch to a different city.'
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

// ── Iterable extension ──
extension _IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
