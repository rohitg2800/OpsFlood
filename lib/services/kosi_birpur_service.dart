// lib/services/kosi_birpur_service.dart  v3.0
//
// Live Kosi @ Birpur barrage gauge data
// ─────────────────────────────────────────────────────────────────────────────
// SOURCE PRIORITY — all fired in parallel, first non-null wins:
//
//  A. BEAMS Bihar JSON (api.beams.bihar.gov.in)          — fastest
//  B. BefiqrCwcService (BEAMS → befiqr fallback)          — fast
//  C. India-WRIS v2 REST (indiawris.gov.in)               — reliable
//  D. CWC FFS endpoint 1 (getFloodData.php)               — slow/blocked
//  E. CWC FFS endpoint 2 (api/station/KOSI-BIRPUR)        — slow/blocked
//
// All 5 are raced with Future.any() — total wait = max(individual)
// not sum. D & E are expected to timeout; they cost 0 extra time because
// A/B/C win first in practice.
//
// DATUM: All levels in CWC AMSL metres.
//   Birpur WRD local danger = 74.70 m
//   Birpur CWC AMSL danger  = 214.00 m  (offset +139.30)
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'befiqr_cwc_service.dart';

// ── Official CWC AMSL thresholds for Kosi @ Birpur ─────────────────────────

const double kBirpurDangerLevel  = 214.00;
const double kBirpurWarningLevel = 213.00;
const double kBirpurNormalLevel  = 210.00;
const double kBirpurHFL          = 215.32;
const double kBirpurWarningDischarge = 22000.0;
const double kBirpurDangerDischarge  = 27014.0;

// ───────────────────────────────────────────────────────────────────────────

class KosiBirpurReading {
  final double levelM;
  final double dangerLevel;
  final double warningLevel;
  final double? dischargeCumecs;
  final double? levelWrd;
  final String? trend;
  final DateTime observedAt;
  final String  source;

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
        fetchedAt:    observedAt,
      );
}

// ── KosiBirpurService ───────────────────────────────────────────────────────

class KosiBirpurService {
  static const _raceTimeout = Duration(seconds: 7);

  final BefiqrCwcService _cwcSvc = BefiqrCwcService();

