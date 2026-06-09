// lib/services/data_fetch_engine.dart  v2.2
//
// v2.1 → v2.2 changes:
//   Forecast Step 6: WRD-covered stations now use ws.forecast24h (bulletin-
//   accurate 24h predicted level from FMISC/CWC model) instead of the
//   GloFAS rate-of-rise heuristic. The heuristic is retained as fallback
//   for GLOFAS/SEED stations not covered by WRD bulletin.
//
//   Logic:
//     source == 'WRD_LIVE' && ws.forecast24h != null
//       → forecastLevel24h = ws.forecast24h (clamped to hfl)
//         forecastLevel48h / 72h = heuristic from that anchor (not bulletin)
//     otherwise
//       → all three = heuristic from current level
//
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/bihar_rivers.dart';
import '../models/river_station.dart';
import 'wrd_bihar_service.dart';
import 'fcm_broadcast_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
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
      riskLabel:        riskLabel ?? _deriveRisk(cl, this.warningLevel, dng),
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

  static String _deriveRisk(double cur, double warn, double dng) {
    if (cur >= dng)          return 'CRITICAL';
    if (cur >= warn)         return 'DANGER';
    if (cur >= warn * 0.85)  return 'WARNING';
    return 'NORMAL';
  }

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
      riskLabel:    j['rl'] as String,
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
  int    get warningCount    => stations.where((s) => s.riskLabel == 'WARNING').length;
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

