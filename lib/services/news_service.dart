// lib/services/news_service.dart  v3.0
// Multi-source flood news aggregator — last 7 days.
//
// SOURCES (all parallel):
//   A. IMD FFS RSS           — ffs.imd.gov.in
//   B. IMD FFS daily archive — loops last 7 daily bulletin URLs
//   C. NDMA advisories JSON  — ndma.gov.in (limit=50)
//   D. CWC Bihar bulletin    — cwc.gov.in JSON
//   E. CWC flood archive RSS — cwc.gov.in/fld_mng/floodmain.htm
//   F. India-WRIS JSON       — indiawris.gov.in
//   G. GDACS GeoJSON         — gdacs.org (global flood events, India filtered)
//   H. PIB RSS               — pib.gov.in (flood-keyword filtered)
//
// All items older than 7 days are discarded.
// fetchAll() dedupes by id (source|title), sorts: severity desc → date desc.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

enum NewsSeverity { critical, high, moderate, info }

class NewsItem {
  final String       title;
  final String       summary;
  final String       url;
  final String       source;
  final DateTime     publishedAt;
  final NewsSeverity severity;

  const NewsItem({
    required this.title,
    required this.summary,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.severity,
  });

  String get id => '$source|${title.toLowerCase().trim()}';

  /// Day bucket: yyyy-MM-dd  (used for grouping in the UI)
  String get dayKey {
    final d = publishedAt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }
}

class NewsFilter {
  final int            days;        // 1 | 3 | 7
  final Set<String>    sources;     // empty = all
  final Set<NewsSeverity> severities; // empty = all

  const NewsFilter({
    this.days       = 7,
    this.sources    = const {},
    this.severities = const {},
  });

  NewsFilter copyWith({
    int? days,
    Set<String>? sources,
    Set<NewsSeverity>? severities,
  }) => NewsFilter(
    days:       days       ?? this.days,
    sources:    sources    ?? this.sources,
    severities: severities ?? this.severities,
  );
}

class NewsService {
  static const _timeout     = Duration(seconds: 12);
  static const _kMaxDays    = 7;

  static final _kFloodWords = [
    'flood', 'rain', 'cyclone', 'inundation', 'disaster',
    'relief', 'storm', 'deluge', 'landslide', 'cloudburst',
    'alert', 'warning', 'advisory', 'evacuat',
  ];

  // ── public ─────────────────────────────────────────────────────────────
  Future<List<NewsItem>> fetchAll() async {
    final cutoff = DateTime.now().subtract(const Duration(days: _kMaxDays));

    final results = await Future.wait([
      _tryImdRss(),
      _tryImdDailyArchive(cutoff),
      _tryNdma(),
      _tryCwcBulletin(),
      _tryCwcArchiveRss(),
      _tryWris(),
      _tryGdacs(),
      _tryPib(),
    ], eagerError: false);

    final merged = <String, NewsItem>{};
    for (final list in results) {
      for (final item in list) {
        if (item.publishedAt.isAfter(cutoff)) {
          merged.putIfAbsent(item.id, () => item);
        }
      }
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        final sc = b.severity.index.compareTo(a.severity.index);
        if (sc != 0) return sc;
        return b.publishedAt.compareTo(a.publishedAt);
      });

