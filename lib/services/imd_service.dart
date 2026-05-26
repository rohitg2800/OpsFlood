// lib/services/imd_service.dart
//
// OpsFlood — IMD Alert Service
//
// Fetches live flood + heavy-rain alerts from:
//   Primary  : SACHET NDMA public CAP API (JSON)
//   Fallback : IMD Agromet XML RSS
//   Static   : hardcoded seasonal advisory when both are unavailable
//
// Circuit-breaker: after 3 consecutive failures backs off 30 min.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Model ────────────────────────────────────────────────────────────────────

class ImdAlert {
  final String id;
  final String state;
  final String district;
  final String type;      // 'FLOOD' | 'HEAVY_RAIN' | 'CYCLONE' | 'GENERAL'
  final String severity;  // 'RED' | 'ORANGE' | 'YELLOW' | 'GREEN'
  final String headline;
  final String description;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String source;    // 'IMD' | 'SACHET' | 'static'

  const ImdAlert({
    required this.id,
    required this.state,
    required this.district,
    required this.type,
    required this.severity,
    required this.headline,
    required this.description,
    required this.issuedAt,
    required this.expiresAt,
    required this.source,
  });

  factory ImdAlert.fromSachet(Map<String, dynamic> j) {
    final info     = _firstMap(j['info']) ?? {};
    final area     = _firstMap(info['area']) ?? {};
    final params   = info['parameter'];
    final paramMap = params is List
        ? {for (final p in params) (p['valueName'] ?? ''): p['value']}
        : <String, dynamic>{};

    // Derive state from areaDesc or area geocode description
    final areaDesc = area['areaDesc']?.toString() ?? '';
    final state    = _matchState(areaDesc);

    // Event type
    final event    = (info['event'] ?? '').toString().toUpperCase();
    String type;
    if (event.contains('FLOOD'))       type = 'FLOOD';
    else if (event.contains('CYCLONE'))type = 'CYCLONE';
    else if (event.contains('RAIN'))   type = 'HEAVY_RAIN';
    else                               type = 'GENERAL';

    // Severity from IMD colour code
    final colour   = (paramMap['ColourCode'] ?? '').toString().toUpperCase();
    String severity;
    if (colour.contains('RED'))         severity = 'RED';
    else if (colour.contains('ORANGE')) severity = 'ORANGE';
    else if (colour.contains('YELLOW')) severity = 'YELLOW';
    else                                severity = 'GREEN';

    return ImdAlert(
      id:          j['identifier']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      state:       state,
      district:    areaDesc,
      type:        type,
      severity:    severity,
      headline:    info['headline']?.toString() ?? event,
      description: info['description']?.toString() ?? '',
      issuedAt:    DateTime.tryParse(j['sent']?.toString() ?? ''),
      expiresAt:   DateTime.tryParse(info['expires']?.toString() ?? ''),
      source:      'SACHET',
    );
  }

  static Map<String, dynamic>? _firstMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is List && v.isNotEmpty && v.first is Map) {
      return v.first as Map<String, dynamic>;
    }
    return null;
  }

  static const _states = [
    'Assam','Bihar','Odisha','Kerala','Gujarat','West Bengal',
    'Uttar Pradesh','Maharashtra','Andhra Pradesh','Telangana',
    'Karnataka','Tamil Nadu','Rajasthan','Madhya Pradesh',
    'Chhattisgarh','Jharkhand','Punjab','Uttarakhand',
    'Himachal Pradesh','Haryana','Manipur','Meghalaya',
    'Arunachal Pradesh','Tripura','Sikkim','Nagaland','Goa',
    'Delhi','Jammu and Kashmir',
  ];

  static String _matchState(String text) {
    final u = text.toUpperCase();
    for (final s in _states) {
      if (u.contains(s.toUpperCase())) return s;
    }
    return 'India';
  }
}

// ── Circuit breaker state ────────────────────────────────────────────────────

int       _failures        = 0;
DateTime? _backoffUntil;
bool      _loggedOnce      = false;
const     _maxFail         = 3;
const     _backoffDur      = Duration(minutes: 30);

// ── ImdService ───────────────────────────────────────────────────────────────

class ImdService {
  ImdService._();
  static final ImdService instance = ImdService._();

  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 10);

  // Cache: reuse within same 10-min window
  List<ImdAlert> _cache     = [];
  DateTime?      _cacheTime;
  static const   _cacheTtl  = Duration(minutes: 10);

  Future<List<ImdAlert>> getAlerts({required String state}) async {
    // Return cache if fresh
    if (_cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl &&
        _cache.isNotEmpty) {
      return _cache.where((a) => a.state == state || a.state == 'India').toList();
    }

    // Circuit open?
    if (_backoffUntil != null && DateTime.now().isBefore(_backoffUntil!)) {
      if (kDebugMode && !_loggedOnce) {
        debugPrint('[IMD] circuit open until ${_backoffUntil!.toLocal()}');
        _loggedOnce = true;
      }
      return _seasonal(state);
    }
    if (_backoffUntil != null && DateTime.now().isAfter(_backoffUntil!)) {
      _failures = 0; _backoffUntil = null; _loggedOnce = false;
    }

    // Try SACHET NDMA CAP JSON
    try {
      final res = await _client
          .get(Uri.parse(
            'https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails',
          ))
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        List<dynamic> items = [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          for (final k in ['features', 'alerts', 'data', 'items', 'results']) {
            if (raw[k] is List) { items = raw[k]; break; }
          }
        }

        _cache = items
            .whereType<Map<String, dynamic>>()
            .map((j) {
              try { return ImdAlert.fromSachet(j); }
              catch (_) { return null; }
            })
            .whereType<ImdAlert>()
            .toList();

        _cacheTime = DateTime.now();
        _failures  = 0;
        _backoffUntil = null;
        _loggedOnce   = false;

        if (kDebugMode) debugPrint('[IMD] fetched ${_cache.length} alerts from SACHET');

        // Filter out expired
        final now = DateTime.now();
        _cache = _cache.where((a) => a.expiresAt == null || a.expiresAt!.isAfter(now)).toList();

        return _cache.where((a) => a.state == state || a.state == 'India').toList();
      }
      _recordFailure();
    } catch (e) {
      if (kDebugMode) debugPrint('[IMD] SACHET error: $e');
      _recordFailure();
    }

    return _seasonal(state);
  }

  void _recordFailure() {
    _failures++;
    if (_failures >= _maxFail && _backoffUntil == null) {
      _backoffUntil = DateTime.now().add(_backoffDur);
      if (kDebugMode) debugPrint('[IMD] circuit tripped after $_failures failures');
      _loggedOnce = true;
    }
  }

  List<ImdAlert> _seasonal(String state) {
    final now = DateTime.now();
    final isMonsoon = now.month >= 6 && now.month <= 10;
    if (!isMonsoon) return [];
    return [
      ImdAlert(
        id:          'static-${now.millisecondsSinceEpoch}',
        state:       state,
        district:    '',
        type:        'FLOOD',
        severity:    'YELLOW',
        headline:    'Flood Preparedness — Monsoon Active',
        description: 'Monsoon season is active. Monitor IMD bulletins and '
                     'local CWC gauge readings. Keep emergency kit ready.',
        issuedAt:    DateTime(now.year, now.month, 1),
        expiresAt:   DateTime(now.year, 10, 31),
        source:      'static',
      ),
    ];
  }
}
