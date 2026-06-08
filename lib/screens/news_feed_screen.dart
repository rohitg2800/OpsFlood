// lib/screens/news_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});
  static const route = '/news_feed';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: const Text('Flood News & Advisories',
            style: TextStyle(
                color: AppTheme.cyan, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppTheme.cyan),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            icon: Icons.info_outline,
            title: 'Live news feed coming soon',
            body:
                'This section will aggregate NDMA, IMD and state disaster '
                'management advisories in real-time.',
            color: AppTheme.cyan,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.link,
            title: 'Official sources',
            body:
                '• NDMA — ndma.gov.in\n'
                '• IMD — mausam.imd.gov.in\n'
                '• CWC — cwc.gov.in\n'
                '• Bihar SDMA — sdma.bih.nic.in',
            color: AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      {required IconData icon,
      required String title,
      required String body,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 6),
                Text(body,
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