    debugPrint('[NewsService] fetchAll → ${sorted.length} items (cutoff: ${_fmtDate(cutoff)})');
    return sorted;
  }

  /// Client-side filter applied after fetchAll()
  static List<NewsItem> applyFilter(List<NewsItem> all, NewsFilter f) {
    final cutoff = DateTime.now().subtract(Duration(days: f.days));
    return all.where((item) {
      if (item.publishedAt.isBefore(cutoff))            return false;
      if (f.sources.isNotEmpty    && !f.sources.contains(item.source))       return false;
      if (f.severities.isNotEmpty && !f.severities.contains(item.severity))  return false;
      return true;
    }).toList();
  }

  /// Group a filtered list by day (newest day first)
  static Map<String, List<NewsItem>> groupByDay(List<NewsItem> items) {
    final map = <String, List<NewsItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.dayKey, () => []).add(item);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return { for (final k in keys) k: map[k]! };
  }

  // ── Source A: IMD FFS RSS ──────────────────────────────────────────────
  Future<List<NewsItem>> _tryImdRss() async {
    const url = 'https://ffs.imd.gov.in/rss/alerts.xml';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0',
        'Accept':     'application/rss+xml,text/xml',
      }).timeout(_timeout);
      if (resp.statusCode == 200) return _parseRss(resp.body, 'IMD');
    } catch (e) { debugPrint('[NewsService] IMD-RSS: $e'); }
    return [];
  }

  // ── Source B: IMD FFS daily bulletin archive (last 7 days) ──────────────
  Future<List<NewsItem>> _tryImdDailyArchive(DateTime cutoff) async {
    final items  = <NewsItem>[];
    final today  = DateTime.now();
    final fmt    = DateFormat('ddMMyyyy');
    // IMD publishes dated PDF bulletins at a predictable URL pattern.
    // We probe each of the last 7 days and return a link-item for each found.
    for (var i = 0; i < _kMaxDays; i++) {
      final d      = today.subtract(Duration(days: i));
      if (d.isBefore(cutoff)) break;
      final dStr   = fmt.format(d);
      final url    = 'https://ffs.imd.gov.in/flood_bulletin/flood_bulletin_$dStr.pdf';
      try {
        final resp = await http.head(Uri.parse(url), headers: {
          'User-Agent': 'OpsFlood/4.0',
        }).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200 || resp.statusCode == 302) {
          items.add(NewsItem(
            title:       'IMD Flood Bulletin — ${DateFormat('dd MMM yyyy').format(d)}',
            summary:     'Official IMD flood situation bulletin. Tap to open PDF.',
            url:         url,
            source:      'IMD',
            publishedAt: DateTime(d.year, d.month, d.day, 8),
            severity:    NewsSeverity.info,
          ));
        }
      } catch (_) {}
    }
    return items;
  }

  // ── Source C: NDMA advisories JSON ───────────────────────────────────────
  Future<List<NewsItem>> _tryNdma() async {
    const url = 'https://ndma.gov.in/api/v1/advisories?format=json&limit=50';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/json',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['results']    as List? ??
                      body['advisories'] as List? ??
                      body              as List?)?.cast<Map<String, dynamic>>() ?? [];
        final now  = DateTime.now();
        return list.map((r) {
          final title   = r['title']?.toString()       ?? r['heading']?.toString()      ?? 'NDMA Advisory';
          final summary = r['summary']?.toString()     ?? r['description']?.toString()  ?? '';
          final urlStr  = r['url']?.toString()         ?? r['link']?.toString()          ?? 'https://ndma.gov.in';
          final pub     = DateTime.tryParse(r['date']?.toString() ?? r['issued_at']?.toString() ?? '') ?? now;
          return NewsItem(title: title, summary: summary, url: urlStr,
            source: 'NDMA', publishedAt: pub, severity: _severity(title + summary));
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] NDMA: $e'); }
    return [];
  }

  // ── Source D: CWC Bihar Bulletin JSON ─────────────────────────────────────
  Future<List<NewsItem>> _tryCwcBulletin() async {
    const url = 'https://cwc.gov.in/fld_mng/bihar_flood_bulletin.json';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/json',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final body     = jsonDecode(resp.body);
        final bulletin = body['bulletin']?.toString() ?? body['remarks']?.toString() ?? '';
        final date     = DateTime.tryParse(
            body['date']?.toString() ?? body['issued_at']?.toString() ?? '') ?? DateTime.now();
        if (bulletin.isEmpty) return [];
        return [NewsItem(
          title:       'CWC Bihar Flood Bulletin — ${_fmtDate(date)}',
          summary:     bulletin.length > 400 ? '${bulletin.substring(0, 397)}…' : bulletin,
          url:         'https://cwc.gov.in/fld_mng',
          source:      'CWC',
          publishedAt: date,
          severity:    _severity(bulletin),
        )];
      }
    } catch (e) { debugPrint('[NewsService] CWC-Bulletin: $e'); }
    return [];
  }

  // ── Source E: CWC flood archive RSS ────────────────────────────────────────
  Future<List<NewsItem>> _tryCwcArchiveRss() async {
    const url = 'https://cwc.gov.in/rss/flood_news.xml';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0', 'Accept': 'text/xml,application/rss+xml',
      }).timeout(_timeout);
      if (resp.statusCode == 200) return _parseRss(resp.body, 'CWC');
    } catch (e) { debugPrint('[NewsService] CWC-RSS: $e'); }
    return [];
  }

  // ── Source F: India-WRIS JSON ──────────────────────────────────────────────
  Future<List<NewsItem>> _tryWris() async {
    const apiUrl = 'https://indiawris.gov.in/wris/api/floodNews?limit=30';
    try {
      final resp = await http.get(Uri.parse(apiUrl), headers: {
        'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/json',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['data'] as List? ?? body as List?)?.cast<Map<String, dynamic>>() ?? [];
        final now  = DateTime.now();
        return list.map((r) {
          final title   = r['title']?.toString()   ?? r['heading']?.toString()  ?? 'WRIS Update';
          final summary = r['summary']?.toString() ?? r['body']?.toString()     ?? '';
          final urlStr  = r['url']?.toString()     ?? r['link']?.toString()     ?? 'https://indiawris.gov.in';
          final pub     = DateTime.tryParse(r['date']?.toString() ?? r['published']?.toString() ?? '') ?? now;
          return NewsItem(title: title, summary: summary, url: urlStr,
            source: 'WRIS', publishedAt: pub, severity: _severity(title + summary));
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] WRIS: $e'); }
    return [];
  }

  // ── Source G: GDACS GeoJSON (global flood events, India only) ────────────
  Future<List<NewsItem>> _tryGdacs() async {
    // GDACS RSS for floods in Asia/India
    const url = 'https://www.gdacs.org/xml/rss_fl.xml';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0', 'Accept': 'text/xml,application/rss+xml',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'GDACS');
        return all.where((item) {
          final t = (item.title + item.summary).toLowerCase();
          return t.contains('india') || t.contains('bihar') ||
                 t.contains('assam') || t.contains('bengal') ||
                 t.contains('odisha') || t.contains('flood');
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] GDACS: $e'); }
    return [];
  }

  // ── Source H: PIB RSS (flood-keyword filtered) ──────────────────────────
  Future<List<NewsItem>> _tryPib() async {
    const url = 'https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3';
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'OpsFlood/4.0', 'Accept': 'text/xml,application/rss+xml',
      }).timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'PIB');
        return all.where((item) {
          final t = (item.title + item.summary).toLowerCase();
          return _kFloodWords.any(t.contains);
        }).toList();
      }
    } catch (e) { debugPrint('[NewsService] PIB: $e'); }
    return [];
  }

  // ── RSS parser ───────────────────────────────────────────────────────────
  static List<NewsItem> _parseRss(String xml, String source) {
    final items = <NewsItem>[];
    try {
      final doc   = html_parser.parse(xml);
      final nodes = doc.querySelectorAll('item');
      for (final node in nodes) {
        final title   = node.querySelector('title')?.text.trim()       ?? '';
        final desc    = node.querySelector('description')?.text.trim() ?? '';
        final link    = node.querySelector('link')?.text.trim()        ??
                        node.querySelector('guid')?.text.trim()        ?? '';
        final pubDate = node.querySelector('pubDate')?.text.trim()     ??
                        node.querySelector('dc\\:date')?.text.trim()   ?? '';
        if (title.isEmpty) continue;
        final cleanDesc = html_parser.parse(desc).body?.text.trim() ?? desc;
        final truncated = cleanDesc.length > 300
            ? '${cleanDesc.substring(0, 297)}…'
            : cleanDesc;
        items.add(NewsItem(
          title:       title,
          summary:     truncated,
          url:         link,
          source:      source,
          publishedAt: _parseRssDate(pubDate),
          severity:    _severity(title + cleanDesc),
        ));
      }
    } catch (e) {
      debugPrint('[NewsService] RSS parse ($source): $e');
    }
    return items;
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  static DateTime _parseRssDate(String s) {
    if (s.isEmpty) return DateTime.now();
    // Try standard ISO first
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    // RFC 2822: 'Wed, 11 Jun 2026 14:00:00 +0530'
    try {
      return DateFormat('EEE, dd MMM yyyy HH:mm:ss Z').parseUTC(s).toLocal();
    } catch (_) {}
    try {
      return DateFormat('EEE, dd MMM yyyy HH:mm:ss zzz').parse(s);
    } catch (_) {}
    return DateTime.now();
  }

  static NewsSeverity _severity(String text) {
    final t = text.toLowerCase();
    if (t.contains('red alert')     || t.contains('extreme')      ||
        t.contains('catastrophic')  || t.contains('danger level') ||
        t.contains('breach')        || t.contains('evacuate')     ||
        t.contains('red warning'))  return NewsSeverity.critical;
    if (t.contains('orange alert')  || t.contains('severe')       ||
        t.contains('above danger')  || t.contains('warning level')||
        t.contains('flood warning') || t.contains('orange warning')) return NewsSeverity.high;
    if (t.contains('yellow alert')  || t.contains('heavy rain')   ||
        t.contains('moderate')      || t.contains('watch')        ||
        t.contains('yellow warning')) return NewsSeverity.moderate;
    return NewsSeverity.info;
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
