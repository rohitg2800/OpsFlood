// lib/services/data_fetch_engine.dart  v1.0
//
// Central data fetch orchestrator for OpsFlood.
//
// Sources (priority order for river level):
//   1. CWC FFS  — https://ffs.india-water.gov.in/ffs/api/station/<code>
//   2. WRD Bihar live  — irrigation.befiqr.in (via WrdBiharService)
//   3. WRD Bihar disk  — WrdBiharService offline cache
//   4. GloFAS discharge  — flood-api.open-meteo.com
//   5. kBiharGauges seed — static fallback from bihar_rivers.dart
//
// Auto-refresh: every 45 s; exponential back-off (max 5 min) on errors.
// All consumers subscribe to [stream]; each tick emits DataFetchSnapshot.

library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/bihar_rivers.dart';
import '../models/river_station.dart';
import 'wrd_bihar_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StationReading — one gauge reading merged from all available sources
// ─────────────────────────────────────────────────────────────────────────────
class StationReading {
  final String  stationName;
  final String  river;
  final String  district;
  final String  state;
  final double  lat;
  final double  lon;

  // Level data
  final double  currentLevel;   // metres MSL
  final double  warningLevel;
  final double  dangerLevel;
  final double  hfl;

  // Derived
  final double  progressPct;    // current / danger × 100
  final String  riskLabel;      // NORMAL / WARNING / DANGER / CRITICAL

  // Source metadata
  final String  source;         // CWC_FFS | WRD_LIVE | WRD_DISK | GLOFAS | SEED
  final bool    isLive;
  final DateTime fetchedAt;

  // Optional enrichments
  final double? flowRateCumecs;
  final double? rainfall24hMm;
  final double? forecastLevel24h;
  final double? forecastLevel48h;
  final double? forecastLevel72h;
  final double? rateOfRiseMph;  // metres per hour

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
    final cl     = currentLevel ?? this.currentLevel;
    final danger = this.dangerLevel;
    final prog   = danger > 0 ? (cl / danger * 100).clamp(0.0, 200.0) : 0.0;
    return StationReading(
      stationName:       this.stationName,
      river:             this.river,
      district:          this.district,
      state:             this.state,
      lat:               this.lat,
      lon:               this.lon,
      currentLevel:      cl,
      warningLevel:      this.warningLevel,
      dangerLevel:       danger,
      hfl:               this.hfl,
      progressPct:       prog,
      riskLabel:         riskLabel    ?? _deriveRisk(cl, this.warningLevel, danger),
      source:            source       ?? this.source,
      isLive:            isLive       ?? this.isLive,
      fetchedAt:         fetchedAt    ?? this.fetchedAt,
      flowRateCumecs:    flowRateCumecs    ?? this.flowRateCumecs,
      rainfall24hMm:     rainfall24hMm     ?? this.rainfall24hMm,
      forecastLevel24h:  forecastLevel24h  ?? this.forecastLevel24h,
      forecastLevel48h:  forecastLevel48h  ?? this.forecastLevel48h,
      forecastLevel72h:  forecastLevel72h  ?? this.forecastLevel72h,
      rateOfRiseMph:     rateOfRiseMph     ?? this.rateOfRiseMph,
    );
  }

  /// Convert to the RiverStation model used by existing providers/screens.
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
    if (cur >= dng)  return 'CRITICAL';
    if (cur >= warn) return 'DANGER';
    if (cur >= warn * 0.85) return 'WARNING';
    return 'NORMAL';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SourceStatus — health of each data source after a fetch cycle
// ─────────────────────────────────────────────────────────────────────────────
class SourceStatus {
  final String    name;
  final bool      healthy;
  final int?      latencyMs;
  final int       stationCount;
  final DateTime? lastSuccessAt;
  final String?   errorMessage;

