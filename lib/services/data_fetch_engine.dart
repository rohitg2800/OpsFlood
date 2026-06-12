// lib/services/data_fetch_engine.dart  v4.1
//
// v4.1: _deriveRisk() replaced with gaugeRiskFromLevels() from bihar_rivers.dart
//       so DataFetchEngine, RiverStation.dangerClass, and the map all use the
//       same four-tier severity computation (EXTREME/CRITICAL/DANGER/NORMAL).
//       The old warn*0.85 pre-warning bucket is removed.
//
// v4.0: backend-bidirectional push via BackendSyncService.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/bihar_rivers.dart';
import '../models/river_station.dart';
import 'backend_api_service.dart';
import 'backend_sync_service.dart';
import 'wrd_bihar_service.dart';
import 'fcm_broadcast_service.dart';

// ───────────────────────────────────────────────────────────────────────────────
class StationReading {
  final String  stationName;
  final String  river;
  final String  district;
  final String  state;
  final double  lat;
  final double  lon;
  final double  currentLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final double  hfl;
  final double  progressPct;
  final String  riskLabel;
  final String  source;
  final bool    isLive;
  final DateTime fetchedAt;
  final double? flowRateCumecs;
  final double? rainfall24hMm;
  final double? forecastLevel24h;
  final double? forecastLevel48h;
  final double? forecastLevel72h;
  final double? rateOfRiseMph;

  const StationReading({
    required this.stationName,
    required this.river,
    required this.district,
    required this.state,
    required this.lat,
    required this.lon,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    required this.progressPct,
    required this.riskLabel,
    required this.source,
    required this.isLive,
    required this.fetchedAt,
    this.flowRateCumecs,
    this.rainfall24hMm,
    this.forecastLevel24h,
    this.forecastLevel48h,
    this.forecastLevel72h,
    this.rateOfRiseMph,
  });

  bool get isAboveWarning => currentLevel >= warningLevel;
  bool get isAboveDanger  => currentLevel >= dangerLevel;
  bool get isAboveHfl     => currentLevel >= hfl;

  StationReading copyWith({
    double? currentLevel,
    double? flowRateCumecs,
    double? rainfall24hMm,
    double? forecastLevel24h,
    double? forecastLevel48h,
    double? forecastLevel72h,
    double? rateOfRiseMph,
    String? riskLabel,
    String? source,
    bool?   isLive,
    DateTime? fetchedAt,
  }) {
    final cl   = currentLevel ?? this.currentLevel;
    final dng  = this.dangerLevel;
    final prog = dng > 0 ? (cl / dng * 100).clamp(0.0, 200.0) : 0.0;
    return StationReading(
      stationName:      this.stationName,
      river:            this.river,
      district:         this.district,
      state:            this.state,
      lat:              this.lat,
      lon:              this.lon,
      currentLevel:     cl,
      warningLevel:     this.warningLevel,
      dangerLevel:      dng,
      hfl:              this.hfl,
      progressPct:      prog,
      // Always re-derive from shared fn so riskLabel stays canonical
      riskLabel:        riskLabel ?? _deriveRisk(cl, this.warningLevel, dng, this.hfl),
      source:           source    ?? this.source,
      isLive:           isLive    ?? this.isLive,
      fetchedAt:        fetchedAt ?? this.fetchedAt,
      flowRateCumecs:   flowRateCumecs   ?? this.flowRateCumecs,
      rainfall24hMm:    rainfall24hMm    ?? this.rainfall24hMm,
      forecastLevel24h: forecastLevel24h ?? this.forecastLevel24h,
      forecastLevel48h: forecastLevel48h ?? this.forecastLevel48h,
      forecastLevel72h: forecastLevel72h ?? this.forecastLevel72h,
      rateOfRiseMph:    rateOfRiseMph    ?? this.rateOfRiseMph,
    );
  }

  RiverStation toRiverStation() => RiverStation(
    city:       district.isNotEmpty ? district : stationName,
    state:      state,
    river:      river,
    station:    stationName,
    current:    currentLevel,
    warning:    warningLevel,
    danger:     dangerLevel,
    hfl:        hfl,
    isLive:     isLive,
    dataSource: source,
  );

