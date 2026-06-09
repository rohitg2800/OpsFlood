// lib/services/alert_engine.dart  v1.0
//
// Rule-based alert engine for OpsFlood.
//
// Evaluates every DataFetchSnapshot and produces a sorted list of FloodAlert
// objects. Triggered rules:
//
//   LEVEL_ABOVE_WARNING    current ≥ warningLevel
//   LEVEL_ABOVE_DANGER     current ≥ dangerLevel
//   LEVEL_ABOVE_HFL        current ≥ HFL (all-time high)
//   RAPID_RISE             rate-of-rise ≥ 0.15 m/h (WARNING) or ≥ 0.30 (CRITICAL)
//   FORECAST_DANGER_24H    forecast24h ≥ dangerLevel
//   FORECAST_DANGER_48H    forecast48h ≥ dangerLevel
//   RAINFALL_EXTREME       rainfall24h ≥ 100 mm (red alert threshold)
//   RAINFALL_HEAVY         rainfall24h ≥  64.5 mm (IMD heavy rain)
//   UPSTREAM_CRITICAL      >2 stations above danger in same river basin
//   MULTI_RIVER_ALERT      ≥3 rivers with stations above warning

library;

import 'data_fetch_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertSeverity
// ─────────────────────────────────────────────────────────────────────────────
enum AlertSeverity { info, warning, critical, emergency }

