// lib/providers/news_provider.dart
// StreamProvider that refreshes every 60 seconds.
// Fires an immediate fetch, then repeats on the 1-minute ticker.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/news_service.dart';

final newsServiceProvider = Provider<NewsService>((_) => NewsService());

/// Live news stream — emits a new list every 60 s.
/// UI should use AsyncValue.when() to show loading / error / data states.
final liveNewsProvider = StreamProvider<List<NewsItem>>((ref) async* {
  final svc = ref.watch(newsServiceProvider);

  // Immediate first fetch
  yield await svc.fetchAll();

  // Then refresh every 60 seconds
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 60))) {
    yield await svc.fetchAll();
  }
});

/// Seconds remaining until next refresh (counts down 60 → 0).
final newsCountdownProvider = StreamProvider<int>((ref) async* {
  var count = 60;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 1))) {
    yield count;
    count--;
    if (count < 0) count = 60;
  }
});