  /// Single canonical severity derivation — delegates to gaugeRiskFromLevels()
  /// in bihar_rivers.dart.  Used by DataFetchEngine, map, and alert controller.
  static String _deriveRisk(double cur, double warn, double dng, double hfl) =>
      gaugeRiskFromLevels(
        current: cur,
        warning: warn,
        danger:  dng,
        hfl:     hfl,
      );

  Map<String, dynamic> toJson() => {
    'n': stationName, 'r': river, 'd': district, 's': state,
    'la': lat, 'lo': lon,
    'cl': currentLevel, 'wl': warningLevel, 'dl': dangerLevel, 'h': hfl,
    'p': progressPct, 'rl': riskLabel, 'src': source, 'lv': isLive,
    'fa': fetchedAt.millisecondsSinceEpoch,
    if (flowRateCumecs   != null) 'fc': flowRateCumecs,
    if (rainfall24hMm    != null) 'rm': rainfall24hMm,
    if (forecastLevel24h != null) 'f1': forecastLevel24h,
    if (forecastLevel48h != null) 'f2': forecastLevel48h,
    if (forecastLevel72h != null) 'f3': forecastLevel72h,
    if (rateOfRiseMph    != null) 'rr': rateOfRiseMph,
  };

  factory StationReading.fromJson(Map<String, dynamic> j) {
    final cl  = (j['cl'] as num).toDouble();
    final wl  = (j['wl'] as num).toDouble();
    final dl  = (j['dl'] as num).toDouble();
    final hfl = (j['h']  as num).toDouble();
    return StationReading(
      stationName:  j['n']  as String,
      river:        j['r']  as String,
      district:     j['d']  as String,
      state:        j['s']  as String,
      lat:          (j['la'] as num).toDouble(),
      lon:          (j['lo'] as num).toDouble(),
      currentLevel: cl, warningLevel: wl, dangerLevel: dl, hfl: hfl,
      progressPct:  dl > 0 ? (cl / dl * 100).clamp(0.0, 200.0) : 0.0,
      riskLabel:    _deriveRisk(cl, wl, dl, hfl),   // re-derive on deserialise
      source:       j['src'] as String,
      isLive:       j['lv'] as bool,
      fetchedAt:    DateTime.fromMillisecondsSinceEpoch(j['fa'] as int),
      flowRateCumecs:   j['fc'] != null ? (j['fc'] as num).toDouble() : null,
      rainfall24hMm:    j['rm'] != null ? (j['rm'] as num).toDouble() : null,
      forecastLevel24h: j['f1'] != null ? (j['f1'] as num).toDouble() : null,
      forecastLevel48h: j['f2'] != null ? (j['f2'] as num).toDouble() : null,
      forecastLevel72h: j['f3'] != null ? (j['f3'] as num).toDouble() : null,
      rateOfRiseMph:    j['rr'] != null ? (j['rr'] as num).toDouble() : null,
    );
  }
}

class SourceStatus {
  final String    name;
  final bool      healthy;
  final int?      latencyMs;
  final int       stationCount;
  final DateTime? lastSuccessAt;
  final String?   errorMessage;
  final bool      isFromSeed;

  const SourceStatus({
    required this.name,
    required this.healthy,
    this.latencyMs,
    this.stationCount = 0,
    this.lastSuccessAt,
    this.errorMessage,
    this.isFromSeed = false,
  });
}

class DataFetchSnapshot {
  final List<StationReading> stations;
  final List<SourceStatus>   sources;
  final DateTime             fetchedAt;
  final bool                 isLoading;
  final String?              error;
  final bool                 fromBroadcast;

  int    get totalStations   => stations.length;
  int    get liveStations    => stations.where((s) => s.isLive).length;
  int    get criticalCount   => stations.where((s) => s.riskLabel == 'CRITICAL').length;
  int    get dangerCount     => stations.where((s) =>
      s.riskLabel == 'CRITICAL' || s.riskLabel == 'DANGER').length;
  int    get warningCount    => stations.where((s) => s.riskLabel == 'DANGER').length;
  double get maxLevel        => stations.isEmpty ? 0
      : stations.map((s) => s.currentLevel).reduce(math.max);
  String get maxLevelStation => stations.isEmpty ? '—'
      : stations.reduce((a, b) =>
          a.currentLevel > b.currentLevel ? a : b).stationName;

