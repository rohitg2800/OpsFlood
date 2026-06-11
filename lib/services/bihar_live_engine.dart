// lib/services/bihar_live_engine.dart  v1.0
//
// ██████╗ ██╗██╗  ██╗ █████╗ ██████╗     ██╗     ██╗██╗   ██╗███████╗
// ██╔══██╗██║██║  ██║██╔══██╗██╔══██╗    ██║     ██║██║   ██║██╔════╝
// ██████╔╝██║███████║███████║██████╔╝    ██║     ██║██║   ██║█████╗
// ██╔══██╗██║██╔══██║██╔══██║██╔══██╗    ██║     ██║╚██╗ ██╔╝██╔══╝
// ██████╔╝██║██║  ██║██║  ██║██║  ██║    ███████╗██║ ╚████╔╝ ███████╗
// ╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚══════╝╚═╝  ╚═══╝  ╚══════╝
//  ENGINE
//
// Unified live data + news fetch orchestrator — BIHAR ONLY.
//
// Sources wired:
//   1. WRD Bihar  (wrd_bihar_service.dart)         — river gauge levels
//   2. CWC / BEFIQR  (befiqr_cwc_service.dart)     — CWC station readings
//   3. Kosi / Birpur (kosi_birpur_service.dart)     — Kosi barrage readings
//   4. WRIS  (wris_service.dart)                   — WRIS telemetry stations
//   5. Real-time river (real_time_river_service.dart) — live gauge push
//   6. India Stations  (india_stations_service.dart)  — CWC Bihar stations
//   7. NewsService  (news_service.dart)            — Bihar news + alerts
//
// Public API:
//   BiharLiveEngine.instance.stream   → Stream<BiharLiveFeed>
//   BiharLiveEngine.instance.latest   → BiharLiveFeed?   (last emitted)
//   BiharLiveEngine.instance.start()  → begin auto-refresh
//   BiharLiveEngine.instance.stop()   → cancel timers
//   BiharLiveEngine.instance.refresh()→ force immediate fetch
//
// Refresh intervals (configurable):
//   • River / gauge data  : every 15 minutes
//   • News / alerts       : every 10 minutes
//   • Kosi barrage        : every 20 minutes
//
// Each source is fetched independently so a failure in one does not
// block others. Per-source health is tracked in SourceHealth.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'befiqr_cwc_service.dart';
import 'bihar_wrd_scraper.dart';
import 'india_stations_service.dart';
import 'kosi_birpur_service.dart';
import 'news_service.dart';
import 'real_time_river_service.dart';
import 'wrd_bihar_service.dart';
import 'wris_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain models
// ─────────────────────────────────────────────────────────────────────────────

enum FeedItemKind { riverGauge, news, alert, barrage, telemetry }

enum SourceId {
  wrdBihar,
  cwcBefiqr,
  kosiBirpur,
  wris,
  realTimeRiver,
  indiaStations,
  news,
}

class SourceHealth {
  final SourceId id;
  final bool ok;
  final String? error;
  final DateTime lastAttempt;
  final Duration? latency;

  const SourceHealth({
    required this.id,
    required this.ok,
    this.error,
    required this.lastAttempt,
    this.latency,
  });

  SourceHealth copyWith({bool? ok, String? error, Duration? latency}) =>
      SourceHealth(
        id:          id,
        ok:          ok          ?? this.ok,
        error:       error       ?? this.error,
        lastAttempt: lastAttempt,
        latency:     latency     ?? this.latency,
      );

  @override
  String toString() =>
      'SourceHealth($id ok=$ok latency=${latency?.inMilliseconds}ms${error != null ? ' err=$error' : ''})';
}

/// A single normalised feed card — consumed directly by the Flutter feed UI.
class BiharFeedItem {
  final String       id;
  final FeedItemKind kind;
  final SourceId     source;
  final String       title;
  final String       subtitle;
  final String?      value;          // e.g. "12.34 m" or "Normal"
  final String?      dangerLevel;    // e.g. "Danger", "Warning", "Normal"
  final String?      changeStr;      // e.g. "+0.32 m ↑"
  final String?      url;
  final DateTime     fetchedAt;
  final NewsSeverity severity;       // re-used for colour coding
  final Map<String, dynamic> raw;    // original map from the sub-service

  const BiharFeedItem({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.subtitle,
    this.value,
    this.dangerLevel,
    this.changeStr,
    this.url,
    required this.fetchedAt,
    this.severity = NewsSeverity.info,
    this.raw = const {},
  });
}

/// The complete snapshot emitted on every refresh cycle.
class BiharLiveFeed {
  final List<BiharFeedItem>          items;
  final Map<SourceId, SourceHealth>  health;
  final DateTime                     generatedAt;
  final bool                         isPartial; // true if ≥1 source failed