extension AlertSeverityExt on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.info:      return 'INFO';
      case AlertSeverity.warning:   return 'WARNING';
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.emergency: return 'EMERGENCY';
    }
  }
  int get priority {
    switch (this) {
      case AlertSeverity.info:      return 0;
      case AlertSeverity.warning:   return 1;
      case AlertSeverity.critical:  return 2;
      case AlertSeverity.emergency: return 3;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertType
// ─────────────────────────────────────────────────────────────────────────────
enum AlertType {
  levelAboveWarning,
  levelAboveDanger,
  levelAboveHfl,
  rapidRise,
  forecastDanger24h,
  forecastDanger48h,
  rainfallExtreme,
  rainfallHeavy,
  upstreamCritical,
  multiRiverAlert,
}

extension AlertTypeExt on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.levelAboveWarning:  return 'Above Warning Level';
      case AlertType.levelAboveDanger:   return 'Above Danger Level';
      case AlertType.levelAboveHfl:      return 'Above HFL (All-Time High)';
      case AlertType.rapidRise:          return 'Rapid Rise Alert';
      case AlertType.forecastDanger24h:  return 'Forecast: Danger in 24h';
      case AlertType.forecastDanger48h:  return 'Forecast: Danger in 48h';
      case AlertType.rainfallExtreme:    return 'Extreme Rainfall';
      case AlertType.rainfallHeavy:      return 'Heavy Rainfall';
      case AlertType.upstreamCritical:   return 'Upstream Critical';
      case AlertType.multiRiverAlert:    return 'Multi-River Flood Alert';
    }
  }
  String get icon {
    switch (this) {
      case AlertType.levelAboveWarning:  return '⚠️';
      case AlertType.levelAboveDanger:   return '🚨';
      case AlertType.levelAboveHfl:      return '🔴';
      case AlertType.rapidRise:          return '📈';
      case AlertType.forecastDanger24h:  return '⏱️';
      case AlertType.forecastDanger48h:  return '🗓️';
      case AlertType.rainfallExtreme:    return '🌧️';
      case AlertType.rainfallHeavy:      return '🌨️';
      case AlertType.upstreamCritical:   return '⬆️';
      case AlertType.multiRiverAlert:    return '🌊';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodAlert
// ─────────────────────────────────────────────────────────────────────────────
class FloodAlert {
  final String        id;          // unique: station-type
  final AlertType     type;
  final AlertSeverity severity;
  final String        title;
  final String        body;
  final String        stationName;
  final String        river;
  final String        district;
  final String        state;
  final double        currentLevel;
  final double        thresholdLevel;
  final double?       rateOfRiseMph;
  final double?       rainfall24hMm;
  final String        action;      // recommended action
  final DateTime      issuedAt;
  final DateTime?     expiresAt;

  const FloodAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.stationName,
    required this.river,
    required this.district,
    required this.state,
    required this.currentLevel,
    required this.thresholdLevel,
    this.rateOfRiseMph,
    this.rainfall24hMm,
    required this.action,
    required this.issuedAt,
    this.expiresAt,
  });

  bool get isExpired {
    final exp = expiresAt;
    return exp != null && DateTime.now().isAfter(exp);
  }

  double get exceedancePct =>
      thresholdLevel > 0 ? ((currentLevel - thresholdLevel) / thresholdLevel * 100) : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// AlertEngine
// ─────────────────────────────────────────────────────────────────────────────
class AlertEngine {
  AlertEngine._();
  static final instance = AlertEngine._();

  List<FloodAlert> evaluate(DataFetchSnapshot snapshot) {
    if (snapshot.isLoading) return const [];
    final alerts = <FloodAlert>[];
    final now    = snapshot.fetchedAt;

    for (final s in snapshot.stations) {
      alerts.addAll(_evaluateStation(s, now));
    }

    // Basin-level rules
    alerts.addAll(_evaluateBasin(snapshot.stations, now));

    // Deduplicate (keep highest severity per id)
    final Map<String, FloodAlert> deduped = {};
    for (final a in alerts) {
      final existing = deduped[a.id];
      if (existing == null ||
          a.severity.priority > existing.severity.priority) {
        deduped[a.id] = a;
      }
    }

    final result = deduped.values
        .where((a) => !a.isExpired)
        .toList()
      ..sort((a, b) {
        final sc = b.severity.priority.compareTo(a.severity.priority);
        if (sc != 0) return sc;
        return b.issuedAt.compareTo(a.issuedAt);
      });

    return result;
  }

  List<FloodAlert> _evaluateStation(StationReading s, DateTime now) {
    final alerts = <FloodAlert>[];
    final id     = s.stationName.toLowerCase().replaceAll(' ', '_');

    // ── LEVEL_ABOVE_HFL ────────────────────────────────────────────────────
    if (s.isAboveHfl) {
      alerts.add(FloodAlert(
        id:             '$id.hfl',
        type:           AlertType.levelAboveHfl,
        severity:       AlertSeverity.emergency,
        title:          '${s.stationName}: NEW HFL',
        body:           '${s.stationName} on ${s.river} has reached '
                        '${s.currentLevel.toStringAsFixed(2)} m — '
                        'above the all-time HFL of ${s.hfl.toStringAsFixed(2)} m.',
        stationName:    s.stationName,
        river:          s.river,
        district:       s.district,
        state:          s.state,
        currentLevel:   s.currentLevel,
        thresholdLevel: s.hfl,
        action:         'EVACUATE immediately. Breach possible. Alert SDRF and district admin.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 12)),
      ));
    }
    // ── LEVEL_ABOVE_DANGER ────────────────────────────────────────────────
    else if (s.isAboveDanger) {
      alerts.add(FloodAlert(
        id:             '$id.danger',
        type:           AlertType.levelAboveDanger,
        severity:       AlertSeverity.emergency,
        title:          '${s.stationName}: DANGER LEVEL BREACHED',
        body:           '${s.stationName} on ${s.river} at '
                        '${s.currentLevel.toStringAsFixed(2)} m '
                        '(danger: ${s.dangerLevel.toStringAsFixed(2)} m). '
                        '${(s.currentLevel - s.dangerLevel).toStringAsFixed(2)} m above danger.',
        stationName:    s.stationName,
        river:          s.river,
        district:       s.district,
        state:          s.state,
        currentLevel:   s.currentLevel,
        thresholdLevel: s.dangerLevel,
        action:         'Issue Red Alert. Initiate evacuation in low-lying areas. '
                        'Deploy NDRF/SDRF.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 6)),
      ));
    }
    // ── LEVEL_ABOVE_WARNING ───────────────────────────────────────────────
    else if (s.isAboveWarning) {
      alerts.add(FloodAlert(
        id:             '$id.warning',
        type:           AlertType.levelAboveWarning,
        severity:       AlertSeverity.critical,
        title:          '${s.stationName}: Above Warning Level',
        body:           '${s.stationName} on ${s.river} at '
                        '${s.currentLevel.toStringAsFixed(2)} m '
                        '(warning: ${s.warningLevel.toStringAsFixed(2)} m). '
                        'Approaching danger level.',
        stationName:    s.stationName,
        river:          s.river,
        district:       s.district,
        state:          s.state,
        currentLevel:   s.currentLevel,
        thresholdLevel: s.warningLevel,
        action:         'Issue Yellow Alert. Monitor closely. Prepare evacuation plans.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 4)),
      ));
    }

    // ── RAPID_RISE ────────────────────────────────────────────────────────
    final ror = s.rateOfRiseMph;
    if (ror != null && ror >= 0.15) {
      final isCrit = ror >= 0.30;
      alerts.add(FloodAlert(
        id:             '$id.rapid_rise',
        type:           AlertType.rapidRise,
        severity:       isCrit ? AlertSeverity.critical : AlertSeverity.warning,
        title:          '${s.stationName}: Rapid Rise (${ror.toStringAsFixed(2)} m/h)',
        body:           '${s.stationName} on ${s.river} is rising at '
                        '${ror.toStringAsFixed(2)} m/h. '
                        '${isCrit ? "Flash flood risk is HIGH." : "Elevated flood risk."}',
        stationName:    s.stationName,
        river:          s.river,
        district:       s.district,
        state:          s.state,
        currentLevel:   s.currentLevel,
        thresholdLevel: s.warningLevel,
        rateOfRiseMph:  ror,
        action:         isCrit
            ? 'Warn communities downstream. Close riverfront areas.'
            : 'Alert downstream districts. Monitor every 15 min.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 3)),
      ));
    }

    // ── FORECAST_DANGER_24H ───────────────────────────────────────────────
    final f24 = s.forecastLevel24h;
    if (f24 != null && f24 >= s.dangerLevel && !s.isAboveDanger) {
      alerts.add(FloodAlert(
        id:             '$id.forecast24',
        type:           AlertType.forecastDanger24h,
        severity:       AlertSeverity.critical,
        title:          '${s.stationName}: Danger Expected in 24h',
        body:           '${s.stationName} on ${s.river} forecast to reach '
                        '${f24.toStringAsFixed(2)} m '
                        '(danger: ${s.dangerLevel.toStringAsFixed(2)} m) '
                        'within 24 hours.',
        stationName:    s.stationName,
        river:          s.river,
        district:       s.district,
        state:          s.state,
        currentLevel:   s.currentLevel,
        thresholdLevel: s.dangerLevel,
        action:         'Pre-position boats. Notify village-level disaster committees.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 24)),
      ));
    }

    // ── FORECAST_DANGER_48H ───────────────────────────────────────────────
    final f48 = s.forecastLevel48h;
    if (f48 != null && f48 >= s.dangerLevel && (f24 == null || f24 < s.dangerLevel)) {
      alerts.add(FloodAlert(
        id:             '$id.forecast48',
        type:           AlertType.forecastDanger48h,
        severity:       AlertSeverity.warning,
        title:          '${s.stationName}: Danger Possible in 48h',
        body:           '${s.stationName} on ${s.river} may reach danger level within 48 h '
                        '(forecast: ${f48.toStringAsFixed(2)} m).',
        stationName:    s.stationName,
        river:          s.river,
        district:       s.district,
        state:          s.state,
        currentLevel:   s.currentLevel,
        thresholdLevel: s.dangerLevel,
        action:         'Review embankment status. Alert district administration.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 48)),
      ));
    }

    // ── RAINFALL_EXTREME / HEAVY ──────────────────────────────────────────
    final rain = s.rainfall24hMm;
    if (rain != null) {
      if (rain >= 100) {
        alerts.add(FloodAlert(
          id:             '$id.rain_extreme',
          type:           AlertType.rainfallExtreme,
          severity:       AlertSeverity.critical,
          title:          '${s.district}: Extreme Rainfall (${rain.toStringAsFixed(0)} mm)',
          body:           'Extreme rainfall of ${rain.toStringAsFixed(0)} mm recorded '
                          'near ${s.district} in past 24 h. '
                          'IMD Red Alert threshold exceeded.',
          stationName:    s.stationName,
          river:          s.river,
          district:       s.district,
          state:          s.state,
          currentLevel:   s.currentLevel,
          thresholdLevel: 100.0,
          rainfall24hMm:  rain,
          action:         'Mobilise rescue teams. Close low-lying settlements.',
          issuedAt:       now,
          expiresAt:      now.add(const Duration(hours: 6)),
        ));
      } else if (rain >= 64.5) {
        alerts.add(FloodAlert(
          id:             '$id.rain_heavy',
          type:           AlertType.rainfallHeavy,
          severity:       AlertSeverity.warning,
          title:          '${s.district}: Heavy Rainfall (${rain.toStringAsFixed(0)} mm)',
          body:           'Heavy rainfall of ${rain.toStringAsFixed(0)} mm in past 24 h '
                          'near ${s.district}. IMD Heavy Rain threshold exceeded.',
          stationName:    s.stationName,
          river:          s.river,
          district:       s.district,
          state:          s.state,
          currentLevel:   s.currentLevel,
          thresholdLevel: 64.5,
          rainfall24hMm:  rain,
          action:         'Alert block-level officials. Monitor river rise closely.',
          issuedAt:       now,
          expiresAt:      now.add(const Duration(hours: 6)),
        ));
      }
    }

    return alerts;
  }

  List<FloodAlert> _evaluateBasin(
      List<StationReading> stations, DateTime now) {
    final alerts = <FloodAlert>[];

    // ── UPSTREAM_CRITICAL: >2 danger stations on same river ───────────────
    final riverGroups = <String, List<StationReading>>{};
    for (final s in stations) {
      riverGroups.putIfAbsent(s.river, () => []).add(s);
    }
    riverGroups.forEach((river, slist) {
      final dangerStns = slist.where((s) => s.isAboveDanger).toList();
      if (dangerStns.length >= 2) {
        alerts.add(FloodAlert(
          id:             '${river.toLowerCase().replaceAll(' ', '_')}.upstream_critical',
          type:           AlertType.upstreamCritical,
          severity:       AlertSeverity.emergency,
          title:          '$river: Multi-Station Danger',
          body:           '${dangerStns.length} stations on $river are above danger level: '
                          '${dangerStns.map((s) => s.stationName).join(", ")}. '
                          'Downstream breach risk is HIGH.',
          stationName:    dangerStns.first.stationName,
          river:          river,
          district:       dangerStns.first.district,
          state:          dangerStns.first.state,
          currentLevel:   dangerStns.map((s) => s.currentLevel).reduce((a, b) => a > b ? a : b),
          thresholdLevel: dangerStns.first.dangerLevel,
          action:         'Breach likely. Mobilise NDRF. Evacuate all riverside settlements.',
          issuedAt:       now,
          expiresAt:      now.add(const Duration(hours: 8)),
        ));
      }
    });

    // ── MULTI_RIVER_ALERT: ≥3 rivers with warning-level stations ─────────
    final warnRivers = riverGroups.keys
        .where((r) => riverGroups[r]!.any((s) => s.isAboveWarning))
        .toList();
    if (warnRivers.length >= 3) {
      alerts.add(FloodAlert(
        id:             'bihar.multi_river',
        type:           AlertType.multiRiverAlert,
        severity:       AlertSeverity.critical,
        title:          'Multi-River Flood Alert (${warnRivers.length} Rivers)',
        body:           '${warnRivers.length} rivers are above warning level: '
                        '${warnRivers.join(", ")}. '
                        'State-wide flood situation developing.',
        stationName:    'State-Wide',
        river:          warnRivers.join(" / "),
        district:       'Multiple Districts',
        state:          'Bihar',
        currentLevel:   0,
        thresholdLevel: 0,
        action:         'Activate State Emergency Operations Centre. '
                        'Issue state-wide flood alert.',
        issuedAt:       now,
        expiresAt:      now.add(const Duration(hours: 12)),
      ));
    }

    return alerts;
  }
}
