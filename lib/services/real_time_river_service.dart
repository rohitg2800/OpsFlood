// lib/services/real_time_river_service.dart
//
// OpsFlood — Real-Time River Data Service
//
// DATA SOURCES (priority order):
//   1. WrdBiharService — official Bihar WRD portal
//      Primary:  https://irrigation.befiqr.in/state/table/rivers
//      Fallback: https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx
//   2. GloFAS / Open-Meteo — river discharge (m³/s) for every city lat/lon
//      Used when WRD Bihar has no matching station (non-Bihar cities or
//      Bihar cities not yet listed in the WRD feed).
//
// The OpsFlood backend cascade (BULK telemetry / /live/telemetry /
// /cwc/ffs / /cwc/reservoir) has been removed — all those endpoints
// were returning 404 due to a URL prefix mismatch and are not needed
// when the app fetches directly from official portals.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/river_station.dart';
import 'live_fetch_engine.dart';
import 'wrd_bihar_service.dart';

// ── Result model ─────────────────────────────────────────────────────────────
class LiveRiverResult {
  final RiverStation station;
  final String       source;      // 'WRD_BIHAR' | 'GLOFAS' | 'NO_DATA'
  final double       confidence;  // 0.0–1.0
  final String?      mlRiskLevel;
  final double?      mlFloodProb;
  final bool         isStale;
  final String?      rawTimestamp;

  const LiveRiverResult({
    required this.station,
    required this.source,
    required this.confidence,
    this.mlRiskLevel,
    this.mlFloodProb,
    this.isStale = false,
    this.rawTimestamp,
  });
}

void _log(String msg) {
  if (kDebugMode) debugPrint('[RTRS] $msg');
}

// ── Service ───────────────────────────────────────────────────────────────────
class RealTimeRiverService extends ChangeNotifier {
  RealTimeRiverService();

  final WrdBiharService _wrd = WrdBiharService.instance;
  final LiveFetchEngine _lfe = LiveFetchEngine();

  List<LiveRiverResult> _lastResults = [];
  List<LiveRiverResult> get lastResults => _lastResults;

  // ── Public: fetch all monitored cities ───────────────────────────────────
  Future<List<LiveRiverResult>> fetchAll() async {
    final results = <LiveRiverResult>[];

    // Warm WRD Bihar cache once
    await _wrd.fetch();

    // Warm GloFAS cache (web + mobile fallback)
    if (_lfe.liveLevels.isEmpty) {
      try { await _lfe.refreshData(); } catch (_) {}
    }

    for (final mc in AppConstants.monitoredCities) {
      final city  = mc['city']  as String;
      final state = mc['state'] as String;
      final river = mc['river'] as String;
      final wl    = _fp(mc['warning_level']);
      final dl    = _fp(mc['danger_level']);
      results.add(await _fetchCity(
        city: city, state: state, river: river,
        warningLevel: wl, dangerLevel: dl,
      ));
    }

    final live = results.where((r) => r.source != 'NO_DATA').length;
    _log('fetchAll done: $live/${results.length} with live data');
    _lastResults = results;
    notifyListeners();
    return results;
  }

  // ── Public: fetch single city ────────────────────────────────────────────
  Future<LiveRiverResult> fetchCity({
    required String city,
    required String state,
    required String river,
  }) async {
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    return _fetchCity(
      city: city, state: state, river: river,
      warningLevel: _fp(mc['warning_level']),
      dangerLevel:  _fp(mc['danger_level']),
    );
  }

  // ── Public: force refresh ────────────────────────────────────────────────
  Future<List<LiveRiverResult>> refresh() async {
    await _wrd.fetch(forceRefresh: true);
    try { await _lfe.refreshData(); } catch (_) {}
    return fetchAll();
  }

  @override
  void dispose() {
    _lastResults = [];
    super.dispose();
  }

