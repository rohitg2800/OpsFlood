/// LiveLevelsService
/// Aggregates real-time CWC station data for ALL monitored cities.
/// Directly mirrors how app.py /api/live-levels works.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import 'cwc_service.dart';

class LiveLevelsService extends ChangeNotifier {
  static final LiveLevelsService _instance = LiveLevelsService._();
  factory LiveLevelsService() => _instance;
  LiveLevelsService._();

  List<FloodData>  _levels   = [];
  List<FloodAlert> _alerts   = [];
  bool             _loading  = false;
  bool             _liveData = false;
  String?          _error;
  DateTime?        _lastFetch;

  List<FloodData>  get levels      => _levels;
  List<FloodAlert> get alerts      => _alerts;
  bool             get isLoading   => _loading;
  bool             get hasLiveData => _liveData;
  String?          get error       => _error;
  DateTime?        get lastFetch   => _lastFetch;

  final CwcService _cwc = CwcService.instance;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final cwcStations = await _cwc.getAllAboveWarningStations();

      // Build lookup: normalised station name / river name → CwcStation
      final cwcByName = <String, CwcStation>{};
      for (final s in cwcStations) {
        final k = _norm(s.stationName);
        if (k.isNotEmpty) cwcByName[k] = s;
        final r = _norm(s.riverName);
        if (r.isNotEmpty) cwcByName.putIfAbsent(r, () => s);
      }

      final newLevels = <FloodData>[];
      bool anyLive = false;

      for (final city in AppConstants.monitoredCities) {
        final cityName  = city['city']  as String;
        final stateName = city['state'] as String;
        final riverName = city['river'] as String;
        final lat       = (city['lat']  as num).toDouble();
        final lon       = (city['lon']  as num).toDouble();

        // 1. Exact match on city name
        CwcStation? match = cwcByName[_norm(cityName)];
        // 2. Exact match on river name
        match ??= cwcByName[_norm(riverName)];
        // 3. Fuzzy — station contains city or city contains station
        if (match == null) {
          for (final e in cwcByName.entries) {
            if (e.key.contains(_norm(cityName)) ||
                _norm(cityName).contains(e.key)) {
              match = e.value;
              break;
            }
          }
        }

        if (match != null) {
          anyLive = true;
          // Ensure dangerLevel is never 0 — fall back to state default.
          final dl = match.dangerLevel > 0
              ? match.dangerLevel
              : _defaultDanger(stateName);
          final wl = match.warningLevel > 0
              ? match.warningLevel
              : _defaultWarning(stateName);
          final sl = _safeLevel(dl);

          // capacityPercent relative to safe→danger range (matches FloodData formula)
          final rawCapacity = dl > sl
              ? ((match.riverLevel - sl) / (dl - sl) * 100).clamp(0.0, 100.0)
              : 0.0;

          newLevels.add(FloodData(
            id:           '$cityName-$stateName-cwc',
            city:         cityName,
            state:        stateName,
            latitude:     lat,
            longitude:    lon,
            riverName:    match.riverName.isNotEmpty ? match.riverName : riverName,
            currentLevel: match.riverLevel,
            dangerLevel:  dl,
            warningLevel: wl,
            safeLevel:    sl,
            // Recompute riskLevel from rawCapacity so it matches the gauge
            riskLevel:    _riskFromCapacity(rawCapacity),
            lastUpdated:  match.lastUpdate,
            status:       match.status,
            flowRate:     match.flowRate > 0 ? match.flowRate : null,
            rainfall24h:  match.rainfallLastHour > 0 ? match.rainfallLastHour : null,
          ));
        } else {
          // Tactical fallback for cities not in CWC live feed
          final tactical = await _cwc.getLiveTelemetry(
              stateName: stateName, stationName: cityName, limit: 1);
          final t = tactical.isNotEmpty ? tactical.first : null;
          final dl = t?.dangerLevel   ?? _defaultDanger(stateName);
          final wl = t?.warningLevel  ?? _defaultWarning(stateName);
          final sl = _safeLevel(dl);
          final level = t?.riverLevel ?? (sl + (dl - sl) * _defaultCapacityFraction(city['risk'] as String));

          newLevels.add(FloodData(
            id:           '$cityName-$stateName-tactical',
            city:         cityName,
            state:        stateName,
            latitude:     lat,
            longitude:    lon,
            riverName:    riverName,
            currentLevel: level,
            dangerLevel:  dl,
            warningLevel: wl,
            safeLevel:    sl,
            riskLevel:    city['risk'] as String,
            lastUpdated:  DateTime.now(),
            status:       t?.status ?? 'ACTIVE',
            flowRate:     t?.flowRate,
            rainfall24h:  t?.rainfallLastHour,
          ));
        }
      }

