// lib/services/live_fetch_engine.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — LAYER 4: Parallel Live-Fetch Engine                       ║
// ║                                                                          ║
// ║  Fires requests to all 5 data sources simultaneously using             ║
// ║  Future.wait() with individual per-source timeout isolation.           ║
// ║  A failed/slow source NEVER blocks the others.                         ║
// ║                                                                          ║
// ║  Returns: LiveSnapshot — a single immutable data bundle per city.      ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/app_config.dart';
import '../data/india_cities.dart';
import '../data/direct_sources.dart';

// ─── Data containers ──────────────────────────────────────────────────────────

class WeatherSnapshot {
  final double? temperatureC;
  final double? humidity;
  final double? precipitationMm;   // current hour
  final double? windspeedKmh;
  final int?    weatherCode;
  final List<double> hourlyPrecip; // next 24 hours
  final List<double> hourlyPrecipProb;
  final DateTime fetchedAt;
  final bool ok;
  final String? error;

  const WeatherSnapshot({
    this.temperatureC, this.humidity, this.precipitationMm,
    this.windspeedKmh, this.weatherCode,
    this.hourlyPrecip = const [],
    this.hourlyPrecipProb = const [],
    required this.fetchedAt, this.ok = true, this.error,
  });

  factory WeatherSnapshot.failed(String err) =>
      WeatherSnapshot(fetchedAt: DateTime.now(), ok: false, error: err);
}

class RiverSnapshot {
  final double? dischargeM3s;    // latest daily value
  final List<double> discharge7d; // past 7 days
  final List<double> forecast16d; // forward 16 days
  final DateTime fetchedAt;
  final bool ok;
  final String? error;

  const RiverSnapshot({
    this.dischargeM3s,
    this.discharge7d = const [],
    this.forecast16d = const [],
    required this.fetchedAt, this.ok = true, this.error,
  });

  factory RiverSnapshot.failed(String err) =>
      RiverSnapshot(fetchedAt: DateTime.now(), ok: false, error: err);
}

class CwcSnapshot {
  final String? stationCode;
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final String? trend;
  final DateTime fetchedAt;
  final bool ok;
  final String? error;

  const CwcSnapshot({
    this.stationCode, this.currentLevel, this.dangerLevel,
    this.warningLevel, this.trend,
    required this.fetchedAt, this.ok = true, this.error,
  });

  factory CwcSnapshot.noStation() =>
      CwcSnapshot(fetchedAt: DateTime.now(), ok: false, error: 'no_cwc_station');

  factory CwcSnapshot.failed(String err) =>
      CwcSnapshot(fetchedAt: DateTime.now(), ok: false, error: err);
}

class ReservoirSnapshot {
  final List<Map<String, dynamic>> reservoirs; // raw list
  final DateTime fetchedAt;
  final bool ok;
  final String? error;

  const ReservoirSnapshot({
    this.reservoirs = const [],
    required this.fetchedAt, this.ok = true, this.error,
  });

  factory ReservoirSnapshot.failed(String err) =>
      ReservoirSnapshot(fetchedAt: DateTime.now(), ok: false, error: err);
}

class ImdAlertSnapshot {
  final List<String> titles;
  final List<String> descriptions;
  final DateTime fetchedAt;
  final bool ok;
  final String? error;

  const ImdAlertSnapshot({
    this.titles = const [],
    this.descriptions = const [],
    required this.fetchedAt, this.ok = true, this.error,
  });

  factory ImdAlertSnapshot.failed(String err) =>
      ImdAlertSnapshot(fetchedAt: DateTime.now(), ok: false, error: err);
}

/// The single output bundle produced per fetch cycle.
class LiveSnapshot {
  final IndiaCity city;
  final WeatherSnapshot weather;
  final RiverSnapshot river;
  final CwcSnapshot cwc;
  final ReservoirSnapshot reservoir;
  final ImdAlertSnapshot imdAlerts;
  final DateTime fetchedAt;

  const LiveSnapshot({
    required this.city,
    required this.weather,
    required this.river,
    required this.cwc,
    required this.reservoir,
    required this.imdAlerts,
    required this.fetchedAt,
  });

  /// True only when ALL 5 sources returned data.
  bool get allSourcesOk =>
      weather.ok && river.ok && cwc.ok && reservoir.ok && imdAlerts.ok;

