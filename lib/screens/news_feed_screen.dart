// lib/screens/news_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/context_l10n.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class NewsFeedScreen extends ConsumerWidget {
  static const String route = '/news-feed';
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(realTimeProvider);
    final t = RiverColors.of(context);
    final s = context.l10n;

    final alerts     = service.imdAlerts;
    final advisories = service.ndmaAdvisories;

    Future<void> onRefresh() async {
      await service.refreshData();
    }

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: Text(
          s.newsFeedTitle,
          style: const TextStyle(
            color: AppPalette.cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.gold),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppPalette.cyan,
        backgroundColor: AppPalette.abyss2,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(label: s.imdAlertsTitle, color: AppPalette.cyan),
            if (alerts.isEmpty)
              _EmptyCard(message: s.noActiveImdAlerts, color: AppPalette.cyan)
            else
              ...alerts.map((a) => _AlertCard(item: a, color: AppPalette.warning, t: t)),
            const SizedBox(height: 20),
            _SectionHeader(label: s.ndmaAdvisoriesTitle, color: AppPalette.gold),
            if (advisories.isEmpty)
              _EmptyCard(message: s.noActiveNdmaAdvisories, color: AppPalette.gold)
            else
              ...advisories.map((a) => _AlertCard(item: a, color: AppPalette.gold, t: t)),
            const SizedBox(height: 20),
            _SectionHeader(label: s.officialSources, color: AppPalette.textGrey),
            _LinkCard(
              title: s.imdFloodForecasting,
              url: 'https://ffs.imd.gov.in',
              color: AppPalette.cyan,
              t: t,
            ),
            _LinkCard(
              title: s.ndmaAdvisoriesLink,
              url: 'https://ndma.gov.in',
              color: AppPalette.gold,
              t: t,
            ),
            _LinkCard(
              title: s.cwcFloodBulletin,
              url: 'https://cwc.gov.in',
              color: AppPalette.safe,
              t: t,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final Color color;
  const _EmptyCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppPalette.textGrey, fontSize: 13),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final dynamic item;
  final Color color;
  final RiverColors t;
  const _AlertCard({required this.item, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    final title   = item is Map ? item['title']   ?? item['heading']     ?? 'Alert' : item.toString();
    final desc    = item is Map ? item['summary']  ?? item['description'] ?? ''      : '';
    final dateStr = item is Map ? item['date']     ?? item['issued_at']  ?? ''      : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toString(),
            style: const TextStyle(
              color: AppPalette.textWhite,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (desc.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc.toString(),
                style: const TextStyle(color: AppPalette.textGrey, fontSize: 12)),
          ],
          if (dateStr.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dateStr.toString(),
                style: const TextStyle(color: AppPalette.textGrey, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String title, url;
  final Color color;
  final RiverColors t;
  const _LinkCard({
    required this.title,
    required this.url,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new_rounded, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              url,
              style: const TextStyle(color: AppPalette.textGrey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
