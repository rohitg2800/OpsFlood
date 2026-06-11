// lib/screens/news_feed_screen.dart  v2.0
// Live flood-news feed — auto-refreshes every 60 s from 5 sources:
//   IMD FFS · NDMA · CWC Bulletin · India-WRIS · PIB
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/news_provider.dart';
import '../services/news_service.dart';
import '../theme/river_theme.dart';

class NewsFeedScreen extends ConsumerWidget {
  static const String route = '/news-feed';
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync     = ref.watch(liveNewsProvider);
    final countdownAsync = ref.watch(newsCountdownProvider);
    final countdown     = countdownAsync.valueOrNull ?? 60;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: const Text(
          'LIVE FLOOD NEWS',
          style: TextStyle(
            color: AppPalette.cyan,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.8,
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.gold),
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.cyan),
            tooltip: 'Refresh now',
            onPressed: () => ref.invalidate(liveNewsProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: _RefreshBar(countdown: countdown),
        ),
      ),
      body: newsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(liveNewsProvider),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyView()
            : _NewsList(items: items),
      ),
    );
  }
}

// ── Refresh progress bar ──────────────────────────────────────────────────────
class _RefreshBar extends StatelessWidget {
  final int countdown;
  const _RefreshBar({required this.countdown});

  @override
  Widget build(BuildContext context) {
    final progress = countdown / 60.0;
    return Container(
      height: 28,
      color: AppPalette.abyss1,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.circle, color: AppPalette.safe, size: 7),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppPalette.abyss2,
                valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.cyan),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Next in ${countdown}s',
            style: const TextStyle(
              color: AppPalette.textGrey,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── News list ─────────────────────────────────────────────────────────────────
class _NewsList extends StatelessWidget {
  final List<NewsItem> items;
  const _NewsList({required this.items});

  @override
  Widget build(BuildContext context) {
    // Group by source
    final grouped = <String, List<NewsItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.source, () => []).add(item);
    }
    const sourceOrder = ['IMD', 'NDMA', 'CWC', 'WRIS', 'PIB'];
    final orderedSources = [
      ...sourceOrder.where(grouped.containsKey),
      ...grouped.keys.where((k) => !sourceOrder.contains(k)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: orderedSources.length,
      itemBuilder: (context, i) {
        final src       = orderedSources[i];
        final srcItems  = grouped[src]!;
        return _SourceSection(source: src, items: srcItems);
      },
    );
  }
}

// ── Per-source section ────────────────────────────────────────────────────────
class _SourceSection extends StatelessWidget {
  final String source;
  final List<NewsItem> items;
  const _SourceSection({required this.source, required this.items});

  Color get _headerColor {
    switch (source) {
      case 'IMD':  return AppPalette.cyan;
      case 'NDMA': return AppPalette.warning;
      case 'CWC':  return AppPalette.safe;
      case 'WRIS': return AppPalette.gold;
      case 'PIB':  return const Color(0xFFB39DDB);
      default:     return AppPalette.textGrey;
    }
  }

  String get _headerLabel {
    switch (source) {
      case 'IMD':  return 'IMD — Flood Forecasting Service';
      case 'NDMA': return 'NDMA — National Disaster Mgmt Authority';
      case 'CWC':  return 'CWC — Central Water Commission';
      case 'WRIS': return 'India-WRIS — Water Resources Info System';
      case 'PIB':  return 'PIB — Press Information Bureau';
      default:     return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _headerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  source,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headerLabel,
                  style: const TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppPalette.textGrey, fontSize: 10),
              ),
            ],
          ),
        ),
        ...items.map((item) => _NewsCard(item: item)),
      ],
    );
  }
}

// ── Single news card ──────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  Color get _severityColor {
    switch (item.severity) {
      case NewsSeverity.critical: return const Color(0xFFD32F2F);
      case NewsSeverity.high:     return const Color(0xFFF57C00);
      case NewsSeverity.moderate: return const Color(0xFFFBC02D);
      case NewsSeverity.info:     return AppPalette.textGrey;
    }
  }

  String get _severityLabel {
    switch (item.severity) {
      case NewsSeverity.critical: return 'CRITICAL';
      case NewsSeverity.high:     return 'HIGH';
      case NewsSeverity.moderate: return 'MODERATE';
      case NewsSeverity.info:     return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor;
    final timeStr = _relativeTime(item.publishedAt);

    return GestureDetector(
      onTap: () async {
        if (item.url.isNotEmpty) {
          final uri = Uri.tryParse(item.url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: severity badge + time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _severityLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: const TextStyle(color: AppPalette.textGrey, fontSize: 10),
                ),
                if (item.url.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded,
                       color: AppPalette.textGrey.withValues(alpha: 0.6), size: 12),
                ],
              ],
            ),
            const SizedBox(height: 7),
            // Title
            Text(
              item.title,
              style: const TextStyle(
                color: AppPalette.textWhite,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            // Summary
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── States ────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppPalette.cyan, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Fetching live news…',
              style: TextStyle(color: AppPalette.textGrey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No news items retrieved.\nPull to refresh or wait for next auto-refresh.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textGrey, fontSize: 13),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppPalette.warning, size: 40),
            const SizedBox(height: 12),
            const Text('Could not fetch news',
                style: TextStyle(
                    color: AppPalette.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.textGrey, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.cyan.withValues(alpha: 0.15)),
              icon: const Icon(Icons.refresh_rounded, color: AppPalette.cyan, size: 16),
              label: const Text('Retry',
                  style: TextStyle(color: AppPalette.cyan, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
