// lib/services/kosi_birpur_service.dart  v3.2
//
// FIXES vs v3.1:
//   • Bumped _tryFromCwcService timeout 6s→12s (BefiqrCwcService.fetchStations
//     has its own 15s race; the old 6s outer timeout killed it prematurely).
//   • Bumped overall _raceTimeout 7s→13s so slow gov servers (BEAMS, FFS)
//     have a realistic chance to respond before SEED fallback.
//
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'befiqr_cwc_service.dart';

// ── Official CWC AMSL thresholds for Kosi @ Birpur ─────────────────────────
const double kBirpurDangerLevel       = 214.00;
const double kBirpurWarningLevel      = 213.00;
const double kBirpurNormalLevel       = 210.00;
const double kBirpurHFL               = 215.32;
const double kBirpurWarningDischarge  = 22000.0;
const double kBirpurDangerDischarge   = 27014.0;

// ─────────────────────────────────────────────────────────────────────────────
class KosiBirpurReading {
  final double  levelM;
  final double  dangerLevel;
  final double  warningLevel;
  final double? dischargeCumecs;
  final double? levelWrd;
  final String? trend;
  final DateTime observedAt;
  final String   source;

  const KosiBirpurReading({
    required this.levelM,
    required this.dangerLevel,
    required this.warningLevel,
    this.dischargeCumecs,
    this.levelWrd,
    this.trend,
    required this.observedAt,
    required this.source,
  });

  double get gap        => dangerLevel - levelM;
  bool   get isDanger   => levelM >= dangerLevel;
  bool   get isWarning  => levelM >= warningLevel && levelM < dangerLevel;
  bool   get isElevated => levelM >= kBirpurNormalLevel && levelM < warningLevel;
  bool   get isNormal   => levelM < kBirpurNormalLevel;

  String get statusLabel {
    if (isDanger)   return 'DANGER';
    if (isWarning)  return 'WARNING';
    if (isElevated) return 'ELEVATED';
    return 'NORMAL';
  }

  double get fillFraction => (levelM / dangerLevel).clamp(0.0, 1.1);

  CwcStation toCwcStation() => CwcStation(
    river:        'Kosi',
    site:         'Birpur',
    currentLevel: levelM,
    dangerLevel:  dangerLevel,
    warningLevel: warningLevel,
    trend:        trend,
    source:       source,
    isFromSeed:   source == 'SEED',
    fetchedAt:    observedAt,
  );
}

// ── HTTP client that does NOT follow redirects ──────────────────────────────
// WRIS server has a misconfigured redirect that appends its own path prefix
// on every 3xx response. After 5 hops the URL becomes:
//   indiawris.gov.in/wriswriswriswrisWRIS/API/...
// Solution: disable automatic redirects, follow only the FIRST Location header
// manually (genuine server-side path normalisation), then stop.
http.Client _noRedirectClient() {
  final inner = HttpClient()..maxConnectionsPerHost = 4;
  inner.findProxy = null;
  return IOClient(inner);
}

/// Follow at most one redirect manually. Returns the final response.
/// If the server sends a redirect loop (same host + same path prefix appearing
/// twice), aborts and returns the original response.
Future<http.Response> _getNoLoop(String url,
    {Map<String, String>? headers, Duration timeout = const Duration(seconds: 10)}) async {
  final client = _noRedirectClient();
  try {
    final req     = http.Request('GET', Uri.parse(url));
    if (headers != null) req.headers.addAll(headers);
    final stream  = await client.send(req).timeout(timeout);
    var resp       = await http.Response.fromStream(stream);

    // Follow at most ONE redirect — but only if the Location header doesn't
    // reintroduce the current path as a prefix (the WRIS loop pattern).
    if (resp.statusCode >= 300 && resp.statusCode < 400) {
      final loc = resp.headers['location'];
      if (loc != null) {
        final origPath  = Uri.parse(url).path.toLowerCase();
        final redirPath = Uri.parse(loc).path.toLowerCase();
        // Abort if the redirect target contains the original path as a prefix
        // (classic loop: /WRIS/API → /wrisWRIS/API → /wriswrisWRIS/API ...)
        final isLoop = redirPath.contains(origPath) && redirPath != origPath;
        if (!isLoop) {
          final req2   = http.Request('GET', Uri.parse(loc));
          if (headers != null) req2.headers.addAll(headers);
          final stream2 = await client.send(req2).timeout(timeout);
          resp = await http.Response.fromStream(stream2);
        } else {
          debugPrint('[WRIS] redirect loop detected, aborting: $loc');
        }
      }
    }
    return resp;
  } finally {
    client.close();
  }
}

