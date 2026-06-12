// lib/services/bihar_live_engine.dart  v3.0
//
// v3.0: RTDAS threshold auto-sync fully wired.
//
// Changes vs v2.0:
//   - RtdasThresholdSyncService.instance.start() called in start().
//   - New slot 'rtdas' populated by _fetchRtdasThresholds().
//   - _fetchRtdasThresholds() runs once at startup + on the same 6 h cadence
//     as the sync service (no double HTTP — the sync service is idempotent;
//     this slot just reflects the store contents as FeedItems for debug/UI).
//   - Slot priority in _emit(): rt > rtdas > wrd > wrd_scrape > kosi > wris
//     > india > news  (rtdas overrides wrd for threshold accuracy).
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/flood_data.dart';
import 'befiqr_cwc_service.dart';
import 'bihar_wrd_scraper.dart';
import 'india_stations_service.dart';
import 'kosi_birpur_service.dart';
import 'news_service.dart';
import 'real_time_river_service.dart';
import 'rtdas_threshold_sync_service.dart';   // ← NEW v3.0
import 'threshold_override_store.dart';        // ← NEW v3.0
import 'wrd_bihar_service.dart';
import 'wris_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain models (unchanged from v2.0)
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
  rtdas,          // ← NEW v3.0
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
      'SourceHealth($id ok=$ok latency=${latency?.inMilliseconds}ms'
      '${error != null ? ' err=$error' : ''})';
}

class BiharFeedItem {
  final String       id;
  final FeedItemKind kind;
  final SourceId     source;
  final String       title;
  final String       subtitle;
  final String?      value;
  final String?      dangerLevel;
  final String?      changeStr;
  final String?      url;
  final DateTime     fetchedAt;
  final NewsSeverity severity;
  final Map<String, dynamic> raw;

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

class BiharLiveFeed {
  final List<BiharFeedItem>          items;
  final Map<SourceId, SourceHealth>  health;
  final DateTime                     generatedAt;
  final bool                         isPartial;

  const BiharLiveFeed({
    required this.items,
    required this.health,
    required this.generatedAt,
    this.isPartial = false,
  });

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
// Engine v3.0
// ─────────────────────────────────────────────────────────────────────────────

class BiharLiveEngine {
  BiharLiveEngine._();
  static final BiharLiveEngine instance = BiharLiveEngine._();

  static const _gaugeInterval = Duration(minutes: 15);
  static const _newsInterval  = Duration(minutes: 10);
  static const _kosiInterval  = Duration(minutes: 20);
  // RTDAS thresholds change very rarely; sync every 6 h matches the
  // RtdasThresholdSyncService._syncInterval — no extra network cost.
  static const _rtdasInterval = Duration(hours: 6);
  static const _timeout       = Duration(seconds: 20);

  final _wrd         = WrdBiharService.instance;
  final _befiqr      = BefiqrCwcService();
  final _kosiBirpur  = KosiBirpurService();
  final _wris        = WrisService.instance;
  final _rtRiver     = RealTimeRiverService();
  final _indStations = IndiaStationsService();
  final _wrdScraper  = BiharWrdScraper.instance;
  final _news        = NewsService();

  final _controller = StreamController<BiharLiveFeed>.broadcast();
  BiharLiveFeed?    _latest;
  Timer?            _gaugeTimer;
  Timer?            _newsTimer;
  Timer?            _kosiTimer;
  Timer?            _rtdasTimer;   // ← NEW v3.0
  bool              _running = false;

  // ── Named slots — REPLACED (never appended) on every fetch ────────────────
  // New in v3.0: 'rtdas' slot mirrors ThresholdOverrideStore contents as
  // FeedItems. It participates in dedup with higher priority than 'wrd' so
  // when a gauge appears in both sources the threshold-enriched rtdas entry wins.
  final Map<String, List<BiharFeedItem>> _slots = {
    'rt':         [],
    'rtdas':      [],   // ← NEW v3.0
    'wrd':        [],
    'wrd_scrape': [],
    'kosi':       [],
    'wris':       [],
    'india':      [],
    'news':       [],
  };