  /// Count of healthy sources.
  int get healthySourceCount => [
    weather.ok, river.ok, cwc.ok, reservoir.ok, imdAlerts.ok,
  ].where((v) => v).length;
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class LiveFetchEngine {
  LiveFetchEngine._();
  static final LiveFetchEngine instance = LiveFetchEngine._();

  final _client = http.Client();

  // Per-source timeouts (independent — slow source doesn't affect others)
  static const _weatherTimeout    = Duration(seconds: 12);
  static const _riverTimeout      = Duration(seconds: 15);
  static const _cwcTimeout        = Duration(seconds: 20); // proxy may be cold
  static const _reservoirTimeout  = Duration(seconds: 12);
  static const _imdTimeout        = Duration(seconds: 10);

  /// Fetch all 5 sources in parallel for [city].
  /// Never throws — individual source errors are captured in snapshot fields.
  Future<LiveSnapshot> fetchCity(IndiaCity city) async {
    final results = await Future.wait([
      _fetchWeather(city),
      _fetchRiver(city),
      _fetchCwc(city),
      _fetchReservoir(city),
      _fetchImdAlerts(),
    ]);

    return LiveSnapshot(
      city:       city,
      weather:    results[0] as WeatherSnapshot,
      river:      results[1] as RiverSnapshot,
      cwc:        results[2] as CwcSnapshot,
      reservoir:  results[3] as ReservoirSnapshot,
      imdAlerts:  results[4] as ImdAlertSnapshot,
      fetchedAt:  DateTime.now(),
    );
  }

  // ── A) Open-Meteo Weather ──────────────────────────────────────────────────
  Future<WeatherSnapshot> _fetchWeather(IndiaCity city) async {
    try {
      final url = OpenMeteoUrls.weather(city.lat, city.lon);
      final resp = await _client
          .get(Uri.parse(url))
          .timeout(_weatherTimeout);
      if (resp.statusCode != 200) {
        return WeatherSnapshot.failed('HTTP ${resp.statusCode}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final cur = j['current'] as Map<String, dynamic>? ?? {};
      final hourly = j['hourly'] as Map<String, dynamic>? ?? {};

      List<double> _doubles(dynamic v) =>
          (v as List?)?.map((e) => (e as num?)?.toDouble() ?? 0.0).toList() ?? [];

      return WeatherSnapshot(
        temperatureC:     (cur['temperature_2m'] as num?)?.toDouble(),
        humidity:         (cur['relative_humidity_2m'] as num?)?.toDouble(),
        precipitationMm:  (cur['precipitation'] as num?)?.toDouble(),
        windspeedKmh:     (cur['windspeed_10m'] as num?)?.toDouble(),
        weatherCode:      cur['weathercode'] as int?,
        hourlyPrecip:     _doubles(hourly['precipitation']),
        hourlyPrecipProb: _doubles(hourly['precipitation_probability']),
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      return WeatherSnapshot.failed('timeout');
    } catch (e) {
      return WeatherSnapshot.failed(e.toString());
    }
  }

  // ── B) Open-Meteo GloFAS River Discharge ──────────────────────────────────
  Future<RiverSnapshot> _fetchRiver(IndiaCity city) async {
    try {
      final url = OpenMeteoUrls.riverDischarge(city.lat, city.lon);
      final resp = await _client
          .get(Uri.parse(url))
          .timeout(_riverTimeout);
      if (resp.statusCode != 200) {
        return RiverSnapshot.failed('HTTP ${resp.statusCode}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final daily = j['daily'] as Map<String, dynamic>? ?? {};
      final allDischarge = (daily['river_discharge'] as List?)
          ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
          .toList() ?? [];

      // past 7 days | next 16 days split
      final past = allDischarge.take(7).toList();
      final forecast = allDischarge.skip(7).toList();
      final latest = past.isNotEmpty ? past.last : null;

      return RiverSnapshot(
        dischargeM3s: latest,
        discharge7d:  past,
        forecast16d:  forecast,
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      return RiverSnapshot.failed('timeout');
    } catch (e) {
      return RiverSnapshot.failed(e.toString());
    }
  }

  // ── C) CWC FFS via OpsFlood proxy ─────────────────────────────────────────
  Future<CwcSnapshot> _fetchCwc(IndiaCity city) async {
    if (city.cwcStation == null) return CwcSnapshot.noStation();
    try {
      final url = CwcProxyUrls.station(city.cwcStation!);
      final resp = await _client
          .get(Uri.parse(url))
          .timeout(_cwcTimeout);
      if (resp.statusCode != 200) {
        return CwcSnapshot.failed('HTTP ${resp.statusCode}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return CwcSnapshot(
        stationCode:  city.cwcStation,
        currentLevel: (j['current_level'] as num?)?.toDouble(),
        dangerLevel:  (j['danger_level']  as num?)?.toDouble(),
        warningLevel: (j['warning_level'] as num?)?.toDouble(),
        trend:        j['trend'] as String?,
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      return CwcSnapshot.failed('timeout');
    } catch (e) {
      return CwcSnapshot.failed(e.toString());
    }
  }

  // ── D) data.gov.in Reservoir Levels ───────────────────────────────────────
  Future<ReservoirSnapshot> _fetchReservoir(IndiaCity city) async {
    try {
      final url = DataGovUrls.reservoirByState(city.state);
      final resp = await _client
          .get(Uri.parse(url))
          .timeout(_reservoirTimeout);
      if (resp.statusCode != 200) {
        return ReservoirSnapshot.failed('HTTP ${resp.statusCode}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final records = (j['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return ReservoirSnapshot(
        reservoirs: records,
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      return ReservoirSnapshot.failed('timeout');
    } catch (e) {
      return ReservoirSnapshot.failed(e.toString());
    }
  }

  // ── E) IMD RSS Alerts ──────────────────────────────────────────────────────
  Future<ImdAlertSnapshot> _fetchImdAlerts() async {
    try {
      final resp = await _client
          .get(Uri.parse(ImdRssUrls.nationalAlerts))
          .timeout(_imdTimeout);
      if (resp.statusCode != 200) {
        return ImdAlertSnapshot.failed('HTTP ${resp.statusCode}');
      }
      final doc = XmlDocument.parse(resp.body);
      final items = doc.findAllElements('item');
      final titles = items
          .map((i) => i.findElements('title').firstOrNull?.innerText ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      final descs = items
          .map((i) => i.findElements('description').firstOrNull?.innerText ?? '')
          .where((d) => d.isNotEmpty)
          .toList();
      return ImdAlertSnapshot(
        titles: titles,
        descriptions: descs,
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      return ImdAlertSnapshot.failed('timeout');
    } catch (e) {
      return ImdAlertSnapshot.failed(e.toString());
    }
  }
}