  const DataFetchSnapshot({
    required this.stations,
    required this.sources,
    required this.fetchedAt,
    this.isLoading     = false,
    this.error,
    this.fromBroadcast = false,
  });

  static DataFetchSnapshot loading() => DataFetchSnapshot(
    stations: const [], sources: const [],
    fetchedAt: DateTime.now(), isLoading: true,
  );

  String toCompressedJson() => jsonEncode({
    'ts': fetchedAt.millisecondsSinceEpoch,
    'st': stations.map((s) => s.toJson()).toList(),
  });

  static DataFetchSnapshot? fromCompressedJson(String raw) {
    try {
      final j  = jsonDecode(raw) as Map<String, dynamic>;
      final ts = DateTime.fromMillisecondsSinceEpoch(j['ts'] as int);
      final st = (j['st'] as List<dynamic>)
          .map((e) => StationReading.fromJson(e as Map<String, dynamic>))
          .toList();
      return DataFetchSnapshot(
        stations:      st,
        sources:       const [],
        fetchedAt:     ts,
        fromBroadcast: true,
      );
    } catch (e) {
      debugPrint('[DataFetchEngine] FCM parse failed: $e');
      return null;
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._() {
    _last = _buildSeedSnapshot();
  }
  static final instance = DataFetchEngine._();

  static const _baseInterval  = Duration(seconds: 45);
  static const _fcmStaleness  = Duration(minutes: 3);
  static const _maxBackoffMin = Duration(minutes: 5);

  static const _cwcCodes = <String>[
    'KOSI-BIRPUR', 'KOSI-BASUA', 'KOSI-KURSELA',
    'GANDAK-DUMARIAGHAT', 'GANDAK-HAJIPUR',
    'GANGA-GANDHIGHAT', 'GANGA-BHAGALPUR',
    'PUNPUN-SRIPALPUR',
  ];

  static const _cwcCodeToStation = <String, String>{
    'KOSI-BIRPUR':        'Birpur (CWC)',
    'KOSI-BASUA':         'Basua',
    'KOSI-KURSELA':       'Kursela',
    'GANDAK-DUMARIAGHAT': 'Dumariaghat',
    'GANDAK-HAJIPUR':     'Hajipur',
    'GANGA-GANDHIGHAT':   'Gandhighat',
    'GANGA-BHAGALPUR':    'Bhagalpur',
    'PUNPUN-SRIPALPUR':   'Sripalpur',
  };

  final _ctrl = StreamController<DataFetchSnapshot>.broadcast();

  Stream<DataFetchSnapshot> get stream     => _ctrl.stream;
  Stream<DataFetchSnapshot> get alertStream => _ctrl.stream;

  DataFetchSnapshot? _last;
  DataFetchSnapshot? get last => _last;

  Timer?   _timer;
  bool     _running     = false;
  int      _errorStreak = 0;

  final Map<String, List<_LevelSample>> _history = {};
  final Map<String, double> _wrdForecast24h = {};

  void start() {
    if (_running) return;
    _running = true;
    if (_last != null) _ctrl.add(_last!);
    FcmBroadcastService.instance.init();
    FcmBroadcastService.instance.snapshots.listen(_onBroadcastSnapshot);
    _fetchCycle();
    _scheduleNext(_baseInterval);
  }

  void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
  }

  Future<void> forceRefresh() => _fetchCycle();

  void _onBroadcastSnapshot(DataFetchSnapshot snap) {
    _last = snap;
    if (!_ctrl.isClosed) _ctrl.add(snap);
    _log('FCM broadcast applied: ${snap.stations.length} stations');
  }

  void _scheduleNext(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, () {
      final last     = _last;
      final fcmFresh = last != null &&
          last.fromBroadcast &&
          DateTime.now().difference(last.fetchedAt) < _fcmStaleness;
      if (!fcmFresh) _fetchCycle();
      else _log('FCM snapshot fresh — skipping HTTP cycle');
      final backoff = _errorStreak > 0
          ? Duration(seconds: math.min(
              _baseInterval.inSeconds * (1 << _errorStreak.clamp(0, 6)),
              _maxBackoffMin.inSeconds))
          : _baseInterval;
      _scheduleNext(backoff);
    });
  }

