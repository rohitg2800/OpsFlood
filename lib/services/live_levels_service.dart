/// LiveLevelsService
/// Aggregates real-time CWC station data for ALL monitored cities.
/// Directly mirrors how app.py /api/live-levels works:
///   1. Try CWC live endpoint for all stations
///   2. For cities not in live feed, generate tactical telemetry
///   3. Convert to FloodData shape for the rest of the app
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
  bool             _liveData = false;   // true once CWC_API data received
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
      // 1. Fetch ALL above-warning stations from CWC
      final cwcStations = await _cwc.getAllAboveWarningStations();

      // 2. Build a lookup: normalised city/station name → CwcStation
      final cwcByName = <String, CwcStation>{};
      for (final s in cwcStations) {
        cwcByName[_norm(s.stationName)] = s;
        // Also index by river name for fuzzy match
        if (s.riverName.isNotEmpty) cwcByName[_norm(s.riverName)] = s;
      }

      // 3. Map every monitored city to a FloodData
      final newLevels = <FloodData>[];
      bool anyLive = false;

      for (final city in AppConstants.monitoredCities) {
        final cityName  = city['city']  as String;
        final stateName = city['state'] as String;
        final riverName = city['river'] as String;
        final lat       = (city['lat']  as num).toDouble();
        final lon       = (city['lon']  as num).toDouble();

        // Try matching CWC live data
        CwcStation? match = cwcByName[_norm(cityName)];
        match ??= cwcByName[_norm(riverName)];
        if (match == null) {
          // Fuzzy: find any CWC station whose name contains the city or vice-versa
          for (final e in cwcByName.entries) {
            if (e.key.contains(_norm(cityName)) || _norm(cityName).contains(e.key)) {
              match = e.value;
              break;
            }
          }
        }

        if (match != null) {
          anyLive = true;
          newLevels.add(FloodData(
            city:            cityName,
            state:           stateName,
            riverName:       match.riverName.isNotEmpty ? match.riverName : riverName,
            currentLevel:    match.riverLevel,
            dangerLevel:     match.dangerLevel > 0 ? match.dangerLevel : _defaultDanger(stateName),
            warningLevel:    match.warningLevel > 0 ? match.warningLevel : _defaultWarning(stateName),
            safeLevel:       _safeLevel(match.dangerLevel),
            capacityPercent: match.capacityPercent,
            riskLevel:       match.riskLevel,
            status:          match.status,
            trend:           match.trend,
            flowRate:        match.flowRate,
            rainfallLastHour: match.rainfallLastHour,
            lat: lat, lon: lon,
            source:          'CWC_API',
            lastUpdate:      match.lastUpdate,
          ));
        } else {
          // Tactical fallback for cities not in the live feed
          final tactical = await _cwc.getLiveTelemetry(
              stateName: stateName, stationName: cityName, limit: 1);
          final t = tactical.isNotEmpty ? tactical.first : null;
          newLevels.add(FloodData(
            city:            cityName,
            state:           stateName,
            riverName:       riverName,
            currentLevel:    t?.riverLevel    ?? 0,
            dangerLevel:     t?.dangerLevel   ?? _defaultDanger(stateName),
            warningLevel:    t?.warningLevel  ?? _defaultWarning(stateName),
            safeLevel:       _safeLevel(t?.dangerLevel ?? _defaultDanger(stateName)),
            capacityPercent: t?.capacityPercent ?? _defaultCapacity(stateName, city['risk'] as String),
            riskLevel:       t?.riskLevel  ?? (city['risk'] as String),
            status:          t?.status     ?? 'ACTIVE',
            trend:           t?.trend      ?? 'STEADY',
            flowRate:        t?.flowRate   ?? 0,
            rainfallLastHour: t?.rainfallLastHour ?? 0,
            lat: lat, lon: lon,
            source:          'TACTICAL_REGISTRY',
            lastUpdate:      DateTime.now(),
          ));
        }
      }

      // Sort by risk descending
      newLevels.sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));

      _levels   = newLevels;
      _liveData = anyLive;
      _alerts   = _deriveAlerts(newLevels);
      _lastFetch = DateTime.now();
      _error    = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Alert derivation (mirrors _alertsFromThresholds) ──────────────────────

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
              message:
                  '${e.riverName} is at ${e.capacityPercent.toStringAsFixed(0)}% capacity.',
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

  // ── State-level defaults (from state_severity_matrix.py) ──────────────────

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

  double _defaultDanger(String state) =>
      _stateDangerLevels[state] ?? 12.0;

  double _defaultWarning(String state) {
    final d = _defaultDanger(state);
    return double.parse((d * 0.86).toStringAsFixed(2));
  }

  double _safeLevel(double dangerLevel) =>
      double.parse((dangerLevel * 0.6).toStringAsFixed(2));

  double _defaultCapacity(String state, String riskLabel) {
    switch (riskLabel) {
      case 'CRITICAL': return 92;
      case 'HIGH':     return 75;
      case 'MODERATE': return 55;
      default:         return 30;
    }
  }

  String _norm(String v) => v.trim().toLowerCase();
}