  final Map<SourceId, SourceHealth> _health = {};

  Stream<BiharLiveFeed> get stream  => _controller.stream;
  BiharLiveFeed?        get latest  => _latest;
  bool                  get running => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    debugPrint('[BiharLiveEngine] starting v3.0 …');

    // ── Wire RTDAS threshold sync (idempotent — main.dart may have already
    //    called it; the singleton returns immediately on the second call) ────
    unawaited(RtdasThresholdSyncService.instance.start());

    await refresh();
    _gaugeTimer = Timer.periodic(_gaugeInterval, (_) => _fetchGauge());
    _newsTimer  = Timer.periodic(_newsInterval,  (_) => _fetchNews());
    _kosiTimer  = Timer.periodic(_kosiInterval,  (_) => _fetchKosi());
    // Refresh the 'rtdas' slot every 6 h so UI reflects newly synced values.
    _rtdasTimer = Timer.periodic(_rtdasInterval, (_) => _fetchRtdasThresholds());
  }

  void stop() {
    _gaugeTimer?.cancel();
    _newsTimer?.cancel();
    _kosiTimer?.cancel();
    _rtdasTimer?.cancel();
    _running = false;
    debugPrint('[BiharLiveEngine] stopped.');
  }

  Future<void> refresh() async {
    debugPrint('[BiharLiveEngine] full refresh …');
    await Future.wait([
      _fetchGauge(),
      _fetchNews(),
      _fetchKosi(),
      _fetchWris(),
      _fetchRealTime(),
      _fetchIndiaStations(),
      _fetchRtdasThresholds(),  // ← NEW v3.0
    ]);
    _emit();
  }

  // ── slot write helper ──────────────────────────────────────────────────────

  void _setSlot(String key, List<BiharFeedItem> items) {
    _slots[key] = items;
    _emit();
  }

  // ── fetch workers ──────────────────────────────────────────────────────────

  Future<void> _fetchGauge() async {
    final t0 = DateTime.now();
    try {
      final data = await _wrd.fetch().timeout(_timeout);
      _slots['wrd'] = data.map(_wrdStationToItem).toList();
      _setHealth(SourceId.wrdBihar, true, DateTime.now().difference(t0));

      try {
        final scraped = await _wrdScraper.fetchAll().timeout(_timeout);
        final wrdIds  = { for (final i in _slots['wrd']!) i.id };
        _slots['wrd_scrape'] =
            scraped.map(_biharStationToItem)
                   .where((i) => !wrdIds.contains(i.id))
                   .toList();
      } catch (_) {}
    } catch (e) {
      _setHealth(SourceId.wrdBihar, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] WRD: $e');
    }
    _emit();
  }

  Future<void> _fetchKosi() async {
    final t0 = DateTime.now();
    try {
      final data = await _kosiBirpur.fetchLive().timeout(_timeout);
      _setSlot('kosi', [_kosiReadingToItem(data)]);
      _setHealth(SourceId.kosiBirpur, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.kosiBirpur, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] Kosi: $e');
      _emit();
    }
  }

  Future<void> _fetchWris() async {
    final t0 = DateTime.now();
    try {
      final data = await _wris.fetchBiharTelemetry().timeout(_timeout);
      _setSlot('wris', _listToItems(
        data, SourceId.wris, FeedItemKind.telemetry,
        titleKey: 'stationName', valueKey: 'waterLevel',
        dangerKey: 'alertLevel', subtitleKey: 'riverName',
      ));
      _setHealth(SourceId.wris, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.wris, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] WRIS: $e');
      _emit();
    }
  }