  Future<void> _fetchCycle() async {
    _log('fetch cycle start');
    final sources = <SourceStatus>[];
    final now     = DateTime.now();
    final api     = BackendApiService.instance;

    final Map<String, StationReading> stations = {};
    for (final g in kBiharGauges) {
      final key  = _normaliseKey(g.station);
      final seed = g.warningLevel * 0.70;
      final prog = g.dangerLevel > 0
          ? (seed / g.dangerLevel * 100).clamp(0.0, 200.0) : 0.0;
      stations[key] = StationReading(
        stationName:  g.station,
        river:        g.river,
        district:     g.district,
        state:        'Bihar',
        lat:          g.lat,
        lon:          g.lon,
        currentLevel: seed,
        warningLevel: g.warningLevel,
        dangerLevel:  g.dangerLevel,
        hfl:          g.hfl,
        progressPct:  prog,
        riskLabel:    'NORMAL',
        source:       'SEED',
        isLive:       false,
        fetchedAt:    now,
      );
    }
    sources.add(SourceStatus(
        name: 'SEED', healthy: true,
        stationCount: stations.length, isFromSeed: true));

    final wrdStart = DateTime.now();
    int wrdCount   = 0;
    _wrdForecast24h.clear();
    try {
      final wrdList = await WrdBiharService.instance.fetch();
      for (final ws in wrdList) {
        final base = _findBase(stations, ws.site, ws.district ?? '');
        if (base == null) continue;
        final cl   = ws.currentLevel ?? base.currentLevel;
        // Thresholds always come from the seed (gauge registry), never from API
        final wl   = base.warningLevel;
        final dl   = base.dangerLevel;
        final live = ws.source == 'WRD_BIHAR_LIVE';
        final key  = _normaliseKey(ws.site);
        stations[key] = base.copyWith(
          currentLevel: cl,
          // riskLabel re-derived inside copyWith via _deriveRisk
          source:       live ? 'WRD_LIVE' : 'WRD_DISK',
          isLive:       live,
          fetchedAt:    now,
        );
        if (ws.forecast24h != null && ws.forecast24h! > 0) {
          _wrdForecast24h[key] = ws.forecast24h!;
        }
        wrdCount++;
      }
      sources.add(SourceStatus(
        name:          'WRD_BIHAR',
        healthy:       wrdCount > 0,
        latencyMs:     DateTime.now().difference(wrdStart).inMilliseconds,
        stationCount:  wrdCount,
        lastSuccessAt: wrdCount > 0 ? now : null,
      ));
    } catch (e) {
      sources.add(SourceStatus(
        name:         'WRD_BIHAR',
        healthy:      false,
        latencyMs:    DateTime.now().difference(wrdStart).inMilliseconds,
        errorMessage: e.toString(),
      ));
      _log('WRD Bihar failed: $e');
    }

    final cwcStart = DateTime.now();
    int   cwcCount = 0;
    try {
      final cwcRows = await api.fetchCwcStations(codes: _cwcCodes);
      for (final r in cwcRows) {
        final code  = r['code'] as String? ?? '';
        final lvl   = (r['level'] as num?)?.toDouble();
        if (lvl == null) continue;
        final sName = _cwcCodeToStation[code];
        if (sName == null) continue;
        final base  = _findBase(stations, sName, '');
        if (base == null) continue;
        final key   = _normaliseKey(sName);
        stations[key] = base.copyWith(
          currentLevel: lvl,
          // riskLabel re-derived inside copyWith
          source:    'CWC_FFS',
          isLive:    true,
          fetchedAt: now,
        );
        cwcCount++;
      }
      sources.add(SourceStatus(
        name:          'CWC_FFS',
        healthy:       cwcCount > 0,
        latencyMs:     DateTime.now().difference(cwcStart).inMilliseconds,
        stationCount:  cwcCount,
        lastSuccessAt: cwcCount > 0 ? now : null,
      ));
    } catch (e) {
      sources.add(SourceStatus(
        name:         'CWC_FFS',
        healthy:      false,
        latencyMs:    DateTime.now().difference(cwcStart).inMilliseconds,
        errorMessage: e.toString(),
      ));
      _log('CWC backend fetch failed (non-fatal): $e');
    }

    final stList = stations.values.toList();
    final lats   = stList.map((s) => s.lat).toList();
    final lons   = stList.map((s) => s.lon).toList();
    final keys   = stList.map((s) => s.stationName.toLowerCase().trim()).toList();

    final Map<int, double> dischargeByIdx = {};
    final Map<int, double> meanByIdx      = {};
    final Map<int, double> rainByIdx      = {};

    final glofasStart = DateTime.now();
    try {
      final rows = await api.fetchGloFAS(lats: lats, lons: lons, cityKeys: keys);
      for (int i = 0; i < rows.length && i < stList.length; i++) {
        final dis  = (rows[i]['discharge']      as num?)?.toDouble();
        final mean = (rows[i]['discharge_mean'] as num?)?.toDouble();
        if (dis  != null) dischargeByIdx[i] = dis;
        if (mean != null) meanByIdx[i]      = mean;
      }
      sources.add(SourceStatus(
        name:          'GLOFAS',
        healthy:       dischargeByIdx.isNotEmpty,
        latencyMs:     DateTime.now().difference(glofasStart).inMilliseconds,
        stationCount:  dischargeByIdx.length,
        lastSuccessAt: now,
      ));
    } catch (e) {
      sources.add(SourceStatus(
        name:         'GLOFAS',
        healthy:      false,
        latencyMs:    DateTime.now().difference(glofasStart).inMilliseconds,
        errorMessage: e.toString(),
      ));
      _log('GloFAS (backend) failed: $e');
    }

    try {
      final rows = await api.fetchRainfall(lats: lats, lons: lons, cityKeys: keys);
      for (int i = 0; i < rows.length && i < stList.length; i++) {
        final rain = (rows[i]['rainfall24h'] as num?)?.toDouble();
        if (rain != null) rainByIdx[i] = rain;
      }
    } catch (e) {
      _log('Rainfall (backend) failed: $e');
    }

    for (int i = 0; i < stList.length; i++) {
      final s    = stList[i];
      final key  = _normaliseKey(s.stationName);
      final dis  = dischargeByIdx[i];
      final mean = meanByIdx[i];
      final rain = rainByIdx[i];
      if (s.source == 'SEED' && dis != null && mean != null &&
          mean > 0 && s.dangerLevel > 0) {
        final rawEstimate = (dis / mean) * s.dangerLevel * 0.85;
        final maxAllowed  = s.hfl * 0.98;
        final estLevel    = rawEstimate.clamp(0.0, maxAllowed);
        stations[key] = s.copyWith(
          currentLevel:   estLevel,
          flowRateCumecs: dis,
          rainfall24hMm:  rain,
          source:   'GLOFAS',
          isLive:   true,
        );
      } else {
        stations[key] = s.copyWith(flowRateCumecs: dis, rainfall24hMm: rain);
      }
    }

    final withRoR = <StationReading>[];
    for (final s in stations.values) {
      final key  = _normaliseKey(s.stationName);
      final hist = _history.putIfAbsent(key, () => []);
      hist.add(_LevelSample(s.currentLevel, now));
      if (hist.length > 60) hist.removeAt(0);
      double? ror;
      if (hist.length >= 2) {
        final dt = hist.last.time.difference(hist.first.time).inMinutes;
        if (dt > 0) {
          ror = (hist.last.level - hist.first.level) / (dt / 60.0);
        }
      }
      withRoR.add(s.copyWith(rateOfRiseMph: ror));
    }

    final finalList = withRoR.map((s) {
      if (!s.isLive) return s;
      final key      = _normaliseKey(s.stationName);
      final ror      = s.rateOfRiseMph ?? 0.0;
      final rainMod  = s.rainfall24hMm != null
          ? (s.rainfall24hMm! / 50.0).clamp(0.0, 1.5) : 0.3;
      final rise     = ror * rainMod;

      final bulletinF24 = _wrdForecast24h[key];
      if (bulletinF24 != null && s.source == 'WRD_LIVE') {
        final f24   = bulletinF24.clamp(0.0, s.hfl);
        final delta = rise > 0 ? rise : (f24 - s.currentLevel) / 24.0;
        return s.copyWith(
          forecastLevel24h: f24,
          forecastLevel48h: (f24 + delta * 24).clamp(0.0, s.hfl),
          forecastLevel72h: (f24 + delta * 48).clamp(0.0, s.hfl),
        );
      }

      return s.copyWith(
        forecastLevel24h: (s.currentLevel + rise * 24).clamp(0.0, s.hfl),
        forecastLevel48h: (s.currentLevel + rise * 48).clamp(0.0, s.hfl),
        forecastLevel72h: (s.currentLevel + rise * 72).clamp(0.0, s.hfl),
      );
    }).toList()
      ..sort((a, b) => b.progressPct.compareTo(a.progressPct));

    final snap = DataFetchSnapshot(
      stations:  finalList,
      sources:   sources,
      fetchedAt: now,
      isLoading: false,
    );
    _last        = snap;
    _errorStreak = 0;
    if (!_ctrl.isClosed) _ctrl.add(snap);

    unawaited(BackendSyncService.instance.pushGaugeTelemetry(snap));

    _log('cycle done: ${finalList.length} stations, '
        '${finalList.where((s) => s.isLive).length} live, '
        '${_wrdForecast24h.length} bulletin-24h forecasts');
  }

