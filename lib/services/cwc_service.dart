/// CWC Real-Time River Level Service
/// Mirrors the logic from OpsFlood/backend/cwc_scraper.py + app.py
/// Endpoint: https://ffs.india-water.gov.in/ffm/api/station-water-level-above-warning/
/// Falls back to tactical (seeded) telemetry on failure — same algorithm as backend.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

const String _cwcEndpoint =
    'https://ffs.india-water.gov.in/ffm/api/station-water-level-above-warning/';

const Duration _connectTimeout = Duration(seconds: 5);
const Duration _readTimeout = Duration(seconds: 12);

/// A single CWC station reading.
class CwcStation {
  final String stationName;
  final String stateName;
  final String riverName;
  final double riverLevel;
  final double warningLevel;
  final double dangerLevel;
  final double flowRate;
  final double rainfallLastHour;
  final String status;
  final String trend;
  final String source;
  final DateTime lastUpdate;

  const CwcStation({
    required this.stationName,
    required this.stateName,
    required this.riverName,
    required this.riverLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.flowRate,
    required this.rainfallLastHour,
    required this.status,
    required this.trend,
    required this.source,
    required this.lastUpdate,
  });

  double get capacityPercent {
    if (dangerLevel <= 0) return 0;
    return (riverLevel / dangerLevel * 100).clamp(0, 120);
  }

  String get riskLevel {
    if (capacityPercent >= 90) return 'CRITICAL';
    if (capacityPercent >= 70) return 'HIGH';
    if (capacityPercent >= 50) return 'MODERATE';
    return 'LOW';
  }

  Map<String, dynamic> toJson() => {
        'city': stationName,
        'state': stateName,
        'river_name': riverName,
        'current_level': riverLevel,
        'warning_level': warningLevel,
        'danger_level': dangerLevel,
        'flow_rate': flowRate,
        'rainfall_last_hour': rainfallLastHour,
        'status': status,
        'trend': trend,
        'source': source,
        'capacity_percent': capacityPercent,
        'risk_level': riskLevel,
        'last_update': lastUpdate.toIso8601String(),
      };
}

class CwcService {
  CwcService._();
  static final CwcService instance = CwcService._();

  final http.Client _client = http.Client();

  DateTime? _retryAfter;
  String _failureMessage = '';

  // ── Public API ────────────────────────────────────────────────────────────

  Future<List<CwcStation>> getLiveTelemetry({
    String stateName = 'Maharashtra',
    String stationName = 'Kolhapur',
    int limit = 15,
  }) async {
    final targetState   = _normalizeKey(stateName);
    final targetStation = _normalizeKey(stationName);

    try {
      final raw = await _fetchLiveStationFeed();
      final formatted = raw
          .map((site) => _parseSite(site, stateName))
          .whereType<CwcStation>()
          .toList();

      formatted.sort((a, b) {
        final pa = _sitePriority(a, targetState, targetStation);
        final pb = _sitePriority(b, targetState, targetStation);
        if (pa != pb) return pa.compareTo(pb);
        return b.riverLevel.compareTo(a.riverLevel);
      });

      final filtered = formatted
          .where((s) => _sitePriority(s, targetState, targetStation) < 3)
          .take(limit)
          .toList();

      if (filtered.isNotEmpty) return filtered;
      return _buildTacticalTelemetry(
          stateName: stateName, stationName: stationName, limit: limit);
    } catch (_) {
      return _buildTacticalTelemetry(
          stateName: stateName, stationName: stationName, limit: limit);
    }
  }