      newLevels.sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));

      _levels    = newLevels;
      _liveData  = anyLive;
      _alerts    = _deriveAlerts(newLevels);
      _lastFetch = DateTime.now();
      _error     = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Alert derivation ──────────────────────────────────────────────────────

  List<FloodAlert> _deriveAlerts(List<FloodData> levels) {
    final now = DateTime.now();
    return levels
        .where((e) => e.capacityPercent >= AppConstants.highThreshold)
        .map((e) => FloodAlert(
              id:            '${e.city}_${now.millisecondsSinceEpoch}',
              city:          e.city,
              state:         e.state,
              severity:      e.capacityPercent >= AppConstants.criticalThreshold
                  ? 'CRITICAL'
                  : 'HIGH',
              title:         '${e.city} river alert',
              message:       '${e.riverName} is at ${e.capacityPercent.toStringAsFixed(0)}% capacity.',
              timestamp:     now,
              resolved:      false,
              riverName:     e.riverName,
              currentLevel:  e.currentLevel,
              dangerLevel:   e.dangerLevel,
              recommendation: e.capacityPercent >= AppConstants.criticalThreshold
                  ? 'Evacuate vulnerable river-basin zones immediately.'
                  : 'Increase monitoring and keep response units on standby.',
            ))
        .toList();
  }

  // ── State-level defaults ──────────────────────────────────────────────────

  static const _stateDangerLevels = <String, double>{
    'Maharashtra': 14.0, 'Odisha': 16.5, 'Assam': 15.0,
    'West Bengal': 12.5, 'Bihar': 13.5, 'Uttar Pradesh': 11.5,
    'Andhra Pradesh': 13.0, 'Telangana': 11.0, 'Kerala': 12.0,
    'Karnataka': 12.5, 'Gujarat': 10.5, 'Punjab': 9.5,
    'Rajasthan': 8.5, 'Madhya Pradesh': 11.0, 'Chhattisgarh': 10.5,
    'Jharkhand': 9.5, 'Tamil Nadu': 10.0, 'Uttarakhand': 12.0,
    'Himachal Pradesh': 10.0, 'Jammu & Kashmir': 11.5,
    'Arunachal Pradesh': 14.0, 'Delhi': 207.49,
  };

  double _defaultDanger(String state)  => _stateDangerLevels[state] ?? 12.0;
  double _defaultWarning(String state) {
    final d = _defaultDanger(state);
    return double.parse((d * 0.86).toStringAsFixed(2));
  }
  double _safeLevel(double danger)     => double.parse((danger * 0.60).toStringAsFixed(2));

  double _defaultCapacityFraction(String riskLabel) {
    switch (riskLabel) {
      case 'CRITICAL': return 0.92;
      case 'HIGH':     return 0.75;
      case 'MODERATE': return 0.55;
      default:         return 0.30;
    }
  }

  String _riskFromCapacity(double pct) {
    if (pct >= AppConstants.criticalThreshold) return 'CRITICAL';
    if (pct >= AppConstants.highThreshold)     return 'HIGH';
    if (pct >= AppConstants.moderateThreshold) return 'MODERATE';
    return 'LOW';
  }

  String _norm(String v) => v.trim().toLowerCase();
}
