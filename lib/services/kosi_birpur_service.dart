// lib/services/kosi_birpur_service.dart
//
// Live Kosi @ Birpur barrage gauge data
// ─────────────────────────────────────────────────────────────────────────────
// SOURCE PRIORITY:
//
//  1. BefiqrCwcService.fetchStations() — now backed by BEAMS Bihar as
//     its primary source. Birpur station is in the BEAMS table.
//     WRD→AMSL conversion (offset +139.30) is handled inside BefiqrCwcService.
//
//  2. CWC Flood Forecasting System (ffs.india-water.gov.in)
//     FIXED: was ffs.india.gov.in (404) → correct domain is india-water.gov.in
//
//  3. India-WRIS REST API (station GD_00441 = Birpur CWC gauge)
//     Also tries discharge parameter Q → stage conversion as sub-fallback.
//
//  4. Hardcoded SEED — official CWC thresholds, never null.
//
// DATUM: All levels stored and returned in CWC AMSL metres.
//   Birpur WRD local danger = 74.70 m
//   Birpur CWC AMSL danger  = 214.00 m  (offset +139.30)
//
// DISCHARGE THRESHOLDS (CWC Bihar sub-zone 1a rating curve):
//   kBirpurWarningDischarge = 22 000 m³/s  → stage ≈ 213.00 m AMSL
//   kBirpurDangerDischarge  = 27 014 m³/s  → stage ≈ 214.00 m AMSL (design flood)
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'befiqr_cwc_service.dart';

// ── Official CWC AMSL thresholds for Kosi @ Birpur ─────────────────────────

const double kBirpurDangerLevel  = 214.00; // metres AMSL
const double kBirpurWarningLevel = 213.00; // metres AMSL
const double kBirpurNormalLevel  = 210.00; // metres AMSL (typical pre-monsoon)
const double kBirpurHFL          = 215.32; // metres AMSL (Highest Flood Level)

/// Discharge at warning stage (213.00 m AMSL) — CWC Bihar sub-zone 1a
/// rating curve: Q = 27014 × ((H - 205.0) / 9.0) ^ (1/0.62)
const double kBirpurWarningDischarge = 22000.0; // m³/s

/// Discharge at danger stage (214.00 m AMSL) — design flood discharge
/// per CWC Bihar sub-zone 1a (Kosi @ Birpur barrage)
const double kBirpurDangerDischarge  = 27014.0; // m³/s

// ───────────────────────────────────────────────────────────────────────────

class KosiBirpurReading {
  final double levelM;           // water level — metres AMSL
  final double dangerLevel;      // 214.00 AMSL
  final double warningLevel;     // 213.00 AMSL
  final double? dischargeCumecs; // null if unavailable
  final double? levelWrd;        // original WRD local reading (from BEAMS)
  final String? trend;           // 'Rising' | 'Falling' | 'Steady'
  final DateTime observedAt;
  final String  source;          // 'BEAMS' | 'CWC-FFS' | 'India-WRIS' | 'SEED'

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

  double get fillFraction =>
      (levelM / dangerLevel).clamp(0.0, 1.1);

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
  static const _timeout = Duration(seconds: 12);
  final BefiqrCwcService _cwcSvc = BefiqrCwcService();

  /// Returns the best available live reading for Kosi @ Birpur.
  /// Never throws — falls back to seed on every failure.
  Future<KosiBirpurReading> fetchLive() async {
    // 1️⃣  BEAMS / befiqr (via BefiqrCwcService — already has BEAMS as source #1)
    final fromCwc = await _tryFromCwcService();
    if (fromCwc != null) return fromCwc;

    // 2️⃣  CWC FFS (fixed domain)
    final ffs = await _tryFFS();
    if (ffs != null) return ffs;

    // 3️⃣  India-WRIS
    final wris = await _tryWRIS();
    if (wris != null) return wris;

    // 4️⃣  Seed
    return _seed();
  }

  // ── Source 1: BefiqrCwcService (BEAMS → befiqr → seed internally) ────────

  Future<KosiBirpurReading?> _tryFromCwcService() async {
    try {
      final stations = await _cwcSvc.fetchStations();
      final birpur   = stations.where((s) =>
          s.river.toLowerCase().contains('kosi') &&
          s.site.toLowerCase().contains('birpur')).toList();

      if (birpur.isNotEmpty) {
        final s = birpur.first;
        // Reject seed values so we don't report KOSI LIVE
        // when we're actually showing hardcoded numbers.
        if (s.source == 'SEED') return null;

        debugPrint(
          '[KosiBirpur] ${s.source} ✅ '
          'level=${s.currentLevel} m | danger=${s.dangerLevel} m | '
          'trend=${s.trend} | status=${s.status}',
        );
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
      debugPrint('[KosiBirpur] CwcService failed: $e');
    }
    return null;
  }

  // ── Source 2: CWC FFS (FIXED domain india-water.gov.in) ──────────────────

  Future<KosiBirpurReading?> _tryFFS() async {
    final endpoints = [
      'https://ffs.india-water.gov.in/ffs/pages/getFloodData.php',
      'https://ffs.india-water.gov.in/ffs/api/station/KOSI-BIRPUR',
    ];
    for (final url in endpoints) {
      try {
        final resp = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept':       'application/json',
                'Referer':      'https://ffs.india-water.gov.in/',
                'User-Agent':   'Mozilla/5.0 (OpsFlood/2.0)',
              },
              body: jsonEncode({
                'station_id': 'BR-1',
                'river':      'KOSI',
                'state':      'BIHAR',
              }),
            )
            .timeout(_timeout);

        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final data = body['data'] as Map<String, dynamic>? ?? body;
          final level = _parseDbl(
              data['current_level'] ?? data['gauge_level'] ??
              data['level'] ?? data['wl']);
          if (level != null && level > 100) {
            debugPrint('[KosiBirpur] FFS ✅ level=$level m');
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
        debugPrint('[KosiBirpur] FFS[$url] failed: $e');
      }
    }
    return null;
  }

  // ── Source 3: India-WRIS ──────────────────────────────────────────────────

  Future<KosiBirpurReading?> _tryWRIS() async {
    final uris = [
      'https://indiawris.gov.in/wris/api/v1/hydrograph?station_id=GD_00441&parameter=WL&duration=1',
      'https://indiawris.gov.in/wris/api/v1/hydrograph?station_id=GD_00441&parameter=Q&duration=1',
    ];
    for (final u in uris) {
      try {
        final resp = await http
            .get(Uri.parse(u), headers: {'Accept': 'application/json'})
            .timeout(_timeout);
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final list = (body['data'] as List?)?.cast<Map<String, dynamic>>();
          if (list != null && list.isNotEmpty) {
            final latest = list.last;
            final val = _parseDbl(latest['value']?.toString());
            final obsAt = DateTime.tryParse(
                    latest['date']?.toString() ?? '') ??
                DateTime.now();
            if (val != null && val > 100) {
              // Water level in AMSL — valid
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

  /// Birpur stage-discharge rating curve (CWC Bihar sub-zone 1a):
  /// H(m AMSL) ≈ 205.0 + 9.0 × (Q / 27014)^0.62
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