  const BiharLiveFeed({
    required this.items,
    required this.health,
    required this.generatedAt,
    this.isPartial = false,
  });

  /// Items sorted: severity desc → fetchedAt desc
  List<BiharFeedItem> get sorted {
    final copy = [...items];
    copy.sort((a, b) {
      final sc = b.severity.index.compareTo(a.severity.index);
      return sc != 0 ? sc : b.fetchedAt.compareTo(a.fetchedAt);
    });
    return copy;
  }

  List<BiharFeedItem> byKind(FeedItemKind k) =>
      items.where((i) => i.kind == k).toList();

  int get errorCount => health.values.where((h) => !h.ok).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine
// ─────────────────────────────────────────────────────────────────────────────

class BiharLiveEngine {
  BiharLiveEngine._();
  static final BiharLiveEngine instance = BiharLiveEngine._();

  // ── config ────────────────────────────────────────────────────────────────
  static const _gaugeInterval = Duration(minutes: 15);
  static const _newsInterval  = Duration(minutes: 10);
  static const _kosiInterval  = Duration(minutes: 20);
  static const _timeout       = Duration(seconds: 20);

  // ── services ──────────────────────────────────────────────────────────────
  final _wrd          = WrdBiharService();
  final _befiqr       = BefiqrCwcService();
  final _kosiBirpur   = KosiBirpurService();
  final _wris         = WrisService();
  final _rtRiver      = RealTimeRiverService();
  final _indStations  = IndiaStationsService();
  final _wrdScraper   = BiharWrdScraper();
  final _news         = NewsService();

  // ── state ─────────────────────────────────────────────────────────────────
  final _controller  = StreamController<BiharLiveFeed>.broadcast();
  BiharLiveFeed?     _latest;
  Timer?             _gaugeTimer;
  Timer?             _newsTimer;
  Timer?             _kosiTimer;
  bool               _running = false;

  // ── internal caches (avoids re-fetching unchanged sources) ────────────────
  List<BiharFeedItem> _gaugeCache    = [];
  List<BiharFeedItem> _kosiCache     = [];
  List<BiharFeedItem> _wrisCache     = [];
  List<BiharFeedItem> _stationCache  = [];
  List<BiharFeedItem> _rtCache       = [];
  List<BiharFeedItem> _newsCache     = [];

  final Map<SourceId, SourceHealth> _health = {};

  // ── public ────────────────────────────────────────────────────────────────

  Stream<BiharLiveFeed> get stream => _controller.stream;
  BiharLiveFeed?        get latest => _latest;
  bool                  get running => _running;

  /// Start the engine.  Safe to call multiple times.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    debugPrint('[BiharLiveEngine] starting …');

    // Immediate first fetch
    await refresh();

    // Gauge sources: every 15 min
    _gaugeTimer = Timer.periodic(_gaugeInterval, (_) => _fetchGauge());

    // News: every 10 min
    _newsTimer = Timer.periodic(_newsInterval, (_) => _fetchNews());

    // Kosi barrage: every 20 min
    _kosiTimer = Timer.periodic(_kosiInterval, (_) => _fetchKosi());
  }

  /// Stop all timers and close the stream.
  void stop() {
    _gaugeTimer?.cancel();
    _newsTimer?.cancel();
    _kosiTimer?.cancel();
    _running = false;
    debugPrint('[BiharLiveEngine] stopped.');
  }

  /// Force an immediate full refresh of all sources.
  Future<void> refresh() async {
    debugPrint('[BiharLiveEngine] full refresh …');
    await Future.wait([
      _fetchGauge(),
      _fetchNews(),
      _fetchKosi(),
      _fetchWris(),
      _fetchRealTime(),
      _fetchIndiaStations(),
    ]);
    _emit();
  }

  // ── private fetch workers ─────────────────────────────────────────────────

  Future<void> _fetchGauge() async {
    final t0 = DateTime.now();
    try {
      // WRD Bihar — primary gauge source
      final data = await _wrd
          .fetchStations()
          .timeout(_timeout);
      _gaugeCache = data.map(_wrdToItem).toList();
      _setHealth(SourceId.wrdBihar, true, DateTime.now().difference(t0));

      // Also try WRD scraper for extra district-level rows
      try {
        final scraped = await _wrdScraper
            .fetchLatest()
            .timeout(_timeout);
        final scraperItems = (scraped as List<dynamic>)
            .map((e) => _scrapedToItem(e as Map<String, dynamic>))
            .toList();
        // Merge — prefer WRD service data for same station
        final seen = {for (final i in _gaugeCache) i.id};
        _gaugeCache.addAll(scraperItems.where((i) => !seen.contains(i.id)));
      } catch (_) {/* scraper optional */}
    } catch (e) {
      _setHealth(SourceId.wrdBihar, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] WRD: $e');
    }
    _emit();
  }