  const SourceStatus({
    required this.name,
    required this.healthy,
    this.latencyMs,
    this.stationCount = 0,
    this.lastSuccessAt,
    this.errorMessage,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DataFetchSnapshot — emitted on every cycle
// ─────────────────────────────────────────────────────────────────────────────
class DataFetchSnapshot {
  final List<StationReading> stations;
  final List<SourceStatus>   sources;
  final DateTime             fetchedAt;
  final bool                 isLoading;
  final String?              error;

  // Quick aggregates
  int get totalStations   => stations.length;
  int get liveStations    => stations.where((s) => s.isLive).length;
  int get criticalCount   => stations.where((s) => s.riskLabel == 'CRITICAL').length;
  int get dangerCount     => stations.where((s) =>
      s.riskLabel == 'CRITICAL' || s.riskLabel == 'DANGER').length;
  int get warningCount    => stations.where((s) => s.riskLabel == 'WARNING').length;
  double get maxLevel     =>
      stations.isEmpty ? 0 : stations.map((s) => s.currentLevel).reduce((a, b) => a > b ? a : b);
  String get maxLevelStation =>
      stations.isEmpty ? '—' :
      stations.reduce((a, b) => a.currentLevel > b.currentLevel ? a : b).stationName;

  const DataFetchSnapshot({
    required this.stations,
    required this.sources,
    required this.fetchedAt,
    this.isLoading = false,
    this.error,
  });

  static DataFetchSnapshot loading() => DataFetchSnapshot(
    stations: const [],
    sources:  const [],
    fetchedAt: DateTime.now(),
    isLoading: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DataFetchEngine — singleton
// ─────────────────────────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final instance = DataFetchEngine._();

  static const _baseInterval  = Duration(seconds: 45);
  static const _httpTimeout   = Duration(seconds: 14);
  static const _maxBackoffMin = Duration(minutes: 5);

  // CWC FFS station codes for Bihar gauges that have them
  static const _cwcCodes = <String, String>{
    'Birpur (CWC)':      'KOSI-BIRPUR',
    'Basua':             'KOSI-BASUA',
    'Kursela':           'KOSI-KURSELA',
    'Dumariaghat':       'GANDAK-DUMARIAGHAT',
    'Hajipur':           'GANDAK-HAJIPUR',
    'Gandhighat':        'GANGA-GANDHIGHAT',
    'Bhagalpur':         'GANGA-BHAGALPUR',
    'Sripalpur':         'PUNPUN-SRIPALPUR',
  };

  final _ctrl    = StreamController<DataFetchSnapshot>.broadcast();
  Stream<DataFetchSnapshot> get stream => _ctrl.stream;

  DataFetchSnapshot? _last;
  DataFetchSnapshot? get last => _last;

  Timer?   _timer;
  bool     _running    = false;
  int      _errorStreak = 0;

  // ── Level-history for rate-of-rise calculation ────────────────────────────
  final Map<String, List<_LevelSample>> _history = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  void start() {
    if (_running) return;
    _running = true;
    _ctrl.add(DataFetchSnapshot.loading());
    _fetchCycle();
    _scheduleNext(_baseInterval);
  }

  void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
  }

  Future<void> forceRefresh() => _fetchCycle();

  void _scheduleNext(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, () {
      _fetchCycle();
      final backoff = _errorStreak > 0
          ? Duration(seconds: (_baseInterval.inSeconds * (1 << _errorStreak.clamp(0, 6))).toInt())
          : _baseInterval;
      _scheduleNext(backoff > _maxBackoffMin ? _maxBackoffMin : backoff);
    });
  }

  // ── Main fetch cycle ──────────────────────────────────────────────────────
  Future<void> _fetchCycle() async {
    _log('fetch cycle start');
    final sources = <SourceStatus>[];

    // ── 1. Build seed map from kBiharGauges ──────────────────────────────
    final Map<String, StationReading> stations = {};
    final now = DateTime.now();
    for (final g in kBiharGauges) {
      final key = g.station.toLowerCase();
      final seed = _seedLevel(g.warningLevel);
      final prog = g.dangerLevel > 0
          ? (seed / g.dangerLevel * 100).clamp(0.0, 200.0)
          : 0.0;
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
    sources.add(SourceStatus(name: 'SEED', healthy: true, stationCount: stations.length));

    // ── 2. WRD Bihar ──────────────────────────────────────────────────────
    final wrdStart = DateTime.now();
    int wrdCount = 0;
    try {
      final wrdStations = await WrdBiharService.instance.fetch();
      for (final ws in wrdStations) {
        final key = ws.site.toLowerCase();
        final base = _findBase(stations, ws.site, ws.district);
        if (base == null) continue;
        final cl = ws.currentLevel ?? base.currentLevel;
        final wl = (ws.warningLevel != null && ws.warningLevel! > 0)
            ? ws.warningLevel! : base.warningLevel;
        final dl = (ws.dangerLevel  != null && ws.dangerLevel!  > 0)
            ? ws.dangerLevel!  : base.dangerLevel;
        final isLive = ws.source == 'WRD_BIHAR_LIVE';
        final prog = dl > 0 ? (cl / dl * 100).clamp(0.0, 200.0) : 0.0;
        final updated = base.copyWith(
          currentLevel: cl,
          riskLabel:    StationReading._deriveRisk(cl, wl, dl),
          source:       isLive ? 'WRD_LIVE' : 'WRD_DISK',
          isLive:       isLive,
          fetchedAt:    now,
        );
        stations[key] = updated;
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

    // ── 3. CWC FFS (parallel) ─────────────────────────────────────────────
    final cwcStart = DateTime.now();
    int cwcCount = 0;
    final cwcFetches = _cwcCodes.entries.map((e) =>
        _fetchCwcStation(e.value).then<MapEntry<String, double?>?>(
          (lvl) => MapEntry(e.key, lvl),
        ).catchError((_) => null),
    ).toList();
    final cwcResults = await Future.wait(cwcFetches);
    for (final r in cwcResults) {
      if (r == null || r.value == null) continue;
      final stnName = r.key;
      final cl      = r.value!;
      final key     = stnName.toLowerCase();
      final base    = _findBase(stations, stnName, '');
      if (base == null) continue;
      final prog = base.dangerLevel > 0
          ? (cl / base.dangerLevel * 100).clamp(0.0, 200.0) : 0.0;
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

    // ── 4. GloFAS discharge + Open-Meteo rainfall (parallel) ─────────────
    final glofasStart = DateTime.now();
    final biharStations = stations.values.toList();
    final lats = biharStations.map((s) => '${s.lat}').join(',');
    final lons = biharStations.map((s) => '${s.lon}').join(',');
    Map<int, double> dischargeByIdx = {};
    Map<int, double> meanByIdx      = {};
    Map<int, double> rainByIdx      = {};

    try {
      final glofasRes = await http.get(Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=$lats&longitude=$lons'
        '&daily=river_discharge,river_discharge_mean'
        '&forecast_days=3&models=seamless_v4',
      )).timeout(_httpTimeout);
      if (glofasRes.statusCode != 200) throw Exception('GloFAS HTTP ${glofasRes.statusCode}');
      final body  = jsonDecode(glofasRes.body);
      final items = body is List ? body : [body];
      for (int i = 0; i < items.length && i < biharStations.length; i++) {
        final daily  = items[i]['daily'] as Map<String, dynamic>?;
        final dis    = _extractDoubles(daily?['river_discharge']);
        final mean   = _extractDoubles(daily?['river_discharge_mean']);
        if (dis.isNotEmpty)  dischargeByIdx[i] = dis[0];
        if (mean.isNotEmpty) meanByIdx[i]      = mean[0];
      }
      sources.add(SourceStatus(
        name: 'GLOFAS', healthy: true,
        latencyMs: DateTime.now().difference(glofasStart).inMilliseconds,
        stationCount: dischargeByIdx.length, lastSuccessAt: now,
      ));
    } catch (e) {
      sources.add(SourceStatus(
        name: 'GLOFAS', healthy: false,
        latencyMs: DateTime.now().difference(glofasStart).inMilliseconds,
        errorMessage: e.toString(),
      ));
      _log('GloFAS failed: $e');
    }

    // Open-Meteo rainfall
    try {
      final omRes = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lats&longitude=$lons'
        '&daily=precipitation_sum'
        '&forecast_days=1&timezone=Asia%2FKolkata',
      )).timeout(_httpTimeout);
      if (omRes.statusCode != 200) throw Exception('Open-Meteo HTTP ${omRes.statusCode}');
      final body  = jsonDecode(omRes.body);
      final items = body is List ? body : [body];
      for (int i = 0; i < items.length && i < biharStations.length; i++) {
        final daily = items[i]['daily'] as Map<String, dynamic>?;
        final vals  = _extractDoubles(daily?['precipitation_sum']);
        if (vals.isNotEmpty) rainByIdx[i] = vals[0];
      }
    } catch (e) {
      _log('Open-Meteo rainfall failed: $e');
    }

    // Merge GloFAS flow + rain into stations
    final stList = stations.values.toList();
    for (int i = 0; i < stList.length; i++) {
      final s    = stList[i];
      final key  = s.stationName.toLowerCase();
      final dis  = dischargeByIdx[i];
      final mean = meanByIdx[i];
      final rain = rainByIdx[i];
      // Only use GloFAS level estimate if station is still SEED
      if (s.source == 'SEED' && dis != null && mean != null && mean > 0 && s.dangerLevel > 0) {
        final estLevel = (dis / mean) * s.dangerLevel * 0.85;
        stations[key] = s.copyWith(
          currentLevel: estLevel,
          flowRateCumecs: dis,
          rainfall24hMm:  rain,
          source:   'GLOFAS',
          isLive:   true,
        );
      } else {
        stations[key] = s.copyWith(
          flowRateCumecs: dis,
          rainfall24hMm:  rain,
        );
      }
    }

    // ── 5. Compute rate of rise ───────────────────────────────────────────
    final updatedStations = <StationReading>[];
    for (final s in stations.values) {
      final key = s.stationName.toLowerCase();
      _history.putIfAbsent(key, () => []);
      final hist = _history[key]!;
      hist.add(_LevelSample(s.currentLevel, now));
      if (hist.length > 60) hist.removeAt(0); // keep 60 samples (~45 min)
      double? ror;
      if (hist.length >= 2) {
        final first = hist.first;
        final last  = hist.last;
        final dt    = last.time.difference(first.time).inMinutes;
        if (dt > 0) {
          ror = (last.level - first.level) / (dt / 60.0);
        }
      }
      updatedStations.add(s.copyWith(rateOfRiseMph: ror));
    }

    // ── 6. Forecast 24/48/72h (linear extrapolation + rainfall modifier) ──
    final finalStations = updatedStations.map((s) {
      if (!s.isLive) return s;
      final ror = s.rateOfRiseMph ?? 0.0;
      final rainMod = s.rainfall24hMm != null
          ? (s.rainfall24hMm! / 50.0).clamp(0.0, 1.5) : 0.3;
      final rise = ror * rainMod;
      return s.copyWith(
        forecastLevel24h: (s.currentLevel + rise * 24).clamp(0.0, s.hfl * 1.1),
        forecastLevel48h: (s.currentLevel + rise * 48).clamp(0.0, s.hfl * 1.1),
        forecastLevel72h: (s.currentLevel + rise * 72).clamp(0.0, s.hfl * 1.1),
      );
    }).toList();

    // Sort by risk
    finalStations.sort((a, b) => b.progressPct.compareTo(a.progressPct));

    final snapshot = DataFetchSnapshot(
      stations:  finalStations,
      sources:   sources,
      fetchedAt: now,
      isLoading: false,
    );
    _last = snapshot;
    if (!_ctrl.isClosed) _ctrl.add(snapshot);
    _errorStreak = 0;
    _log('cycle done: ${finalStations.length} stations, '
        '${finalStations.where((s) => s.isLive).length} live');
  }

  // ── CWC FFS single-station fetch ──────────────────────────────────────────
  Future<double?> _fetchCwcStation(String code) async {
    final urls = [
      'https://ffs.india-water.gov.in/ffs/api/station/$code',
      'https://beams.fmiscwrdbihar.gov.in/ffs/api/station/$code',
    ];
    for (final url in urls) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/1.0'},
        ).timeout(_httpTimeout);
        if (res.statusCode != 200) continue;
        final j = jsonDecode(res.body);
        final level = _extractLevel(j);
        if (level != null) return level;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  double? _extractLevel(dynamic j) {
    if (j is Map) {
      for (final k in ['level', 'water_level', 'gauge', 'value', 'currentLevel']) {
        if (j[k] != null) {
          final v = j[k];
          if (v is double) return v;
          if (v is int)    return v.toDouble();
          return double.tryParse(v.toString());
        }
      }
      if (j['data'] != null) return _extractLevel(j['data']);
      if (j['station'] != null) return _extractLevel(j['station']);
    }
    if (j is List && j.isNotEmpty) return _extractLevel(j.first);
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  StationReading? _findBase(
      Map<String, StationReading> map, String site, String district) {
    final sk = site.toLowerCase().trim();
    if (map.containsKey(sk)) return map[sk];
    for (final key in map.keys) {
      if (key.contains(sk) || sk.contains(key)) return map[key];
    }
    if (district.isNotEmpty) {
      final dk = district.toLowerCase().trim();
      for (final key in map.keys) {
        if (key.contains(dk) || dk.contains(key)) return map[key];
      }
    }
    return null;
  }

  double _seedLevel(double warningLevel) => warningLevel * 0.70;

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

  void _log(String msg) {
    if (kDebugMode) debugPrint('[DataFetchEngine] $msg');
  }
}

class _LevelSample {
  final double   level;
  final DateTime time;
  const _LevelSample(this.level, this.time);
}
