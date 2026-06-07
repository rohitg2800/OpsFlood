// lib/screens/news_feed_screen.dart
// OpsFlood — NDMA + IMD + WRD Bihar Alert Feed
// Wired to CwcAlertWatcher.showNewsNotification() for push on new articles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/news_feed_provider.dart';
import '../services/cwc_alert_watcher.dart';
import '../theme/river_theme.dart';

class NewsFeedScreen extends ConsumerStatefulWidget {
  const NewsFeedScreen({super.key});
  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen> {
  // Tracks titles we've already notified to avoid duplicates
  final Set<String> _notified = {};

  @override
  void initState() {
    super.initState();
    // Fire once for any articles already loaded when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(newsFeedProvider);
      _notifyNew(state.items);
    });
  }

  void _notifyNew(List<NewsItem> items) {
    for (final item in items) {
      if (_notified.contains(item.title)) continue;
      _notified.add(item.title);
      // Only notify for non-normal severity
      if (item.severity.toUpperCase() == 'GREEN') continue;
      CwcAlertWatcher.instance.showNewsNotification(
        headline: item.title,
        source: item.source,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen fires whenever the provider state changes (e.g. after refresh)
    ref.listen<NewsFeedState>(newsFeedProvider, (prev, next) {
      if (!next.isLoading && next.error == null) {
        _notifyNew(next.items);
      }
    });

    final state = ref.watch(newsFeedProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                onRefresh: () {
                  HapticFeedback.mediumImpact();
                  ref.read(newsFeedProvider.notifier).refresh();
                },
              ),
              if (state.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppPalette.cyan),
                  ),
                )
              else if (state.error != null && state.items.isEmpty)
                Expanded(child: _ErrorState(message: state.error!))
              else
                Expanded(
                  child: RefreshIndicator(
                    color: AppPalette.cyan,
                    onRefresh: () =>
                        ref.read(newsFeedProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) =>
                          _NewsCard(item: state.items[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: AppPalette.abyss0,
          border: Border(
            bottom: BorderSide(
                color: AppPalette.cyan.withValues(alpha: 0.10), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppPalette.cyan.withValues(alpha: 0.10),
                border: Border.all(
                    color: AppPalette.cyan.withValues(alpha: 0.28),
                    width: 1.5),
              ),
              child: const Icon(Icons.feed_rounded,
                  color: AppPalette.cyan, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                    ).createShader(b),
                    child: const Text('ALERTS & NEWS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        )),
                  ),
                  Text('NDMA · IMD · Bihar WRD Bulletins',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppPalette.textGrey.withValues(alpha: 0.65),
                      )),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.abyssStroke),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: AppPalette.textGrey, size: 18),
              ),
            ),
          ],
        ),
      );
}

// ── Card ──────────────────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final col = _sourceColor(item.source);
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(item.url);
        if (uri != null && uri.hasScheme) {
          if (await canLaunchUrl(uri)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SourceBadge(source: item.source, color: col),
                const SizedBox(width: 8),
                _SeverityBadge(severity: item.severity),
                const Spacer(),
                Text(
                  item.publishedAt,
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(
                color: AppPalette.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (item.summary != null) ...[
              const SizedBox(height: 6),
              Text(
                item.summary!,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 11,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.url.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Read more',
                      style: TextStyle(
                        color: col,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(width: 3),
                  Icon(Icons.open_in_new_rounded, color: col, size: 10),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _sourceColor(String src) {
    final s = src.toUpperCase();
    if (s.contains('NDMA') || s.contains('BSDMA')) return AppPalette.critical;
    if (s.contains('IMD'))                         return AppPalette.amber;
    if (s.contains('CWC'))                         return const Color(0xFF4CAF50);
    if (s.contains('WRD'))                         return AppPalette.cyan;
    return AppPalette.textGrey;
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String source;
  final Color  color;
  const _SourceBadge({required this.source, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          source.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});
  @override
  Widget build(BuildContext context) {
    final col = severity.toUpperCase() == 'RED'
        ? AppPalette.critical
        : severity.toUpperCase() == 'ORANGE'
            ? AppPalette.danger
            : AppPalette.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${severity.toUpperCase()} ALERT',
        style: TextStyle(
          color: col,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppPalette.textDim, size: 48),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