  // ── Per-city fetch: WRD Bihar → GloFAS → NO_DATA ─────────────────────────
  Future<LiveRiverResult> _fetchCity({
    required String city,
    required String state,
    required String river,
    required double warningLevel,
    required double dangerLevel,
  }) async {
    final hfl = dangerLevel > 0 ? dangerLevel * 1.10 : warningLevel * 1.25;

    // ── Source 1: official Bihar WRD portal ──────────────────────────────
    try {
      final wrdMatch = await _wrd.fetchBestMatch(city, river: river);
      if (wrdMatch != null && wrdMatch.currentLevel != null) {
        final lv = wrdMatch.currentLevel!;
        final dl = wrdMatch.dangerLevel  ?? dangerLevel;
        final wl = wrdMatch.warningLevel ?? warningLevel;
        final hl = wrdMatch.hfl          ?? hfl;
        final risk = wrdMatch.riskLabel;
        _log('✓ $city | src=WRD_BIHAR | risk=$risk | level=${lv}m');
        return LiveRiverResult(
          station: RiverStation(
            city:         city,
            state:        state,
            river:        wrdMatch.river.isNotEmpty ? wrdMatch.river : river,
            station:      wrdMatch.site,
            current:      lv,
            warning:      wl,
            danger:       dl,
            hfl:          hl,
            flowRate:     null,
            trend:        wrdMatch.trend?.toUpperCase(),
            liveStatus:   risk,
            lastUpdated:  wrdMatch.fetchedAt.toIso8601String(),
            dataSource:   'WRD_BIHAR',
            isLive:       true,
          ),
          source:      'WRD_BIHAR',
          confidence:  0.95,
          mlRiskLevel: risk,
          mlFloodProb: _riskToProb(risk),
          rawTimestamp: wrdMatch.fetchedAt.toIso8601String(),
        );
      }
    } catch (e) {
      _log('WRD Bihar error for $city: $e');
    }

    // ── Source 2: GloFAS / Open-Meteo (via LiveFetchEngine) ──────────────
    try {
      final fd = _lfe.dataForCity(city);
      if (fd != null) {
        final lv   = fd.currentLevel ?? 0.0;
        final wlEf = fd.warningLevel > 0 ? fd.warningLevel : warningLevel;
        final dlEf = fd.dangerLevel  > 0 ? fd.dangerLevel  : dangerLevel;
        final risk = fd.riskLevel ?? 'LOW';
        _log('✓ $city | src=GLOFAS | risk=$risk | flow=${fd.flowRate} m³/s');
        return LiveRiverResult(
          station: RiverStation(
            city:         city,
            state:        state,
            river:        river,
            station:      '$city GloFAS',
            current:      lv,
            warning:      wlEf,
            danger:       dlEf,
            hfl:          hfl,
            flowRate:     fd.flowRate,
            rainfallLastHour: fd.rainfall24h != null && fd.rainfall24h! > 0
                ? fd.rainfall24h! / 24 : null,
            trend:        _deriveTrend(lv, wlEf, dlEf),
            liveStatus:   risk,
            lastUpdated:  fd.lastUpdated.toIso8601String(),
            dataSource:   'GLOFAS',
            isLive:       true,
          ),
          source:      'GLOFAS',
          confidence:  0.75,
          mlRiskLevel: risk,
          mlFloodProb: _riskToProb(risk),
          isStale: DateTime.now().difference(fd.lastUpdated) >
                   const Duration(minutes: 30),
        );
      }
    } catch (e) {
      _log('GloFAS error for $city: $e');
    }

    // ── NO_DATA ───────────────────────────────────────────────────────────
    _log('NO_DATA: $city');
    return LiveRiverResult(
      station: RiverStation(
        city: city, state: state, river: river,
        station:    '$city WRD Gauge',
        current:    0,
        warning:    warningLevel,
        danger:     dangerLevel,
        hfl:        hfl,
        dataSource: 'NO_DATA',
        isLive:     false,
      ),
      source:     'NO_DATA',
      confidence: 0.0,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _deriveTrend(double lv, double wl, double dl) {
    if (dl > 0 && lv >= dl * 0.97) return 'RISING';
    if (wl > 0 && lv >= wl)        return 'STEADY';
    if (wl > 0 && lv < wl * 0.80)  return 'FALLING';
    return 'STEADY';
  }

  double _riskToProb(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return 0.92;
      case 'HIGH':     return 0.72;
      case 'MODERATE': return 0.48;
      default:         return 0.15;
    }
  }

  static double _fp(dynamic v) =>
      v == null ? 0.0 : (double.tryParse(v.toString().trim()) ?? 0.0);
}