  Future<double?> getLiveRiverLevel(String stationName) async {
    try {
      final raw = await _fetchLiveStationFeed();
      for (final site in raw) {
        final name = _stationNameFrom(site);
        if (name.toLowerCase().contains(stationName.toLowerCase())) {
          final wl  = _safeFloat(site['warningLevel'] ?? site['warning_level'] ?? site['wl']);
          final abw = _safeFloat(site['value'] ?? site['aboveWarning'] ?? site['above_warning']);
          return wl > 0 ? wl + abw : abw;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<CwcStation>> getAllAboveWarningStations() async {
    try {
      final raw = await _fetchLiveStationFeed();
      return raw
          .map((site) => _parseSite(site, ''))
          .whereType<CwcStation>()
          .where((s) => s.stationName != 'UNKNOWN' && s.stationName.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Network ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchLiveStationFeed() async {
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      throw Exception(_failureMessage.isNotEmpty
          ? _failureMessage
          : 'CWC endpoint on cooldown');
    }

    try {
      final response = await _client
          .get(
            Uri.parse(_cwcEndpoint),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Accept': 'application/json, text/plain, */*',
              'Referer': 'https://ffs.india-water.gov.in/',
            },
          )
          .timeout(_connectTimeout + _readTimeout);

      if (response.statusCode == 404) {
        _rememberFailure('CWC endpoint 404', cooldownSeconds: 900);
        throw Exception('CWC endpoint 404');
      }
      if (response.statusCode >= 400) {
        _rememberFailure('HTTP ${response.statusCode}', cooldownSeconds: 180);
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      final stations = _parseStationFeedPayload(body);
      if (stations.isNotEmpty) {
        _clearFailure();
        return stations;
      }

      _rememberFailure('Empty/unexpected schema', cooldownSeconds: 120);
      throw Exception('Empty station feed');
    } on TimeoutException {
      _rememberFailure('Connect timeout', cooldownSeconds: 300);
      rethrow;
    } catch (e) {
      if (_retryAfter == null) {
        _rememberFailure(e.toString(), cooldownSeconds: 120);
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _parseStationFeedPayload(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      // Try common wrapper keys the CWC API uses
      for (final key in ['data', 'stations', 'results', 'items', 'features']) {
        final inner = payload[key];
        if (inner is List) return inner.whereType<Map<String, dynamic>>().toList();
      }
      // GeoJSON FeatureCollection
      final features = payload['features'];
      if (features is List) {
        return features
            .whereType<Map<String, dynamic>>()
            .map((f) => (f['properties'] as Map<String, dynamic>?) ?? f)
            .toList();
      }
    }
    return [];
  }

  // ── Station name extraction (handles all known CWC API variants) ──────────

  /// The CWC API has returned at least 6 different key names for station name
  /// across different API versions. This covers them all.
  String _stationNameFrom(Map<String, dynamic> site) {
    final raw = site['stationName'] ??
        site['station_name'] ??
        site['StationName'] ??
        site['name'] ??
        site['Name'] ??
        site['basin_name'] ??
        site['BasinName'] ??
        site['gauging_station'] ??
        site['gaugingStation'] ??
        site['station'] ??
        site['title'];
    final s = (raw ?? '').toString().trim();
    return s.isEmpty ? '' : s;
  }

  String _stateNameFrom(Map<String, dynamic> site, String fallback) {
    final raw = site['stateName'] ??
        site['state_name'] ??
        site['StateName'] ??
        site['state'] ??
        site['State'] ??
        site['stateCode'];
    final s = (raw ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _riverNameFrom(Map<String, dynamic> site) {
    final raw = site['riverName'] ??
        site['river_name'] ??
        site['RiverName'] ??
        site['river'] ??
        site['River'] ??
        site['basin'] ??
        site['basinName'];
    return (raw ?? '').toString().trim();
  }

  // ── Parser ────────────────────────────────────────────────────────────────

  CwcStation? _parseSite(Map<String, dynamic> site, String fallbackState) {
    try {
      final stationName = _stationNameFrom(site);
      if (stationName.isEmpty) return null; // skip truly nameless rows

      // Warning level
      final warningLevel = _safeFloat(
          site['warningLevel'] ?? site['warning_level'] ??
          site['WarningLevel'] ?? site['wl'] ?? site['WL']);

      // Danger level — try many aliases used by CWC
      final dangerLevel = _safeFloat(
          site['dangerLevel'] ?? site['danger_level'] ??
          site['DangerLevel'] ?? site['dl'] ?? site['DL'] ??
          site['highFloodLevel'] ?? site['high_flood_level'] ??
          site['hfl'] ?? site['HFL']);

      // Value above warning
      final aboveWarning = _safeFloat(
          site['value'] ?? site['Value'] ??
          site['above_warning'] ?? site['aboveWarning'] ??
          site['levelAboveWarning']);

      // Absolute water level
      double waterLevel;
      if (site.containsKey('waterLevel') || site.containsKey('water_level') ||
          site.containsKey('currentLevel') || site.containsKey('current_level')) {
        waterLevel = _safeFloat(
            site['waterLevel'] ?? site['water_level'] ??
            site['currentLevel'] ?? site['current_level']);
      } else {
        // compute from warning + above
        waterLevel = warningLevel > 0 ? warningLevel + aboveWarning : aboveWarning;
      }

      // If dangerLevel still 0, derive it from warningLevel using the CWC
      // typical ratio (danger ≈ warning + 10-15%) or state default
      final effectiveDanger = dangerLevel > 0
          ? dangerLevel
          : warningLevel > 0
              ? double.parse((warningLevel * 1.12).toStringAsFixed(2))
              : 0.0;

      final rainfall = _safeFloat(
          site['rainfall'] ?? site['rainfallLastHour'] ??
          site['rainfall1Hr'] ?? site['rainfall_1hr'] ??
          site['rain'] ?? site['Rain']);

      final statusLabel = _statusFromLevels(waterLevel, warningLevel, effectiveDanger);

      // Trend — normalise whatever string CWC sends
      final rawTrend = (site['trend'] ?? site['Trend'] ?? site['trendIndicator'] ?? '').toString().toUpperCase();
      final trend = rawTrend.contains('RIS') ? 'RISING'
          : rawTrend.contains('FAL') ? 'FALLING'
          : 'STEADY';

      return CwcStation(
        stationName:      stationName,
        stateName:        _stateNameFrom(site, fallbackState),
        riverName:        _riverNameFrom(site),
        riverLevel:       double.parse(waterLevel.toStringAsFixed(2)),
        warningLevel:     double.parse(warningLevel.toStringAsFixed(2)),
        dangerLevel:      double.parse(effectiveDanger.toStringAsFixed(2)),
        flowRate:         double.parse(
            _safeFloat(site['discharge'] ?? site['Discharge'] ?? site['flowRate'] ?? site['flow_rate'])
                .toStringAsFixed(1)),
        rainfallLastHour: double.parse(rainfall.toStringAsFixed(2)),
        status:           statusLabel,
        trend:            trend,
        source:           'CWC_API',
        lastUpdate:       _parseDate(
            (site['dateTime'] ?? site['DateTime'] ??
             site['lastUpdate'] ?? site['last_update'] ??
             site['observationTime'] ?? site['date'])?.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Tactical fallback ──────────────────────────────────────────────────────

  List<CwcStation> _buildTacticalTelemetry({
    required String stateName,
    required String stationName,
    required int limit,
  }) {
    final stateKey   = _normalizeKey(stateName).isEmpty ? 'active-region' : _normalizeKey(stateName);
    final stationKey = _normalizeKey(stationName);
    final timeBucket = DateTime.now().millisecondsSinceEpoch ~/ (30 * 60 * 1000);

    final profiles = _buildTacticalProfiles(stateName, stationName);
    final telemetry = <CwcStation>[];

    for (var i = 0; i < math.min(limit, profiles.length); i++) {
      final profile = profiles[i];
      final seed    = '$stateKey|${_normalizeKey(profile.station)}|$timeBucket|$i';
      final threat  = _seededUnit('$seed|threat');
      final warnLvl = profile.warningLevel;
      final dangerLvl = profile.dangerLevel;

      double currentLevel = warnLvl - (0.45 + _seededUnit('$seed|safe') * 1.55);
      if (threat > 0.84) {
        currentLevel = dangerLvl + _seededUnit('$seed|critical') * 0.45;
      } else if (threat > 0.58) {
        currentLevel = warnLvl +
            _seededUnit('$seed|warning') * math.max(dangerLvl - warnLvl, 0.6);
      }
      currentLevel = double.parse(currentLevel.toStringAsFixed(2));

      final trendRoll = _seededUnit('$seed|trend');
      final trend = trendRoll > 0.66 ? 'RISING' : trendRoll > 0.33 ? 'STEADY' : 'FALLING';

      telemetry.add(CwcStation(
        stationName:      profile.station,
        stateName:        stateName,
        riverName:        profile.river,
        riverLevel:       currentLevel,
        warningLevel:     warnLvl,
        dangerLevel:      dangerLvl,
        flowRate:         double.parse(
            (math.max(currentLevel, 0) * (10.8 + _seededUnit('$seed|flow') * 4.4)).toStringAsFixed(1)),
        rainfallLastHour: double.parse((_seededUnit('$seed|rain') * 18).toStringAsFixed(1)),
        status:           _statusFromLevels(currentLevel, warnLvl, dangerLvl),
        trend:            trend,
        source:           'TACTICAL_REGISTRY',
        lastUpdate:       DateTime.now().subtract(
            Duration(milliseconds: (_seededUnit('$seed|time') * 55 * 60 * 1000).toInt())),
      ));
    }

    if (stationKey.isNotEmpty) {
      telemetry.sort((a, b) {
        final ma = _normalizeKey(a.stationName).contains(stationKey) ||
            _normalizeKey(a.riverName).contains(stationKey) ? 0 : 1;
        final mb = _normalizeKey(b.stationName).contains(stationKey) ||
            _normalizeKey(b.riverName).contains(stationKey) ? 0 : 1;
        if (ma != mb) return ma.compareTo(mb);
        return b.riverLevel.compareTo(a.riverLevel);
      });
    }

    return telemetry;
  }

  _TacticalProfile _defaultStateProfile(String stateName) {
    const dangerLevels = <String, double>{
      'maharashtra': 14.0, 'odisha': 16.5, 'assam': 15.0,
      'west bengal': 12.5, 'bihar': 13.5, 'uttar pradesh': 11.5,
      'andhra pradesh': 13.0, 'telangana': 11.0, 'kerala': 12.0,
      'karnataka': 12.5, 'gujarat': 10.5, 'punjab': 9.5,
      'rajasthan': 8.5, 'madhya pradesh': 11.0, 'chhattisgarh': 10.5,
      'jharkhand': 9.5, 'tamil nadu': 10.0, 'uttarakhand': 12.0,
      'himachal pradesh': 10.0, 'jammu & kashmir': 11.5,
      'arunachal pradesh': 14.0, 'manipur': 9.0, 'nagaland': 8.0,
      'meghalaya': 9.5, 'tripura': 8.5, 'mizoram': 7.5, 'sikkim': 11.0,
      'goa': 7.0, 'delhi': 207.49,
    };
    final key    = _normalizeKey(stateName);
    final danger = dangerLevels[key] ?? 12.0;
    return _TacticalProfile(
      station: '$stateName Central Gauge',
      river:   '$stateName Primary Basin',
      warningLevel: double.parse(math.max(danger - 1.4, danger * 0.86).toStringAsFixed(2)),
      dangerLevel:  danger,
    );
  }

  List<_TacticalProfile> _buildTacticalProfiles(String stateName, String stationName) {
    final base    = _defaultStateProfile(stateName);
    final danger  = base.dangerLevel;
    final primary = math.max(danger - 1.4, danger * 0.86);
    return [
      _TacticalProfile(
        station:      stationName.isNotEmpty ? stationName : base.station,
        river:        '$stateName Primary Basin',
        warningLevel: double.parse(primary.toStringAsFixed(2)),
        dangerLevel:  double.parse(danger.toStringAsFixed(2)),
      ),
      _TacticalProfile(
        station:      '$stateName Downstream Sector',
        river:        '$stateName Downstream Reach',
        warningLevel: double.parse(math.max(primary - 0.6, 0.6).toStringAsFixed(2)),
        dangerLevel:  double.parse(math.max(danger - 0.4, primary + 0.7).toStringAsFixed(2)),
      ),
      _TacticalProfile(
        station:      '$stateName Catchment Control',
        river:        '$stateName Catchment Basin',
        warningLevel: double.parse(math.max(primary - 1.2, 0.5).toStringAsFixed(2)),
        dangerLevel:  double.parse(math.max(danger - 1.1, math.max(primary - 1.2, 0.5) + 0.8).toStringAsFixed(2)),
      ),
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalizeKey(String? value) {
    if (value == null) return '';
    var k = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (k == 'orissa')                     return 'odisha';
    if (k == 'nct of delhi' || k == 'new delhi') return 'delhi';
    if (k == 'uttaranchal')                return 'uttarakhand';
    return k;
  }

  double _safeFloat(dynamic value, {double def = 0.0}) {
    if (value == null || value == '') return def;
    return double.tryParse(value.toString()) ?? def;
  }

  String _statusFromLevels(double current, double warning, double danger) {
    if (danger > 0 && current >= danger)  return 'CRITICAL';
    if (warning > 0 && current >= warning) return 'WARNING';
    return 'ACTIVE';
  }

  DateTime _parseDate(String? raw) {
    if (raw == null) return DateTime.now();
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  int _sitePriority(CwcStation station, String targetState, String targetStation) {
    final stationMatch = targetStation.isNotEmpty &&
        (_normalizeKey(station.stationName).contains(targetStation) ||
            _normalizeKey(station.riverName).contains(targetStation));
    final stateMatch = targetState.isNotEmpty &&
        _normalizeKey(station.stateName).contains(targetState);
    if (stationMatch && stateMatch) return 0;
    if (stationMatch) return 1;
    if (stateMatch)   return 2;
    return 3;
  }

  double _seededUnit(String seed) {
    int hash = 0;
    for (final ch in seed.codeUnits) {
      hash = ((hash << 5) - hash + ch) & 0x7FFFFFFF;
    }
    return (hash % 1000) / 1000;
  }

  void _rememberFailure(String message, {required int cooldownSeconds}) {
    _failureMessage = message;
    _retryAfter = DateTime.now().add(Duration(seconds: math.max(30, cooldownSeconds)));
  }

  void _clearFailure() {
    _retryAfter     = null;
    _failureMessage = '';
  }
}

class _TacticalProfile {
  final String station;
  final String river;
  final double warningLevel;
  final double dangerLevel;
  const _TacticalProfile({
    required this.station,
    required this.river,
    required this.warningLevel,
    required this.dangerLevel,
  });
}
