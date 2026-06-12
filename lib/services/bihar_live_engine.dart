// lib/services/bihar_live_engine.dart  v2.0
//
// v2.0 fix: replace per-source List caches with named Map slots.
//
// PROBLEM (v1.x): six separate List fields (_gaugeCache, _kosiCache, …).
// _fetchGauge() called _gaugeCache.addAll(scraperItems) on every invocation,
// so the scraper batch accumulated: 31→63→158→190 items across refresh cycles.
//
// FIX: _slots is a Map<String, List<BiharFeedItem>> with fixed keys.
// Each fetch worker calls _setSlot(key, items) which REPLACES the slot.
// _emit() flattens all slots fresh every time — no accumulation possible.
//
// Slot keys (stable, never change):
//   'wrd'          WrdBiharService.fetch()
//   'wrd_scrape'   BiharWrdScraper.fetchAll()
//   'kosi'         KosiBirpurService
//   'wris'         WrisService
//   'rt'           RealTimeRiverService
//   'india'        IndiaStationsService + BefiqrCwcService
//   'news'         NewsService
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
      'SourceHealth($id ok=$ok latency=${latency?.inMilliseconds}ms'
      '${error != null ? ' err=$error' : ''})';
}

/// A single normalised feed card — consumed directly by the Flutter feed UI.
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

/// The complete snapshot emitted on every refresh cycle.
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
// Engine
// ─────────────────────────────────────────────────────────────────────────────

class BiharLiveEngine {
  BiharLiveEngine._();
  static final BiharLiveEngine instance = BiharLiveEngine._();

  static const _gaugeInterval = Duration(minutes: 15);
  static const _newsInterval  = Duration(minutes: 10);
  static const _kosiInterval  = Duration(minutes: 20);
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
  bool              _running = false;

  // ── Named slots — each key is REPLACED (never appended) on every fetch ──────
  // Fixed slot keys:
  //   'wrd'        → WrdBiharService live stations
  //   'wrd_scrape' → BiharWrdScraper HTML scrape
  //   'kosi'       → KosiBirpurService barrage reading
  //   'wris'       → WrisService telemetry
  //   'rt'         → RealTimeRiverService RTRS results
  //   'india'      → IndiaStationsService + BefiqrCwcService
  //   'news'       → NewsService headlines
  final Map<String, List<BiharFeedItem>> _slots = {
    'wrd':        [],
    'wrd_scrape': [],
    'kosi':       [],
    'wris':       [],
    'rt':         [],
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
    debugPrint('[BiharLiveEngine] starting …');
    await refresh();
    _gaugeTimer = Timer.periodic(_gaugeInterval, (_) => _fetchGauge());
    _newsTimer  = Timer.periodic(_newsInterval,  (_) => _fetchNews());
    _kosiTimer  = Timer.periodic(_kosiInterval,  (_) => _fetchKosi());
  }

  void stop() {
    _gaugeTimer?.cancel();
    _newsTimer?.cancel();
    _kosiTimer?.cancel();
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
    ]);
    // _emit() is called inside each fetch worker, but call once more after
    // all finish so the final fully-populated snapshot is broadcast.
    _emit();
  }

  // ── slot write helper ──────────────────────────────────────────────────────

  /// Atomically replace a named slot and re-emit.
  void _setSlot(String key, List<BiharFeedItem> items) {
    _slots[key] = items;
    _emit();
  }

  // ── fetch workers ──────────────────────────────────────────────────────────

  Future<void> _fetchGauge() async {
    final t0 = DateTime.now();
    try {
      // 'wrd' slot: WrdBiharService (API/cache) — replaced atomically.
      final data = await _wrd.fetch().timeout(_timeout);
      _slots['wrd'] = data.map(_wrdStationToItem).toList();
      _setHealth(SourceId.wrdBihar, true, DateTime.now().difference(t0));

      // 'wrd_scrape' slot: BiharWrdScraper (HTML bulletin) — separate slot
      // so the scraper result never grows the 'wrd' slot on each call.
      try {
        final scraped = await _wrdScraper.fetchAll().timeout(_timeout);
        // Only keep scraper stations not already present in the WRD slot.
        final wrdIds  = { for (final i in _slots['wrd']!) i.id };
        _slots['wrd_scrape'] =
            scraped.map(_biharStationToItem)
                   .where((i) => !wrdIds.contains(i.id))
                   .toList();
      } catch (_) {
        // Scraper failure is non-fatal; keep whatever was in the slot.
      }
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

  // ── emit ───────────────────────────────────────────────────────────────────
  // Reads ALL slots fresh, flattens, deduplicates by id, then broadcasts once.
  // Because every slot is replaced (never appended), the item count is always
  // the union of current slot sizes — it can never grow unboundedly.

  void _emit() {
    final seen  = <String>{};
    final dedup = <BiharFeedItem>[];

    // Slot iteration order determines priority for dedup:
    // rt > wrd > wrd_scrape > kosi > wris > india > news
    for (final key in ['rt', 'wrd', 'wrd_scrape', 'kosi', 'wris', 'india', 'news']) {
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

  // ── item converters ───────────────────────────────────────────────────────

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

  // ── severity ───────────────────────────────────────────────────────────────

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
