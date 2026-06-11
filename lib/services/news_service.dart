// lib/services/news_service.dart
// Multi-source flood news / alert aggregator.
//
// SOURCES (all fired in parallel per refresh):
//   A. IMD FFS RSS    — ffs.imd.gov.in  (flood forecasting bulletins)
//   B. NDMA advisories JSON — ndma.gov.in public API
//   C. CWC Bihar bulletin  — cwc.gov.in/fld_mng/bihar_flood_bulletin.json
//   D. APDM / India-WRIS   — indiawris.gov.in news feed
//   E. PIB flood press-note RSS — pib.gov.in feed
//
// NewsItem.severity is derived from keyword scanning so cards can be
// colour-coded without a separate classification step.

library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

enum NewsSeverity { critical, high, moderate, info }

class NewsItem {
  final String  title;
  final String  summary;
  final String  url;
  final String  source;       // 'IMD', 'NDMA', 'CWC', 'WRIS', 'PIB'
  final DateTime publishedAt;
  final NewsSeverity severity;

  const NewsItem({
    required this.title,
    required this.summary,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.severity,
  });

  // Stable dedup key
  String get id => '$source|${title.toLowerCase().trim()}';
}

class NewsService {
  static const _timeout = Duration(seconds: 12);

  // ── public entry point ────────────────────────────────────────────────
  Future<List<NewsItem>> fetchAll() async {
    final results = await Future.wait([
      _tryImd(),
      _tryNdma(),
      _tryCwcBulletin(),
      _tryWris(),
      _tryPib(),
    ], eagerError: false);

    final merged = <String, NewsItem>{};
    for (final list in results) {
      for (final item in list) {
        merged.putIfAbsent(item.id, () => item);
      }
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        // Primary: severity desc, Secondary: date desc
        final sc = b.severity.index.compareTo(a.severity.index);
        if (sc != 0) return sc;
        return b.publishedAt.compareTo(a.publishedAt);
      });
    return sorted;
  }

  // ── Source A: IMD FFS RSS ─────────────────────────────────────────────
  Future<List<NewsItem>> _tryImd() async {
    const url = 'https://ffs.imd.gov.in/rss/alerts.xml';
    try {
      final resp = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/rss+xml,text/xml'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return _parseRss(resp.body, 'IMD');
      }
    } catch (e) {
      debugPrint('[NewsService] IMD failed: $e');
    }
    return [];
  }

  // ── Source B: NDMA advisories JSON ───────────────────────────────────
  Future<List<NewsItem>> _tryNdma() async {
    const url = 'https://ndma.gov.in/api/v1/advisories?format=json&limit=20';
    try {
      final resp = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['results'] as List? ??
                      body['advisories'] as List? ??
                      body as List?)?.cast<Map<String, dynamic>>() ?? [];
        final now  = DateTime.now();
        return list.map((r) {
          final title   = r['title']?.toString()   ?? r['heading']?.toString() ?? 'NDMA Advisory';
          final summary = r['summary']?.toString() ?? r['description']?.toString() ?? '';
          final urlStr  = r['url']?.toString()     ?? r['link']?.toString() ?? 'https://ndma.gov.in';
          final pub     = DateTime.tryParse(r['date']?.toString() ?? r['issued_at']?.toString() ?? '') ?? now;
          return NewsItem(
            title: title, summary: summary, url: urlStr,
            source: 'NDMA', publishedAt: pub,
            severity: _severity(title + summary),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[NewsService] NDMA failed: $e');
    }
    return [];
  }

  // ── Source C: CWC Bihar Flood Bulletin JSON ───────────────────────────
  Future<List<NewsItem>> _tryCwcBulletin() async {
    const url = 'https://cwc.gov.in/fld_mng/bihar_flood_bulletin.json';
    try {
      final resp = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        // Bulletin JSON has a top-level 'bulletin' text + stations list
        final bulletin = body['bulletin']?.toString() ?? body['remarks']?.toString() ?? '';
        final date     = DateTime.tryParse(
                body['date']?.toString() ?? body['issued_at']?.toString() ?? '') ??
            DateTime.now();
        if (bulletin.isEmpty) return [];
        return [
          NewsItem(
            title:       'CWC Bihar Flood Bulletin — ${_fmtDate(date)}',
            summary:     bulletin.length > 300 ? '${bulletin.substring(0, 297)}…' : bulletin,
            url:         'https://cwc.gov.in/fld_mng',
            source:      'CWC',
            publishedAt: date,
            severity:    _severity(bulletin),
          )
        ];
      }
    } catch (e) {
      debugPrint('[NewsService] CWC bulletin failed: $e');
    }
    return [];
  }

  // ── Source D: India-WRIS News feed (HTML) ─────────────────────────────
  Future<List<NewsItem>> _tryWris() async {
    const url = 'https://indiawris.gov.in/wris/#/newsEvents';
    // WRIS doesn't expose a clean JSON/RSS — try the data endpoint instead
    const apiUrl = 'https://indiawris.gov.in/wris/api/floodNews?limit=10';
    try {
      final resp = await http
          .get(Uri.parse(apiUrl),
              headers: {'User-Agent': 'OpsFlood/4.0', 'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['data'] as List? ?? body as List?)?.cast<Map<String, dynamic>>() ?? [];
        final now  = DateTime.now();
        return list.map((r) {
          final title   = r['title']?.toString()   ?? r['heading']?.toString()  ?? 'WRIS Update';
          final summary = r['summary']?.toString() ?? r['body']?.toString()    ?? '';
          final urlStr  = r['url']?.toString()     ?? r['link']?.toString()    ?? url;
          final pub     = DateTime.tryParse(r['date']?.toString() ?? '') ?? now;
          return NewsItem(
            title: title, summary: summary, url: urlStr,
            source: 'WRIS', publishedAt: pub,
            severity: _severity(title + summary),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[NewsService] WRIS failed: $e');
    }
    return [];
  }

  // ── Source E: PIB press-release RSS (flood keyword filter) ────────────
  Future<List<NewsItem>> _tryPib() async {
    const url = 'https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3';
    try {
      final resp = await http
          .get(Uri.parse(url),
              headers: {'User-Agent': 'OpsFlood/4.0', 'Accept': 'text/xml,application/rss+xml'})
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final all = _parseRss(resp.body, 'PIB');
        // Keep only flood/rain/cyclone-related items
        return all.where((item) {
          final combined = (item.title + item.summary).toLowerCase();
          return combined.contains('flood') ||
                 combined.contains('rain')  ||
                 combined.contains('cyclone') ||
                 combined.contains('inundation') ||
                 combined.contains('disaster')   ||
                 combined.contains('relief');
        }).toList();
      }
    } catch (e) {
      debugPrint('[NewsService] PIB failed: $e');
    }
    return [];
  }

  // ── RSS parser ─────────────────────────────────────────────────────────
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
        final pubDate = node.querySelector('pubDate')?.text.trim()     ?? '';
        if (title.isEmpty) continue;
        final cleanDesc = html_parser.parse(desc).body?.text.trim() ?? desc;
        items.add(NewsItem(
          title:       title,
          summary:     cleanDesc.length > 250 ? '${cleanDesc.substring(0, 247)}…' : cleanDesc,
          url:         link,
          source:      source,
          publishedAt: _parseRssDate(pubDate),
          severity:    _severity(title + cleanDesc),
        ));
      }
    } catch (e) {
      debugPrint('[NewsService] RSS parse error ($source): $e');
    }
    return items;
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  static DateTime _parseRssDate(String s) {
    try {
      // RFC 2822: 'Wed, 11 Jun 2026 14:00:00 +0530'
      return DateTime.parse(s);
    } catch (_) {}
    try {
      // Simple fallback
      return DateTime.tryParse(s) ?? DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  static NewsSeverity _severity(String text) {
    final t = text.toLowerCase();
    if (t.contains('red alert')    || t.contains('extreme')     ||
        t.contains('catastrophic') || t.contains('danger level') ||
        t.contains('breach')       || t.contains('evacuate'))     return NewsSeverity.critical;
    if (t.contains('orange alert') || t.contains('severe')      ||
        t.contains('above danger') || t.contains('warning level') ||
        t.contains('flood warning'))                               return NewsSeverity.high;
    if (t.contains('yellow alert') || t.contains('heavy rain')  ||
        t.contains('moderate')     || t.contains('watch'))        return NewsSeverity.moderate;
    return NewsSeverity.info;
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
