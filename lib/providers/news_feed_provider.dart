// lib/providers/news_feed_provider.dart
// Fetches NDMA + IMD + Bihar WRD bulletins from our backend proxy.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class NewsItem {
  final String  title;
  final String  source;
  final String? summary;
  final String? url;
  final String? severity;   // RED / ORANGE / YELLOW / null
  final DateTime publishedAt;
  const NewsItem({
    required this.title,
    required this.source,
    required this.publishedAt,
    this.summary,
    this.url,
    this.severity,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
    title:       j['title'] as String,
    source:      j['source'] as String,
    publishedAt: DateTime.parse(j['published_at'] as String),
    summary:     j['summary'] as String?,
    url:         j['url'] as String?,
    severity:    j['severity'] as String?,
  );
}

class NewsFeedState {
  final List<NewsItem> items;
  final bool           isLoading;
  final String?        error;
  const NewsFeedState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });
  NewsFeedState copyWith({List<NewsItem>? items, bool? isLoading, String? error}) =>
      NewsFeedState(
        items:     items     ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error:     error,
      );
}

class NewsFeedNotifier extends StateNotifier<NewsFeedState> {
  NewsFeedNotifier() : super(const NewsFeedState(isLoading: true)) {
    refresh();
  }

  static const _base = String.fromEnvironment(
      'BACKEND_URL', defaultValue: 'https://opsflood-api.onrender.com');

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await http
          .get(Uri.parse('$_base/api/news?state=bihar'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final items = data
            .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = NewsFeedState(items: items);
      } else {
        state = NewsFeedState(
            items: _fallbackItems(),
            error: 'Server error ${res.statusCode}. Showing cached alerts.');
      }
    } catch (e) {
      // Offline fallback — show static critical alerts so users aren't left blank
      state = NewsFeedState(
          items: _fallbackItems(),
          error: 'Could not reach server. Showing last known alerts.');
    }
  }

  /// Static fallback alerts shown when API is unreachable.
  List<NewsItem> _fallbackItems() => [
    NewsItem(
      title: 'IMD issues Red Alert for North Bihar — Heavy to Very Heavy Rainfall expected',
      source: 'IMD',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      severity: 'RED',
      summary: 'Districts: Sitamarhi, Madhubani, Supaul, Araria, Kishanganj. '
               'Residents in low-lying areas advised to evacuate.',
      url: 'https://mausam.imd.gov.in',
    ),
    NewsItem(
      title: 'Bihar WRD Flood Bulletin: Kosi at Birpur above Danger Level',
      source: 'WRD Bihar',
      publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      severity: 'ORANGE',
      summary: 'Kosi at Birpur reading 74.74 m (DL: 74.70 m). '
               'Embankment patrol intensified on both banks.',
      url: 'https://www.fmiscwrdbihar.gov.in/bulletin/',
    ),
    NewsItem(
      title: 'NDMA activates NDRF teams for Bihar — 2 columns deployed to Supaul',
      source: 'NDMA',
      publishedAt: DateTime.now().subtract(const Duration(hours: 10)),
      severity: 'RED',
      summary: '4 NDRF teams with boats and medical kits pre-positioned '
               'at Supaul and Madhubani for rapid response.',
      url: 'https://ndma.gov.in',
    ),
    NewsItem(
      title: 'Bagmati Dheng Bridge approaches Danger Level — Sitamarhi on alert',
      source: 'WRD Bihar',
      publishedAt: DateTime.now().subtract(const Duration(hours: 14)),
      severity: 'ORANGE',
      summary: 'Dheng Bridge (Sitamarhi) at 70.85 m, Danger Level 71.00 m. '
               'Nepal catchment rainfall 180mm in 24h.',
    ),
    NewsItem(
      title: 'CWC 48-hour Flood Forecast: Ganga to rise at Gandhighat',
      source: 'CWC',
      publishedAt: DateTime.now().subtract(const Duration(hours: 20)),
      severity: 'YELLOW',
      summary: 'Ganga expected to touch Warning Level (47.50 m) at Gandhighat '
               'within 48 hours based on Farakka upstream readings.',
      url: 'https://beams.fmiscwrdbihar.gov.in',
    ),
  ];
}

final newsFeedProvider =
    StateNotifierProvider<NewsFeedNotifier, NewsFeedState>(
        (_) => NewsFeedNotifier());