  Future<void> _fetchKosi() async {
    final t0 = DateTime.now();
    try {
      final data = await _kosiBirpur
          .fetchLatest()
          .timeout(_timeout);
      _kosiCache = _listToItems(
        data,
        SourceId.kosiBirpur,
        FeedItemKind.barrage,
        titleKey:    'station',
        valueKey:    'level',
        dangerKey:   'status',
        subtitleKey: 'river',
      );
      _setHealth(SourceId.kosiBirpur, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.kosiBirpur, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] Kosi: $e');
    }
    _emit();
  }

  Future<void> _fetchWris() async {
    final t0 = DateTime.now();
    try {
      final data = await _wris
          .fetchBiharTelemetry()
          .timeout(_timeout);
      _wrisCache = _listToItems(
        data,
        SourceId.wris,
        FeedItemKind.telemetry,
        titleKey:    'stationName',
        valueKey:    'waterLevel',
        dangerKey:   'alertLevel',
        subtitleKey: 'riverName',
      );
      _setHealth(SourceId.wris, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.wris, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] WRIS: $e');
    }
    _emit();
  }

  Future<void> _fetchRealTime() async {
    final t0 = DateTime.now();
    try {
      final data = await _rtRiver
          .fetchBiharGauges()
          .timeout(_timeout);
      _rtCache = _listToItems(
        data,
        SourceId.realTimeRiver,
        FeedItemKind.riverGauge,
        titleKey:    'name',
        valueKey:    'level',
        dangerKey:   'status',
        subtitleKey: 'river',
      );
      _setHealth(SourceId.realTimeRiver, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.realTimeRiver, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] RT-River: $e');
    }
    _emit();
  }

  Future<void> _fetchIndiaStations() async {
    final t0 = DateTime.now();
    try {
      final stations = await _indStations
          .fetchBiharStations()
          .timeout(_timeout);
      // Also try CWC BEFIQR for extra readings
      List<dynamic> befiqrData = [];
      try {
        befiqrData = await _befiqr.fetchBiharReadings().timeout(_timeout);
      } catch (_) {}

      final all = [
        ...stations.map((s) => _stationToItem(s as Map<String, dynamic>, SourceId.indiaStations)),
        ...befiqrData.map((s) => _stationToItem(s as Map<String, dynamic>, SourceId.cwcBefiqr)),
      ];
      _stationCache = all;
      _setHealth(SourceId.indiaStations, true, DateTime.now().difference(t0));
      if (befiqrData.isNotEmpty) {
        _setHealth(SourceId.cwcBefiqr, true, DateTime.now().difference(t0));
      }
    } catch (e) {
      _setHealth(SourceId.indiaStations, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] IndiaStations: $e');
    }
    _emit();
  }

  Future<void> _fetchNews() async {
    final t0 = DateTime.now();
    try {
      final items = await _news.fetchAll();
      _newsCache = items.map(_newsToItem).toList();
      _setHealth(SourceId.news, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.news, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] News: $e');
    }
    _emit();
  }

  // ── emit ──────────────────────────────────────────────────────────────────

  void _emit() {
    final all = [
      ..._gaugeCache,
      ..._kosiCache,
      ..._wrisCache,
      ..._rtCache,
      ..._stationCache,
      ..._newsCache,
    ];

    // Deduplicate by id
    final seen  = <String>{};
    final dedup = all.where((i) => seen.add(i.id)).toList();

    final feed = BiharLiveFeed(
      items:       dedup,
      health:      Map.unmodifiable(_health),
      generatedAt: DateTime.now(),
      isPartial:   _health.values.any((h) => !h.ok),
    );
    _latest = feed;
    if (!_controller.isClosed) _controller.add(feed);
    debugPrint('[BiharLiveEngine] emitted ${dedup.length} items '
        '(${feed.errorCount} source errors)');
  }

  // ── health helpers ────────────────────────────────────────────────────────

  void _setHealth(SourceId id, bool ok, Duration latency, [String? err]) {
    _health[id] = SourceHealth(
      id:          id,
      ok:          ok,
      error:       err,
      lastAttempt: DateTime.now(),
      latency:     latency,
    );
  }

  // ── item converters ───────────────────────────────────────────────────────

  /// WRD Bihar service map → BiharFeedItem
  BiharFeedItem _wrdToItem(dynamic raw) {
    final m       = (raw as Map<String, dynamic>? ?? {});
    final name    = m['stationName']?.toString()    ??
                    m['station']?.toString()        ??
                    m['name']?.toString()           ?? 'Bihar Station';
    final level   = m['waterLevel']?.toString()     ??
                    m['level']?.toString()          ?? '—';
    final danger  = m['dangerLevel']?.toString()    ??
                    m['alertStatus']?.toString()    ??
                    m['status']?.toString()         ?? '';
    final river   = m['riverName']?.toString()      ??
                    m['river']?.toString()          ?? '';
    final change  = m['change']?.toString()         ??
                    m['levelChange']?.toString()    ?? '';
    return BiharFeedItem(
      id:          'wrd|${name.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.wrdBihar,
      title:       name,
      subtitle:    river.isNotEmpty ? 'River: $river' : 'WRD Bihar',
      value:       level.isNotEmpty ? '$level m' : null,
      dangerLevel: danger,
      changeStr:   change.isNotEmpty ? change : null,
      fetchedAt:   DateTime.now(),
      severity:    _dangerToSeverity(danger),
      raw:         m,
    );
  }