  StationReading? _findBase(
      Map<String, StationReading> map, String site, String district) {
    final sk = _normaliseKey(site);
    if (map.containsKey(sk)) return map[sk];
    for (final key in map.keys) {
      if (key.contains(sk) || sk.contains(key)) return map[key];
    }
    final stripped = sk.replaceAll(RegExp(r'\s*\(.*\)'), '').trim();
    if (stripped != sk) {
      if (map.containsKey(stripped)) return map[stripped];
      for (final key in map.keys) {
        if (key.contains(stripped) || stripped.contains(key)) return map[key];
      }
    }
    final prefix = sk.length > 5 ? sk.substring(0, 5) : sk;
    for (final key in map.keys) {
      final kp = key.length > 5 ? key.substring(0, 5) : key;
      if (kp == prefix) return map[key];
    }
    if (district.isNotEmpty) {
      final dk = _normaliseKey(district);
      for (final key in map.keys) {
        if (key.contains(dk) || dk.contains(key)) return map[key];
      }
    }
    return null;
  }

  static String _normaliseKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim();

  static DataFetchSnapshot _buildSeedSnapshot() {
    final now   = DateTime.now();
    final seeds = kBiharGauges.map((g) {
      final cl   = g.warningLevel * 0.70;
      final prog = g.dangerLevel > 0
          ? (cl / g.dangerLevel * 100).clamp(0.0, 200.0) : 0.0;
      return StationReading(
        stationName: g.station, river: g.river,
        district: g.district, state: 'Bihar',
        lat: g.lat, lon: g.lon,
        currentLevel: cl, warningLevel: g.warningLevel,
        dangerLevel: g.dangerLevel, hfl: g.hfl,
        progressPct: prog, riskLabel: 'NORMAL',
        source: 'SEED', isLive: false, fetchedAt: now,
      );
    }).toList();
    return DataFetchSnapshot(
      stations: seeds,
      sources:  [SourceStatus(name:'SEED', healthy:true,
          stationCount: seeds.length, isFromSeed: true)],
      fetchedAt: now,
    );
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[DataFetchEngine] $msg');
  }
}

class _LevelSample {
  final double   level;
  final DateTime time;
  const _LevelSample(this.level, this.time);
}