// ──────────────────────────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._() {
    _last = _buildSeedSnapshot();
  }
  static final instance = DataFetchEngine._();

  static const _baseInterval   = Duration(seconds: 45);
  static const _cwcTimeout     = Duration(seconds: 4);
  static const _httpTimeout    = Duration(seconds: 8);
  static const _fcmStaleness   = Duration(minutes: 3);
  static const _maxBackoffMin  = Duration(minutes: 5);
  static const _openMeteoBatch = 8;

  static const _cwcCodes = <String, String>{
    'Birpur (CWC)':  'KOSI-BIRPUR',
    'Basua':         'KOSI-BASUA',
    'Kursela':       'KOSI-KURSELA',
    'Dumariaghat':   'GANDAK-DUMARIAGHAT',
    'Hajipur':       'GANDAK-HAJIPUR',
    'Gandhighat':    'GANGA-GANDHIGHAT',
    'Bhagalpur':     'GANGA-BHAGALPUR',
    'Sripalpur':     'PUNPUN-SRIPALPUR',
  };

  final _ctrl = StreamController<DataFetchSnapshot>.broadcast();
  Stream<DataFetchSnapshot> get stream => _ctrl.stream;

  DataFetchSnapshot? _last;
  DataFetchSnapshot? get last => _last;

  Timer?   _timer;
  bool     _running     = false;
  int      _errorStreak = 0;

  final Map<String, List<_LevelSample>> _history = {};

  // v2.2: track forecast24h values from WRD scrape so Step 6 can use them
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

    // ── Step 1: Seed ──────────────────────────────────────────────────────────
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

    // ── Step 2: WRD Bihar ─────────────────────────────────────────────────────
    final wrdStart = DateTime.now();
    int wrdCount   = 0;
    _wrdForecast24h.clear();  // reset before each cycle
    try {
      final wrdList = await WrdBiharService.instance.fetch();
      for (final ws in wrdList) {
        final base = _findBase(stations, ws.site, ws.district ?? '');
        if (base == null) continue;
        final cl   = ws.currentLevel ?? base.currentLevel;
        final wl   = (ws.warningLevel != null && ws.warningLevel! > 0)
            ? ws.warningLevel! : base.warningLevel;
        final dl   = (ws.dangerLevel  != null && ws.dangerLevel!  > 0)
            ? ws.dangerLevel!  : base.dangerLevel;
        final live = ws.source == 'WRD_BIHAR_LIVE';
        final key  = _normaliseKey(ws.site);
        stations[key] = base.copyWith(
          currentLevel: cl,
          riskLabel:    StationReading._deriveRisk(cl, wl, dl),
          source:       live ? 'WRD_LIVE' : 'WRD_DISK',
          isLive:       live,
          fetchedAt:    now,
        );
        // v2.2: stash bulletin forecast24h keyed by normalised station name
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

    // ── Step 3: CWC multi-URL race ────────────────────────────────────────────
    final cwcStart  = DateTime.now();
    int   cwcCount  = 0;
    final cwcFutures = _cwcCodes.entries.map((e) =>
        _fetchCwcStationRaced(e.value)
            .then<MapEntry<String, double?>?>(
                (lvl) => MapEntry(e.key, lvl))
            .catchError((_) => null),
    ).toList();
    final cwcResults = await Future.wait(cwcFutures);
    for (final r in cwcResults) {
      if (r == null || r.value == null) continue;
      final base = _findBase(stations, r.key, '');
      if (base == null) continue;
      final cl  = r.value!;
      final key = _normaliseKey(r.key);
      stations[key] = base.copyWith(
        currentLevel: cl,
        riskLabel: StationReading._deriveRisk(cl, base.warningLevel, base.dangerLevel),
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

    // ── Step 4: GloFAS + Open-Meteo ───────────────────────────────────────────
    final stList = stations.values.toList();
    final Map<int, double> dischargeByIdx = {};
    final Map<int, double> meanByIdx      = {};
    final Map<int, double> rainByIdx      = {};

    final glofasStart = DateTime.now();
    try {
      final lats = stList.map((s) => s.lat.toString()).join(',');
      final lons = stList.map((s) => s.lon.toString()).join(',');
      final res  = await http.get(Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=$lats&longitude=$lons'
        '&daily=river_discharge,river_discharge_mean'
        '&forecast_days=3&models=seamless_v4',
      )).timeout(_httpTimeout);
      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body);
        final items = body is List ? body : [body];
        for (int i = 0; i < items.length && i < stList.length; i++) {
          final daily = items[i]['daily'] as Map<String, dynamic>?;
          final dis   = _extractDoubles(daily?['river_discharge']);
          final mean  = _extractDoubles(daily?['river_discharge_mean']);
          if (dis.isNotEmpty)  dischargeByIdx[i] = dis[0];
          if (mean.isNotEmpty) meanByIdx[i]      = mean[0];
        }
      }
      sources.add(SourceStatus(
        name: 'GLOFAS', healthy: dischargeByIdx.isNotEmpty,
        latencyMs:    DateTime.now().difference(glofasStart).inMilliseconds,
        stationCount: dischargeByIdx.length, lastSuccessAt: now,
      ));
    } catch (e) {
      sources.add(SourceStatus(
          name: 'GLOFAS', healthy: false,
          latencyMs:    DateTime.now().difference(glofasStart).inMilliseconds,
          errorMessage: e.toString()));
      _log('GloFAS failed: $e');
    }

    // Open-Meteo rainfall batched
    for (int bStart = 0; bStart < stList.length; bStart += _openMeteoBatch) {
      final bEnd  = math.min(bStart + _openMeteoBatch, stList.length);
      final batch = stList.sublist(bStart, bEnd);
      final bLats = batch.map((s) => s.lat.toString()).join(',');
      final bLons = batch.map((s) => s.lon.toString()).join(',');
      try {
        final res = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=$bLats&longitude=$bLons'
          '&daily=precipitation_sum'
          '&forecast_days=1&timezone=Asia%2FKolkata',
        )).timeout(_httpTimeout);
        if (res.statusCode == 200) {
          final body  = jsonDecode(res.body);
          final items = body is List ? body : [body];
          for (int i = 0; i < items.length && i < batch.length; i++) {
            final daily = items[i]['daily'] as Map<String, dynamic>?;
            final vals  = _extractDoubles(daily?['precipitation_sum']);
            if (vals.isNotEmpty) rainByIdx[bStart + i] = vals[0];
          }
        }
      } catch (e) {
        _log('Open-Meteo batch[$bStart..${bEnd-1}] failed: $e');
      }
    }

    // Merge GloFAS + rain into SEED-only stations (FIX #7: HFL clamp retained)
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
        stations[key] = s.copyWith(
            flowRateCumecs: dis, rainfall24hMm: rain);
      }
    }

    // ── Step 5: Rate of rise ──────────────────────────────────────────────────
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

    // ── Step 6: 24/48/72h forecast ────────────────────────────────────────────
    //
    // v2.2 change: WRD_LIVE stations use bulletin forecast24h for the 24h slot.
    // 48h and 72h still use heuristic anchored from the bulletin 24h value.
    // GLOFAS/SEED stations: all three slots use heuristic from current level.
    final finalList = withRoR.map((s) {
      if (!s.isLive) return s;
      final key      = _normaliseKey(s.stationName);
      final ror      = s.rateOfRiseMph ?? 0.0;
      final rainMod  = s.rainfall24hMm != null
          ? (s.rainfall24hMm! / 50.0).clamp(0.0, 1.5) : 0.3;
      final rise     = ror * rainMod;

      // Bulletin 24h forecast available for this station?
      final bulletinF24 = _wrdForecast24h[key];
      if (bulletinF24 != null && s.source == 'WRD_LIVE') {
        // Use bulletin for 24h; extrapolate 48/72 from that anchor.
        // If ror is near-zero use simple linear from bulletin value.
        final f24 = bulletinF24.clamp(0.0, s.hfl);
        final delta = rise > 0 ? rise : (f24 - s.currentLevel) / 24.0;
        return s.copyWith(
          forecastLevel24h: f24,
          forecastLevel48h: (f24 + delta * 24).clamp(0.0, s.hfl),
          forecastLevel72h: (f24 + delta * 48).clamp(0.0, s.hfl),
        );
      }

      // Fallback: full heuristic (GloFAS / SEED / WRD_DISK)
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
    _log('cycle done: ${finalList.length} stations, '
        '${finalList.where((s) => s.isLive).length} live, '
        '${_wrdForecast24h.length} bulletin-24h forecasts');
  }

  Future<double?> _fetchCwcStationRaced(String code) async {
    final urls = [
      'https://beams.fmiscwrdbihar.gov.in/ffs/api/station/$code',
      'https://indiawris.gov.in/wris/#/riverMonitoring?station=$code',
      'https://ffs.india-water.gov.in/ffs/api/station/$code',
      'https://ffs.india-water.gov.in/ffs/pages/getFloodData.php?station=$code',
    ];
    final futures = urls.map((url) async {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/2.2'},
        ).timeout(_cwcTimeout);
        if (res.statusCode != 200) return null;
        return _extractLevel(jsonDecode(res.body));
      } catch (_) {
        return null;
      }
    }).toList();
    final results = await Future.wait(futures);
    for (final r in results) {
      if (r != null) return r;
    }
    return null;
  }

  double? _extractLevel(dynamic j) {
    if (j is Map) {
      for (final k in ['level','water_level','gauge','value','currentLevel',
                       'wl','WaterLevel','current_level']) {
        if (j[k] != null) {
          final v = j[k];
          if (v is double) return v;
          if (v is int)    return v.toDouble();
          return double.tryParse(v.toString());
        }
      }
      if (j['data']    != null) return _extractLevel(j['data']);
      if (j['station'] != null) return _extractLevel(j['station']);
    }
    if (j is List && j.isNotEmpty) return _extractLevel(j.first);
    return null;
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

  List<double> _extractDoubles(dynamic raw) {
    if (raw is List) {
      return raw.map<double?>((v) {
        if (v is double) return v;
        if (v is int)    return v.toDouble();
        return double.tryParse(v.toString());
      }).whereType<double>().toList();
    }
    return [];
  }

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