  /// WRD scraper row → BiharFeedItem
  BiharFeedItem _scrapedToItem(Map<String, dynamic> m) {
    final name  = m['station']?.toString() ?? m['name']?.toString() ?? 'Station';
    final level = m['level']?.toString()   ?? m['waterLevel']?.toString() ?? '—';
    final status= m['status']?.toString()  ?? '';
    final river = m['river']?.toString()   ?? '';
    return BiharFeedItem(
      id:          'wrd_scrape|${name.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.wrdBihar,
      title:       name,
      subtitle:    river.isNotEmpty ? 'River: $river' : 'WRD Scrape',
      value:       level.isNotEmpty ? '$level m' : null,
      dangerLevel: status,
      fetchedAt:   DateTime.now(),
      severity:    _dangerToSeverity(status),
      raw:         m,
    );
  }

  /// Generic list-of-maps → list of BiharFeedItems
  List<BiharFeedItem> _listToItems(
    dynamic raw,
    SourceId source,
    FeedItemKind kind, {
    required String titleKey,
    required String valueKey,
    required String dangerKey,
    required String subtitleKey,
  }) {
    if (raw is! List) return [];
    return raw.map((e) {
      final m       = (e as Map<String, dynamic>? ?? {});
      final title   = m[titleKey]?.toString()   ?? 'Station';
      final value   = m[valueKey]?.toString()   ?? '—';
      final danger  = m[dangerKey]?.toString()  ?? '';
      final sub     = m[subtitleKey]?.toString() ?? source.name;
      return BiharFeedItem(
        id:          '${source.name}|${title.toLowerCase().trim()}',
        kind:        kind,
        source:      source,
        title:       title,
        subtitle:    sub,
        value:       value.isNotEmpty ? value : null,
        dangerLevel: danger,
        fetchedAt:   DateTime.now(),
        severity:    _dangerToSeverity(danger),
        raw:         m,
      );
    }).toList();
  }

  /// IndiaStations / BEFIQR map → BiharFeedItem
  BiharFeedItem _stationToItem(Map<String, dynamic> m, SourceId src) {
    final name   = m['stationName']?.toString()  ??
                   m['name']?.toString()         ?? 'CWC Station';
    final level  = m['waterLevel']?.toString()   ??
                   m['level']?.toString()        ?? '—';
    final status = m['alertLevel']?.toString()   ??
                   m['status']?.toString()       ?? '';
    final river  = m['riverName']?.toString()    ??
                   m['river']?.toString()        ?? '';
    return BiharFeedItem(
      id:          '${src.name}|${name.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      src,
      title:       name,
      subtitle:    river.isNotEmpty ? 'River: $river' : src.name,
      value:       level.isNotEmpty ? '$level m' : null,
      dangerLevel: status,
      fetchedAt:   DateTime.now(),
      severity:    _dangerToSeverity(status),
      raw:         m,
    );
  }

  /// NewsItem → BiharFeedItem
  BiharFeedItem _newsToItem(NewsItem n) => BiharFeedItem(
        id:          'news|${n.id}',
        kind:        n.severity == NewsSeverity.critical ||
                     n.severity == NewsSeverity.high
                         ? FeedItemKind.alert
                         : FeedItemKind.news,
        source:      SourceId.news,
        title:       n.title,
        subtitle:    '${n.source} · ${_fmtDate(n.publishedAt)}',
        url:         n.url,
        fetchedAt:   n.publishedAt,
        severity:    n.severity,
        raw:         {
          'summary': n.summary,
          'source':  n.source,
          'url':     n.url,
        },
      );

  // ── severity mapping ──────────────────────────────────────────────────────

  static NewsSeverity _dangerToSeverity(String status) {
    final s = status.toLowerCase();
    if (s.contains('danger') || s.contains('breach') ||
        s.contains('red')    || s.contains('extreme'))
      return NewsSeverity.critical;
    if (s.contains('warning') || s.contains('high') ||
        s.contains('orange')  || s.contains('above'))
      return NewsSeverity.high;
    if (s.contains('watch')  || s.contains('caution') ||
        s.contains('yellow') || s.contains('moderate'))
      return NewsSeverity.moderate;
    return NewsSeverity.info;
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