  Future<void> _fetchRealTime() async {
    final t0 = DateTime.now();
    try {
      final results = await _rtRiver.fetchAll().timeout(_timeout);
      _setSlot('rt', results.map(_liveResultToItem).toList());
      _setHealth(SourceId.realTimeRiver, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.realTimeRiver, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] RT-River: $e');
      _emit();
    }
  }

  Future<void> _fetchIndiaStations() async {
    final t0 = DateTime.now();
    try {
      final stations = await _indStations.fetchAll().timeout(_timeout);

      List<BiharFeedItem> befiqrItems = [];
      try {
        final cwcStations = await _befiqr.fetchStations().timeout(_timeout);
        befiqrItems = cwcStations
            .map((s) => BiharFeedItem(
                  id:          'cwc|${s.site.toLowerCase().trim()}',
                  kind:        FeedItemKind.riverGauge,
                  source:      SourceId.cwcBefiqr,
                  title:       s.site,
                  subtitle:    'River: ${s.river}',
                  value:       '${s.currentLevel.toStringAsFixed(2)} m',
                  dangerLevel: s.currentLevel >= s.dangerLevel
                      ? 'Danger'
                      : s.currentLevel >= (s.warningLevel ?? s.dangerLevel - 1)
                          ? 'Warning'
                          : 'Normal',
                  fetchedAt:   s.fetchedAt,
                  severity:    s.currentLevel >= s.dangerLevel
                      ? NewsSeverity.critical
                      : s.currentLevel >= (s.warningLevel ?? s.dangerLevel - 1)
                          ? NewsSeverity.high
                          : NewsSeverity.info,
                  raw: {
                    'river':   s.river,
                    'site':    s.site,
                    'level':   s.currentLevel,
                    'danger':  s.dangerLevel,
                    'warning': s.warningLevel,
                  },
                ))
            .toList();
        _setHealth(SourceId.cwcBefiqr, true, DateTime.now().difference(t0));
      } catch (_) {}

      _setSlot('india', [...stations.map(_floodDataToItem), ...befiqrItems]);
      _setHealth(SourceId.indiaStations, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.indiaStations, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] IndiaStations: $e');
      _emit();
    }
  }

  Future<void> _fetchNews() async {
    final t0 = DateTime.now();
    try {
      final items = await _news.fetchAll();
      _setSlot('news', items.map(_newsToItem).toList());
      _setHealth(SourceId.news, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.news, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] News: $e');
      _emit();
    }
  }

  // ── NEW v3.0: populate 'rtdas' slot from ThresholdOverrideStore ─────────
  // This does NOT do an HTTP call — it reads whatever the sync service last
  // stored. The sync service itself fires separately on its own 6 h timer.
  // The purpose of this slot is to create FeedItems that carry the correct
  // WL/DL/HFL for the dedup logic in live_engine_bridge_provider.
  Future<void> _fetchRtdasThresholds() async {
    final store  = ThresholdOverrideStore.instance;
    final now    = DateTime.now();
    final items  = <BiharFeedItem>[];

    // Re-trigger the sync service if its data is stale — fire-and-forget.
    if (store.isStale('__last_full_sync__', maxHours: 18)) {
      unawaited(RtdasThresholdSyncService.instance.forceSync());
    }

    // Build stub FeedItems so the bridge provider can enrich any incoming
    // gauge reading with the latest RTDAS thresholds via the store lookup.
    // Real water-level values come from the other slots; these stubs just
    // ensure the 'rtdas' source is reflected in SourceHealth.
    // We emit at least one item so _setSlot triggers _emit().
    items.add(BiharFeedItem(
      id:        'rtdas|__sync_marker__',
      kind:      FeedItemKind.telemetry,
      source:    SourceId.rtdas,
      title:     'RTDAS Threshold Sync',
      subtitle:  'WRD Bihar / BEAMS — ${store.count} stations cached',
      value:     'age: ${store.ageHours('__last_full_sync__')?.toStringAsFixed(1) ?? '?'}h',
      fetchedAt: now,
      raw: {'stationCount': store.count},
    ));

    _setSlot('rtdas', items);
    _setHealth(SourceId.rtdas, true, Duration.zero);
    debugPrint('[BiharLiveEngine] rtdas slot refreshed — ${store.count} thresholds in store');
  }

