// lib/providers/bihar_live_provider.dart  (v3.2)
//
// OpsFlood — All-Stations Live Provider
//
// v3.1 had a dead-code smell:
//   StationsUnifiedBridge.instance.attach(LiveFetchEngine())
//   • LiveFetchEngine has zero usages anywhere in the app.
//   • StationsUnifiedBridge has zero usages anywhere in the app.
//   • The attach() call created a brand-new, never-started LiveFetchEngine
//     instance on every build(), silently wiring a dead bridge to nothing.
//
// v3.2 fix: remove both imports and the attach() call entirely.
// The live data pipeline is:
//   BiharLiveEngine.instance.stream  (Engines A)
//   DataFetchEngine.instance.stream  (Engine B, via dataFetchProvider)
// Both are already correctly wired — no third engine is needed.
//
// Data flow (this file):
//   BiharLiveEngine.instance.stream
//     └─ BiharLiveFeed (items: List<BiharFeedItem>)
//           └─ BiharStationData.fromFeedItem() per gauge/barrage/telemetry item
//                 └─ BiharLiveState (sorted by risk)
//                       └─ biharLiveProvider (AsyncNotifier)
//                             ├─ LiveStationsScreen
//                             ├─ BiharDashboardProvider counts
//                             └─ BiharRiverMapScreen pins

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bihar_live_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BiharStationData  (model consumed by LiveStationsScreen + Map)
// ─────────────────────────────────────────────────────────────────────────────
class BiharStationData {
  final String  city;
  final String  river;
  final String  district;
  final String  state;
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final double? diff24h;
  final double? forecast24h;
  final String  trend;        // '↑' / '↓' / '→'
  final String  riskLabel;    // CRITICAL / SEVERE / HIGH / MODERATE / LOW / NORMAL
  final String  source;       // LIVE / STATIC
  final String  fetchedAt;    // ISO-8601 string

  final double? discharge;
  final double? dischargeMean;
  final double? rainfall24h;

  const BiharStationData({
    required this.city,
    required this.river,
    required this.district,
    required this.state,
    this.currentLevel,
    this.dangerLevel,
    this.warningLevel,
    this.diff24h,
    this.forecast24h,
    required this.trend,
    required this.riskLabel,
    required this.source,
    required this.fetchedAt,
    this.discharge,
    this.dischargeMean,
    this.rainfall24h,
  });

  // ── Factory: BiharFeedItem → BiharStationData ─────────────────────────────
  //
  // BiharFeedItem fields used:
  //   item.title           → city / station name
  //   item.raw['river']    → river name
  //   item.raw['district'] → district (may be absent)
  //   item.raw['state']    → state    (absent → 'Bihar')
  //   item.raw['level']    → numeric level (double, most reliable)
  //   item.value           → "12.34 m" string fallback
  //   item.raw['danger']   → danger threshold (double or null)
  //   item.raw['warning']  → warning threshold (double or null)
  //   item.dangerLevel     → status string ("Danger", "Warning", "Normal" …)
  //   item.fetchedAt       → timestamp
  //   item.changeStr       → diff string (e.g. "+0.12 m ↑")  optional
  factory BiharStationData.fromFeedItem(BiharFeedItem item) {
    // level
    final rawLevel  = item.raw['level'];
    final curDouble = rawLevel != null
        ? _safeLevel(rawLevel)
        : _parseLevelString(item.value);

    // thresholds
    final dan = _safeThreshold(item.raw['danger'],  fallback: 99.0);
    final war = _safeThreshold(item.raw['warning'], fallback: dan * 0.85);

    // diff from changeStr  e.g. "+0.12 m ↑"
    double? diff;
    if (item.changeStr != null) {
      final numStr = item.changeStr!.replaceAll(RegExp(r'[^0-9.+-]'), '');
      diff = _safeLevel(double.tryParse(numStr));
    }

    // trend: prefer changeStr arrow, fall back to level vs warning
    String trend = '→';
    if (item.changeStr != null) {
      if (item.changeStr!.contains('↑')) trend = '↑';
      if (item.changeStr!.contains('↓')) trend = '↓';
    } else if (curDouble != null && war > 0) {
      if (curDouble > war)       trend = '↑';
      if (curDouble < war * 0.9) trend = '↓';
    }

    // risk label — normalise the dangerLevel status string
    final risk = _normaliseRisk((item.dangerLevel ?? '').trim().toUpperCase());

    // river
    String river = '';
    if (item.raw['river'] is String) {
      river = (item.raw['river'] as String).trim();
    }
    if (river.isEmpty && item.subtitle.startsWith('River: ')) {
      river = item.subtitle.substring('River: '.length).trim();
    }

    final district = (item.raw['district'] as String?)?.trim() ?? '';
    final state    = (item.raw['state'] as String?)?.trim().isNotEmpty == true
        ? (item.raw['state'] as String).trim()
        : 'Bihar';

    return BiharStationData(
      city:          item.title,
      river:         river,
      district:      district,
      state:         state,
      currentLevel:  curDouble,
      dangerLevel:   dan,
      warningLevel:  war,
      diff24h:       diff,
      forecast24h:   null,
      trend:         trend,
      riskLabel:     risk,
      source:        'LIVE',
      fetchedAt:     item.fetchedAt.toIso8601String(),
      discharge:     null,
      dischargeMean: null,
      rainfall24h:   _safeLevel(item.raw['rainfall']),
    );
  }