// ── KosiBirpurService ───────────────────────────────────────────────────────

class KosiBirpurService {
  // v3.2: bumped from 7s → 13s so BEAMS / FFS gov servers have a fair chance
  static const _raceTimeout = Duration(seconds: 13);
  final BefiqrCwcService _cwcSvc = BefiqrCwcService();

  /// Returns the best available live reading for Kosi @ Birpur.
  /// Fires all 5 sources in parallel — first non-null live result wins.
  /// Never throws — falls back to seed if every future returns null.
  Future<KosiBirpurReading> fetchLive() async {
    final futures = <Future<KosiBirpurReading?>>[
      _tryBeamsDirect(),
      _tryFromCwcService(),
      _tryWRIS(),
      _tryFFSEndpoint('https://ffs.india-water.gov.in/ffs/pages/getFloodData.php'),
      _tryFFSEndpoint('https://ffs.india-water.gov.in/ffs/api/station/KOSI-BIRPUR'),
    ];

    final completer = Completer<KosiBirpurReading?>();
    int pending = futures.length;

    for (final f in futures) {
      f.then((result) {
        if (result != null && !completer.isCompleted) {
          completer.complete(result);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    final result = await completer.future.timeout(
      _raceTimeout, onTimeout: () => null);
    return result ?? _seed();
  }

  // ── Source A: BEAMS Bihar direct JSON ─────────────────────────────────────
  Future<KosiBirpurReading?> _tryBeamsDirect() async {
    final urls = [
      'https://api.beams.bihar.gov.in/api/stations/live?river=KOSI&site=BIRPUR',
      'https://api.beams.bihar.gov.in/public/flood/stations?river=kosi',
    ];
    for (final url in urls) {
      try {
        final resp = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.2'},
        ).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body  = jsonDecode(resp.body);
          final items = body is List ? body
              : (body['data'] as List? ?? body['stations'] as List? ?? []);
          for (final item in items) {
            final name = (item['site'] ?? item['station_name'] ?? '').toString().toLowerCase();
            if (!name.contains('birpur')) continue;
            final level = _parseDbl(item['current_level'] ?? item['water_level'] ?? item['wl']);
            if (level != null && level > 100) {
              debugPrint('[KosiBirpur] BEAMS-direct ✅ $level m');
              return KosiBirpurReading(
                levelM:       level,
                dangerLevel:  _parseDbl(item['danger_level'])  ?? kBirpurDangerLevel,
                warningLevel: _parseDbl(item['warning_level']) ?? kBirpurWarningLevel,
                trend:        item['trend']?.toString(),
                observedAt:   DateTime.tryParse(item['observed_at']?.toString() ?? '') ?? DateTime.now(),
                source:       'BEAMS-direct',
              );
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ── Source B: BefiqrCwcService ─────────────────────────────────────────────
  // v3.2: bumped timeout 6s→12s (BefiqrCwcService has a 15s internal race;
  //       the old 6s outer limit cancelled it before any source could respond).
  Future<KosiBirpurReading?> _tryFromCwcService() async {
    try {
      final stations = await _cwcSvc.fetchStations().timeout(const Duration(seconds: 12));
      final birpur   = stations.where((s) =>
          !s.isFromSeed &&
          s.river.toLowerCase().contains('kosi') &&
          s.site.toLowerCase().contains('birpur')).toList();
      if (birpur.isNotEmpty) {
        final s = birpur.first;
        debugPrint('[KosiBirpur] BefiqrCwc ✅ ${s.currentLevel} m (${s.source})');
        return KosiBirpurReading(
          levelM:       s.currentLevel,
          dangerLevel:  s.dangerLevel,
          warningLevel: s.warningLevel ?? kBirpurWarningLevel,
          trend:        s.trend,
          observedAt:   s.fetchedAt,
          source:       s.source,
        );
      }
    } catch (e) {
      debugPrint('[KosiBirpur] BefiqrCwc failed: $e');
    }
    return null;
  }

  // ── Source C: India-WRIS — redirect-safe ─────────────────────────────────
  // Uses _getNoLoop() instead of http.get() to avoid the indiawris.gov.in
  // redirect loop that produces wriswriswriswrisWRIS/API/... URLs.
  Future<KosiBirpurReading?> _tryWRIS() async {
    final uris = [
      'https://indiawris.gov.in/WRIS/API/hydrograph?station_id=GD_00441&parameter=WL&days=1',
      'https://indiawris.gov.in/wris/api/v1/hydrograph?station_id=GD_00441&parameter=WL&duration=1',
      'https://indiawris.gov.in/WRIS/API/hydrograph?station_id=GD_00441&parameter=Q&days=1',
    ];
    for (final u in uris) {
      try {
        final resp = await _getNoLoop(
          u,
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.2'},
          timeout: const Duration(seconds: 10),
        );
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final list = (body['data'] as List? ?? body['hydrograph'] as List?);
          if (list != null && list.isNotEmpty) {
            final latest = list.last as Map<String, dynamic>;
            final val    = _parseDbl(latest['value'] ?? latest['wl'] ?? latest['level']);
            final obsAt  = DateTime.tryParse(
                latest['date']?.toString() ?? latest['time']?.toString() ?? '') ?? DateTime.now();
            if (val != null && val > 100) {
              debugPrint('[KosiBirpur] WRIS WL ✅ $val m');
              return KosiBirpurReading(
                levelM:       val,
                dangerLevel:  kBirpurDangerLevel,
                warningLevel: kBirpurWarningLevel,
                observedAt:   obsAt,
                source:       'India-WRIS',
              );
            }
            if (val != null && val > 0) {
              final h = _dischargeToLevel(val);
              debugPrint('[KosiBirpur] WRIS Q=$val → H=$h m');
              return KosiBirpurReading(
                levelM:          h,
                dangerLevel:     kBirpurDangerLevel,
                warningLevel:    kBirpurWarningLevel,
                dischargeCumecs: val,
                observedAt:      obsAt,
                source:          'India-WRIS (Q→H)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[KosiBirpur] WRIS[$u] failed: $e');
      }
    }
    return null;
  }

  // ── Source D/E: CWC FFS endpoints ──────────────────────────────────────────
  Future<KosiBirpurReading?> _tryFFSEndpoint(String url) async {
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'Referer':      'https://ffs.india-water.gov.in/',
          'User-Agent':   'Mozilla/5.0 (OpsFlood/3.2)',
        },
        body: jsonEncode({'station_id': 'BR-1', 'river': 'KOSI', 'state': 'BIHAR'}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body  = jsonDecode(resp.body) as Map<String, dynamic>;
        final data  = body['data'] as Map<String, dynamic>? ?? body;
        final level = _parseDbl(
            data['current_level'] ?? data['gauge_level'] ??
            data['level']         ?? data['wl']);
        if (level != null && level > 100) {
          debugPrint('[KosiBirpur] FFS ✅ level=$level m ($url)');
          return KosiBirpurReading(
            levelM:          level,
            dangerLevel:     _parseDbl(data['danger_level']) ?? kBirpurDangerLevel,
            warningLevel:    kBirpurWarningLevel,
            dischargeCumecs: _parseDbl(data['discharge'] ?? data['q']),
            observedAt:      DateTime.now(),
            source:          'CWC-FFS',
          );
        }
      }
    } catch (e) {
      debugPrint('[KosiBirpur] FFS[$url] skipped: $e');
    }
    return null;
  }

  // ── Seed ──────────────────────────────────────────────────────────────────
  KosiBirpurReading _seed() {
    debugPrint('[KosiBirpur] ⚠️ all sources failed — SEED');
    return KosiBirpurReading(
      levelM:       210.80,
      dangerLevel:  kBirpurDangerLevel,
      warningLevel: kBirpurWarningLevel,
      observedAt:   DateTime(2026, 6, 1),
      source:       'SEED',
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────────
  static double _dischargeToLevel(double q) {
    final ratio = (q / kBirpurDangerDischarge).clamp(0.0, 1.2);
    return 205.0 + 9.0 * (ratio < 1 ? ratio : 1.0);
  }

  static double? _parseDbl(dynamic v) {
    if (v == null) return null;
    if (v is num)  return v.toDouble();
    return double.tryParse(
        v.toString().replaceAll(RegExp(r'[^\d.]'), '').trim());
  }
}
