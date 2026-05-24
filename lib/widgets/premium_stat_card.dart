// lib/widgets/premium_stat_card.dart
//
// OpsFlood — PremiumStatCard (redesigned)
// Glass card with glow border, large value, accent gradient line at bottom.
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   value;
  final String   subtitle;
  final Color    accent;

  const PremiumStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      color: rc.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                color: accent,
                fontSize: 26, fontWeight: FontWeight.w900,
                letterSpacing: -1,
              )),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(color: rc.textSecondary, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          // Accent gradient line at bottom
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.7), accent.withValues(alpha: 0.1)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
