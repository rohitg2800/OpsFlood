// lib/providers/news_feed_provider.dart
// Riverpod 3.x compatible — uses Notifier + NotifierProvider
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ── State model ──────────────────────────────────────────────────────────────
class NewsItem {
  final String title;
  final String source;
  final String severity;   // RED | ORANGE | YELLOW | INFO
  final String url;
  final String publishedAt;

  const NewsItem({
    required this.title,
    required this.source,
    required this.severity,
    required this.url,
    required this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        title:       j['title']       as String? ?? '',
        source:      j['source']      as String? ?? 'Unknown',
        severity:    j['severity']    as String? ?? 'INFO',
        url:         j['url']         as String? ?? '',
        publishedAt: j['published_at'] as String? ?? '',
      );
}

class NewsFeedState {
  final List<NewsItem> items;
  final bool isLoading;
  final String? error;

  const NewsFeedState({
    this.items    = const [],
    this.isLoading = false,
    this.error,
  });

  NewsFeedState copyWith({
    List<NewsItem>? items,
    bool? isLoading,
    String? error,
  }) => NewsFeedState(
        items:     items     ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error:     error,
      );
}

// ── Notifier (Riverpod 3.x) ──────────────────────────────────────────────────
class NewsFeedNotifier extends Notifier<NewsFeedState> {
  static const _backendBase = 'https://opsflood-backend.onrender.com';

  @override
  NewsFeedState build() {
    // Auto-fetch on first build
    Future.microtask(fetch);
    return const NewsFeedState(isLoading: true);
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await http
          .get(Uri.parse('$_backendBase/api/news?state=bihar'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(res.body) as List<dynamic>;
        final items = raw
            .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = NewsFeedState(items: items);
      } else {
        state = NewsFeedState(
          items: _offlineFallback(),
          error: 'Backend returned ${res.statusCode}',
        );
      }
    } catch (e) {
      state = NewsFeedState(
        items: _offlineFallback(),
        error: e.toString(),
      );
    }
  }

  List<NewsItem> _offlineFallback() => const [
    NewsItem(
      title: 'IMD: Heavy to very heavy rainfall likely over North Bihar in next 48h',
      source: 'IMD', severity: 'ORANGE',
      url: 'https://mausam.imd.gov.in',
      publishedAt: 'Latest bulletin',
    ),
    NewsItem(
      title: 'CWC: Kosi at Birpur above danger level — embankment patrolling activated',
      source: 'CWC', severity: 'RED',
      url: 'https://cwc.gov.in',
      publishedAt: 'Latest bulletin',
    ),
    NewsItem(
      title: 'NDMA: Pre-positioning of NDRF teams in Supaul, Madhubani, Darbhanga',
      source: 'NDMA', severity: 'ORANGE',
      url: 'https://ndma.gov.in',
      publishedAt: 'Latest bulletin',
    ),
    NewsItem(
      title: 'Bihar WRD: Gandak at Dumariaghat approaching warning level',
      source: 'Bihar WRD', severity: 'YELLOW',
      url: 'https://fmiscwrdbihar.gov.in',
      publishedAt: 'Latest bulletin',
    ),
    NewsItem(
      title: 'BSDMA: 12 districts on flood alert — evacuation centres activated',
      source: 'BSDMA', severity: 'RED',
      url: 'https://bsdma.org',
      publishedAt: 'Latest bulletin',
    ),
  ];
}

// ── Provider ─────────────────────────────────────────────────────────────────
final newsFeedProvider =
    NotifierProvider<NewsFeedNotifier, NewsFeedState>(NewsFeedNotifier.new);