  // ── Gauge helpers ─────────────────────────────────────────────────────────
  double get dangerPercent {
    final cur = currentLevel;
    final dan = dangerLevel;
    if (cur == null || dan == null || dan <= 0) return 0;
    return ((cur / dan) * 100).clamp(0, 150).toDouble();
  }

  bool get isCritical => riskLabel == 'CRITICAL';
  bool get isSevere   => riskLabel == 'SEVERE';
  bool get isWarning  =>
      riskLabel == 'HIGH' || riskLabel == 'WARNING' || riskLabel == 'MODERATE';
  bool get isSafe     => riskLabel == 'LOW' || riskLabel == 'NORMAL';
  bool get hasNoData  => riskLabel == 'UNKNOWN' || source == 'STATIC';

  // ── Private safe-parse helpers ────────────────────────────────────────────
  static double? _parseLevelString(String? s) {
    if (s == null || s.isEmpty || s == '—') return null;
    final numStr = RegExp(r'[-+]?\d+\.?\d*').firstMatch(s)?.group(0);
    return _safeLevel(double.tryParse(numStr ?? ''));
  }

  static double? _safeLevel(dynamic v) {
    if (v == null) return null;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else {
      d = double.tryParse(v.toString());
    }
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d.clamp(0.0, double.maxFinite);
  }

  static double _safeThreshold(dynamic v, {required double fallback}) {
    final d = _safeLevel(v);
    if (d == null || d <= 0) return fallback;
    return d;
  }

  static String _normaliseRisk(String raw) {
    if (raw.contains('DANGER')   || raw.contains('BREACH')   ||
        raw.contains('EXTREME')  || raw.contains('CRITICAL'))
      return 'CRITICAL';
    if (raw.contains('SEVERE')   || raw.contains('ABOVE_HFL') ||
        raw.contains('ABOVE DANGER'))
      return 'SEVERE';
    if (raw.contains('WARNING')  || raw.contains('HIGH')     ||
        raw.contains('ABOVE')    || raw.contains('MODERATE'))
      return 'HIGH';
    if (raw.contains('WATCH')    || raw.contains('CAUTION'))
      return 'MODERATE';
    if (raw == 'LOW' || raw == 'SAFE'   || raw == 'NORMAL' ||
        raw == 'PRE-MONSOON'            || raw == 'BELOW WARNING')
      return 'LOW';
    return 'NORMAL';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BiharLiveState
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveState {
  final List<BiharStationData> stations;
  final DateTime? lastFetched;

  const BiharLiveState({this.stations = const [], this.lastFetched});

  int get criticalCount => stations.where((s) => s.isCritical).length;
  int get severeCount   => stations.where((s) => s.isSevere).length;
  int get warningCount  => stations.where((s) => s.isWarning).length;
  int get safeCount     => stations.where((s) => s.isSafe).length;
  int get noDataCount   => stations.where((s) => s.hasNoData).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier  (v3.2 — clean, single-engine: BiharLiveEngine)
// ─────────────────────────────────────────────────────────────────────────────

const _kRiskOrder = {
  'CRITICAL': 0,
  'SEVERE':   1,
  'HIGH':     2,
  'MODERATE': 3,
  'LOW':      4,
  'NORMAL':   5,
  'UNKNOWN':  6,
};

class BiharLiveNotifier extends AsyncNotifier<BiharLiveState> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  Future<BiharLiveState> build() async {
    final engine = BiharLiveEngine.instance;

    // Start engine if not already running (idempotent).
    if (!engine.running) engine.start();

    // Cancel any previous subscription (e.g. hot-reload).
    _sub?.cancel();

    // Subscribe to the broadcast stream — fires after every engine cycle.
    _sub = engine.stream.listen(_onFeed);

    // Clean up on provider dispose.
    ref.onDispose(() => _sub?.cancel());

    // Build state from whatever the engine has cached already
    // (instant first paint; empty state shows loading spinner).
    return _buildState(engine.latest);
  }

  // Called by the engine after every refresh (≈every 15 min for gauges).
  void _onFeed(BiharLiveFeed feed) {
    state = AsyncData(_buildState(feed));
  }

  // Convert BiharLiveFeed → BiharLiveState.
  BiharLiveState _buildState(BiharLiveFeed? feed) {
    if (feed == null || feed.items.isEmpty) {
      return BiharLiveState(lastFetched: feed?.generatedAt);
    }

    final stations = feed.items
        .where((i) =>
            i.kind == FeedItemKind.riverGauge ||
            i.kind == FeedItemKind.barrage    ||
            i.kind == FeedItemKind.telemetry)
        .map(BiharStationData.fromFeedItem)
        .where((s) => s.currentLevel != null && s.currentLevel! > 0)
        .toList()
      ..sort((a, b) =>
          (_kRiskOrder[a.riskLabel] ?? 5)
              .compareTo(_kRiskOrder[b.riskLabel] ?? 5));

    return BiharLiveState(
      stations:    stations,
      lastFetched: feed.generatedAt,
    );
  }

  /// Force an immediate full refresh (e.g. user taps Refresh button).
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      await BiharLiveEngine.instance.refresh();
      // _onFeed() fires automatically from the stream — no manual assignment.
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
final biharLiveProvider =
    AsyncNotifierProvider<BiharLiveNotifier, BiharLiveState>(
  BiharLiveNotifier.new,
);