  /// Returns the best available live reading for Kosi @ Birpur.
  /// Fires all 5 sources in parallel — first non-null live result wins.
  /// Never throws — falls back to seed if every future returns null or errors.
  Future<KosiBirpurReading> fetchLive() async {
    // Build all 5 source futures. Each returns null on failure — never throws.
    final futures = <Future<KosiBirpurReading?>>[
      _tryBeamsDirect(),      // A — fastest
      _tryFromCwcService(),   // B — BEAMS via befiqr fallback
      _tryWRIS(),             // C — India-WRIS v2
      _tryFFSEndpoint('https://ffs.india-water.gov.in/ffs/pages/getFloodData.php'),   // D
      _tryFFSEndpoint('https://ffs.india-water.gov.in/ffs/api/station/KOSI-BIRPUR'), // E
    ];

    // Race: first non-null result wins. We use a Completer so we can
    // resolve on the first non-null and let the rest finish silently.
    final completer = Completer<KosiBirpurReading?>();
    int pending = futures.length;

    for (final f in futures) {
      f.then((result) {
        if (result != null && !completer.isCompleted) {
          completer.complete(result);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null); // all failed
          }
        }
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    final result = await completer.future.timeout(
      _raceTimeout,
      onTimeout: () => null,
    );

    if (result != null) return result;
    return _seed();
  }

  // ── Source A: BEAMS Bihar direct JSON ─────────────────────────────────────
  // BEAMS exposes a direct JSON endpoint that doesn't go through the
  // befiqr proxy. Faster and more reliable on Indian networks.

  Future<KosiBirpurReading?> _tryBeamsDirect() async {
    final urls = [
      'https://api.beams.bihar.gov.in/api/stations/live?river=KOSI&site=BIRPUR',
      'https://api.beams.bihar.gov.in/public/flood/stations?river=kosi',
    ];
    for (final url in urls) {
      try {
        final resp = await http.get(
          Uri.parse(url),
          headers: {
            'Accept':     'application/json',
            'User-Agent': 'OpsFlood/3.0',
          },
        ).timeout(const Duration(seconds: 5));

        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          // Handle both array and object responses
          final List<dynamic> items = body is List
              ? body
              : (body['data'] as List? ?? body['stations'] as List? ?? []);

          for (final item in items) {
            final name = (item['site'] ?? item['station_name'] ?? '').toString().toLowerCase();
            if (!name.contains('birpur')) continue;
            final level = _parseDbl(item['current_level'] ?? item['water_level'] ?? item['wl']);
            if (level != null && level > 100) {
              debugPrint('[KosiBirpur] BEAMS-direct ✅ $level m');
              return KosiBirpurReading(
                levelM:       level,
                dangerLevel:  _parseDbl(item['danger_level']) ?? kBirpurDangerLevel,
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

  // ── Source B: BefiqrCwcService (BEAMS → befiqr → internal seed) ──────────

  Future<KosiBirpurReading?> _tryFromCwcService() async {
    try {
      final stations = await _cwcSvc.fetchStations()
          .timeout(const Duration(seconds: 6));
      final birpur = stations.where((s) =>
          s.river.toLowerCase().contains('kosi') &&
          s.site.toLowerCase().contains('birpur')).toList();

      if (birpur.isNotEmpty) {
        final s = birpur.first;
        if (s.source == 'SEED') return null;
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

  // ── Source C: India-WRIS v2 ────────────────────────────────────────────────
  // Station GD_00441 = Birpur (CWC gauge on Kosi)
  // v2 endpoint changed from /wris/api/v1/ to /WRIS/API/ in 2025.

  Future<KosiBirpurReading?> _tryWRIS() async {
    final uris = [
      // v2 (2025+ correct path)
      'https://indiawris.gov.in/WRIS/API/hydrograph?station_id=GD_00441&parameter=WL&days=1',
      // v1 legacy fallback
      'https://indiawris.gov.in/wris/api/v1/hydrograph?station_id=GD_00441&parameter=WL&duration=1',
      // discharge fallback
      'https://indiawris.gov.in/WRIS/API/hydrograph?station_id=GD_00441&parameter=Q&days=1',
    ];
    for (final u in uris) {
      try {
        final resp = await http.get(
          Uri.parse(u),
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.0'},
        ).timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final list = (body['data'] as List? ?? body['hydrograph'] as List?);
          if (list != null && list.isNotEmpty) {
            final latest = list.last as Map<String, dynamic>;
            final val    = _parseDbl(latest['value'] ?? latest['wl'] ?? latest['level']);
            final obsAt  = DateTime.tryParse(latest['date']?.toString() ?? latest['time']?.toString() ?? '') ?? DateTime.now();
            if (val != null && val > 100) {
              // WL in AMSL — good
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
              // Discharge — convert to stage
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

  // ── Source D/E: CWC FFS — single-endpoint wrapper ─────────────────────────
  // Called twice in parallel from fetchLive() with different URLs.
  // Expected to timeout on Indian mobile networks — logged as info only.

  Future<KosiBirpurReading?> _tryFFSEndpoint(String url) async {
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'Referer':      'https://ffs.india-water.gov.in/',
          'User-Agent':   'Mozilla/5.0 (OpsFlood/3.0)',
        },
        body: jsonEncode({
          'station_id': 'BR-1',
          'river':      'KOSI',
          'state':      'BIHAR',
        }),
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? body;
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
      // Expected on Indian networks — FFS is geoblocked. Log as info.
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

  // ── Utilities ─────────────────────────────────────────────────────────────

  static double _dischargeToLevel(double q) {
    const qDesign = kBirpurDangerDischarge;
    final ratio   = (q / qDesign).clamp(0.0, 1.2);
    return 205.0 + 9.0 * (ratio < 1 ? ratio : 1.0);
  }

  static double? _parseDbl(dynamic v) {
    if (v == null) return null;
    if (v is num)  return v.toDouble();
    return double.tryParse(
        v.toString().replaceAll(RegExp(r'[^\d.]'), '').trim());
  }
}
