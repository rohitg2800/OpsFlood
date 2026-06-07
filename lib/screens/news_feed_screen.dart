// lib/screens/news_feed_screen.dart
// Bihar Flood Command — News Feed HUD v3
// Scrapes Bihar flood news from BSDMA, NDMA, IMD, and news providers.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/news_feed_provider.dart';
import '../theme/river_theme.dart';

const _biharKeywords = [
  'bihar','patna','muzaffarpur','darbhanga','bhagalpur','kosi','gandak',
  'ganga','bagmati','ghaghara','flood','flood warning','bsdma','ndma',
  'champaran','sitamarhi','supaul','saran','vaishali','madhubani',
];

class NewsFeedScreen extends ConsumerStatefulWidget {
  static const route = '/news-feed';
  const NewsFeedScreen({super.key});
  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Timer _clock;
  String _timeStr = '';
  String _tag = 'ALL';
  final _tags = ['ALL', 'FLOOD', 'RAIN', 'ALERT', 'RESCUE', 'RELIEF'];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _timeStr = DateFormat('HH:mm:ss').format(DateTime.now()));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(newsFeedProvider);
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildTagBar()),
        ],
        body: newsAsync.when(
          data: (items) {
            // Filter to Bihar-relevant items
            final biharItems = items.where((item) {
              final text = [
                (item['title'] ?? '').toString(),
                (item['description'] ?? '').toString(),
                (item['source'] ?? '').toString(),
              ].join(' ').toLowerCase();
              return _biharKeywords.any((k) => text.contains(k));
            }).toList();

            // Tag filter
            final filtered = _tag == 'ALL'
                ? biharItems
                : biharItems.where((item) {
                    final text = [
                      (item['title'] ?? '').toString(),
                      (item['description'] ?? '').toString(),
                    ].join(' ').toLowerCase();
                    return text.contains(_tag.toLowerCase());
                  }).toList();

            if (filtered.isEmpty) {
              return _NoSignal(label: 'NO FEED · BIHAR UPDATES AWAITED');
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _NewsCard(item: filtered[i]),
            );
          },
          loading: () => Center(
              child: CircularProgressIndicator(
                  color: AppPalette.cyan, strokeWidth: 1.5)),
          error: (e, _) => _NoSignal(label: 'FEED ERROR · NDMA/IMD OFFLINE'),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
    decoration: BoxDecoration(
      color: AppPalette.abyss0,
      border: Border(bottom:
          BorderSide(color: AppPalette.cyan.withValues(alpha: 0.15))),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.30)),
              color: AppPalette.abyss2,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppPalette.cyan, size: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INTEL FEED · BIHAR',
                  style: TextStyle(
                    color: AppPalette.cyan, fontSize: 13,
                    fontWeight: FontWeight.w800, letterSpacing: 2,
                  )),
              Text('SYS $_timeStr · NDMA / IMD / BSDMA',
                  style: const TextStyle(
                    color: AppPalette.textDim, fontSize: 9,
                    letterSpacing: 1,
                  )),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.cyan.withValues(alpha: 0.06 + 0.06 * _pulse.value),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.cyan.withValues(alpha: 0.5 + 0.5 * _pulse.value),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('LIVE',
                    style: TextStyle(
                      color: AppPalette.cyan, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    )),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildTagBar() => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      children: _tags.map((t) {
        final active = _tag == t;
        return GestureDetector(
          onTap: () => setState(() => _tag = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                  ? AppPalette.cyan.withValues(alpha: 0.14)
                  : AppPalette.abyss2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: active ? AppPalette.cyan : AppPalette.abyssStroke),
            ),
            child: Center(
              child: Text(t,
                  style: TextStyle(
                    color: active ? AppPalette.cyan : AppPalette.textDim,
                    fontSize: 9, fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

// ─── News Card ────────────────────────────────────────────────────────────────
class _NewsCard extends StatelessWidget {
  final dynamic item;
  const _NewsCard({required this.item});

  String _f(String k, [String fb = '']) {
    try {
      final v = (item as dynamic)[k];
      return v?.toString().isNotEmpty == true ? v.toString() : fb;
    } catch (_) { return fb; }
  }

  @override
  Widget build(BuildContext context) {
    final title   = _f('title', 'No title');
    final desc    = _f('description', _f('summary', ''));
    final source  = _f('source', _f('publisher', ''));
    final rawDate = _f('published_at', _f('date', ''));
    final url     = _f('url', _f('link', ''));
    final category= _f('category', 'FLOOD').toUpperCase();

    String dateStr = '';
    if (rawDate.isNotEmpty) {
      final dt = DateTime.tryParse(rawDate);
      dateStr = dt != null
          ? DateFormat('dd MMM, HH:mm').format(dt.toLocal())
          : rawDate;
    }

    final isBiharKw = _biharKeywords.any(
        (k) => title.toLowerCase().contains(k) ||
            desc.toLowerCase().contains(k));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBiharKw
              ? AppPalette.cyan.withValues(alpha: 0.20)
              : AppPalette.abyssStroke,
        ),
      ),
      child: Column(
        children: [
          if (isBiharKw)
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                gradient: LinearGradient(colors: [
                  AppPalette.cyan.withValues(alpha: 0.7),
                  AppPalette.cyan.withValues(alpha: 0),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppPalette.cyan.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: AppPalette.cyan.withValues(alpha: 0.22)),
                      ),
                      child: Text(category,
                          style: const TextStyle(
                            color: AppPalette.cyan, fontSize: 7.5,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8,
                          )),
                    ),
                    if (isBiharKw) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppPalette.safe.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: AppPalette.safe.withValues(alpha: 0.22)),
                        ),
                        child: const Text('BIHAR',
                            style: TextStyle(
                              color: AppPalette.safe, fontSize: 7.5,
                              fontWeight: FontWeight.w800, letterSpacing: 0.8,
                            )),
                      ),
                    ],
                    const Spacer(),
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: const TextStyle(
                            color: AppPalette.textDim, fontSize: 8.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontSize: 12.5, fontWeight: FontWeight.w700,
                      height: 1.4,
                    )),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textGrey,
                        fontSize: 10.5, height: 1.5,
                      )),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (source.isNotEmpty) ...[
                      const Icon(Icons.language_rounded,
                          color: AppPalette.textDim, size: 10),
                      const SizedBox(width: 3),
                      Text(source,
                          style: const TextStyle(
                            color: AppPalette.textDim, fontSize: 9,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                    const Spacer(),
                    if (url.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppPalette.cyan.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppPalette.cyan.withValues(alpha: 0.25)),
                          ),
                          child: const Text('READ →',
                              style: TextStyle(
                                color: AppPalette.cyan, fontSize: 8.5,
                                fontWeight: FontWeight.w800, letterSpacing: 0.8,
                              )),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSignal extends StatelessWidget {
  final String label;
  const _NoSignal({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.cyan.withValues(alpha: 0.08),
            border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.rss_feed_rounded, color: AppPalette.cyan, size: 28),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.5,
            )),
      ],
    ),
  );
}