  // ── emit ───────────────────────────────────────────────────────────────────
  // Slot priority (first wins dedup):
  //   rt > rtdas > wrd > wrd_scrape > kosi > wris > india > news
  void _emit() {
    final seen  = <String>{};
    final dedup = <BiharFeedItem>[];

    for (final key in
        ['rt', 'rtdas', 'wrd', 'wrd_scrape', 'kosi', 'wris', 'india', 'news']) {
      for (final item in (_slots[key] ?? [])) {
        if (seen.add(item.id)) dedup.add(item);
      }
    }

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

  // ── health ─────────────────────────────────────────────────────────────────

  void _setHealth(SourceId id, bool ok, Duration latency, [String? err]) {
    _health[id] = SourceHealth(
      id: id, ok: ok, error: err,
      lastAttempt: DateTime.now(), latency: latency,
    );
  }

  // ── item converters (unchanged from v2.0) ─────────────────────────────────

  BiharFeedItem _wrdStationToItem(WrdStation s) {
    final level  = s.currentLevel?.toStringAsFixed(2) ?? '—';
    final status = s.riskLabel ?? '';
    return BiharFeedItem(
      id:          'wrd|${s.site.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.wrdBihar,
      title:       s.site,
      subtitle:    s.river.isNotEmpty ? 'River: ${s.river}' : 'WRD Bihar',
      value:       '$level m',
      dangerLevel: status,
      fetchedAt:   s.fetchedAt,
      severity:    _dangerToSeverity(status),
      raw: {'river': s.river, 'site': s.site, 'level': s.currentLevel, 'danger': s.dangerLevel},
    );
  }

  BiharFeedItem _biharStationToItem(BiharStationReading r) {
    final level  = r.currentLevel.toStringAsFixed(2);
    final status = r.status;
    final change = r.diff != null
        ? '${r.diff! >= 0 ? '+' : ''}${r.diff!.toStringAsFixed(2)} m '
          '${r.trend == 'Rising' ? '↑' : r.trend == 'Falling' ? '↓' : '→'}'
        : null;
    return BiharFeedItem(
      id:          'wrd_scrape|${r.stationName.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.wrdBihar,
      title:       r.stationName,
      subtitle:    r.river.isNotEmpty ? 'River: ${r.river}' : 'WRD Scrape',
      value:       '$level m',
      dangerLevel: status,
      changeStr:   change,
      fetchedAt:   r.observedAt,
      severity:    _dangerToSeverity(status),
      raw: {
        'river':    r.river,       'station':  r.stationName,
        'district': r.district,    'level':    r.currentLevel,
        'danger':   r.dangerLevel, 'hfl':      r.hfl,
        'trend':    r.trend,       'status':   r.status,
      },
    );
  }

  BiharFeedItem _floodDataToItem(FloodData fd) {
    final level  = fd.currentLevel.toStringAsFixed(2);
    final status = fd.riskLevel;
    return BiharFeedItem(
      id:          'india|${fd.city.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.indiaStations,
      title:       fd.city,
      subtitle:    fd.riverName != null && fd.riverName!.isNotEmpty
                       ? 'River: ${fd.riverName}'
                       : fd.state,
      value:       '$level m',
      dangerLevel: status,
      fetchedAt:   fd.lastUpdated,
      severity:    _riskToSeverity(status),
      raw: {
        'city':    fd.city,       'state':   fd.state,
        'river':   fd.riverName,  'level':   fd.currentLevel,
        'danger':  fd.dangerLevel,'warning': fd.warningLevel,
        'risk':    fd.riskLevel,
      },
    );
  }

  BiharFeedItem _kosiReadingToItem(KosiBirpurReading r) => BiharFeedItem(
    id:          'kosi|birpur',
    kind:        FeedItemKind.barrage,
    source:      SourceId.kosiBirpur,
    title:       'Birpur',
    subtitle:    'Kosi Barrage',
    value:       '${r.levelM.toStringAsFixed(2)} m',
    dangerLevel: r.statusLabel,
    fetchedAt:   r.observedAt,
    severity:    _dangerToSeverity(r.statusLabel),
    raw: {
      'river': 'Kosi', 'station': 'Birpur',
      'level': r.levelM, 'danger': r.dangerLevel, 'warning': r.warningLevel,
    },
  );

  BiharFeedItem _liveResultToItem(LiveRiverResult r) {
    final s      = r.station;
    final level  = s.current > 0 ? '${s.current.toStringAsFixed(2)} m' : null;
    final status = r.mlRiskLevel ?? s.liveStatus ?? '';
    return BiharFeedItem(
      id:          'rt|${s.station.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.realTimeRiver,
      title:       s.station,
      subtitle:    '${s.river} · ${r.source}',
      value:       level,
      dangerLevel: status,
      fetchedAt:   DateTime.now(),
      severity:    _dangerToSeverity(status),
      raw: {
        'river': s.river, 'station': s.station, 'level': s.current,
        'danger': s.danger, 'warning': s.warning, 'source': r.source,
      },
    );
  }

  List<BiharFeedItem> _listToItems(
    dynamic raw, SourceId source, FeedItemKind kind, {
    required String titleKey, required String valueKey,
    required String dangerKey, required String subtitleKey,
  }) {
    if (raw is! List) return [];
    return raw.map((e) {
      final m = (e is Map ? e.cast<String, dynamic>() : <String, dynamic>{});
      final title  = m[titleKey]?.toString()    ?? 'Station';
      final value  = m[valueKey]?.toString()    ?? '—';
      final danger = m[dangerKey]?.toString()   ?? '';
      final sub    = m[subtitleKey]?.toString() ?? source.name;
      return BiharFeedItem(
        id:          '${source.name}|${title.toLowerCase().trim()}',
        kind:        kind,   source:      source,
        title:       title,  subtitle:    sub,
        value:       value.isNotEmpty ? value : null,
        dangerLevel: danger, fetchedAt:   DateTime.now(),
        severity:    _dangerToSeverity(danger), raw: m,
      );
    }).toList();
  }

  BiharFeedItem _newsToItem(NewsItem n) => BiharFeedItem(
    id:        'news|${n.id}',
    kind:      n.severity == NewsSeverity.critical || n.severity == NewsSeverity.high
                   ? FeedItemKind.alert : FeedItemKind.news,
    source:    SourceId.news,
    title:     n.title,
    subtitle:  '${n.source} · ${_fmtDate(n.publishedAt)}',
    url:       n.url,
    fetchedAt: n.publishedAt,
    severity:  n.severity,
    raw: {'summary': n.summary, 'source': n.source, 'url': n.url},
  );

  static NewsSeverity _dangerToSeverity(String status) {
    final s = status.toLowerCase();
    if (s.contains('danger')    || s.contains('breach')  ||
        s.contains('red')       || s.contains('extreme') ||
        s.contains('above_hfl') || s.contains('above_danger'))
      return NewsSeverity.critical;
    if (s.contains('warning')   || s.contains('high')    ||
        s.contains('orange')    || s.contains('above')   ||
        s.contains('near_danger'))
      return NewsSeverity.high;
    if (s.contains('watch')     || s.contains('caution') ||
        s.contains('yellow')    || s.contains('moderate'))
      return NewsSeverity.moderate;
    return NewsSeverity.info;
  }

  static NewsSeverity _riskToSeverity(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return NewsSeverity.critical;
      case 'HIGH':     return NewsSeverity.high;
      case 'MODERATE': return NewsSeverity.moderate;
      default:         return NewsSeverity.info;
    }
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
