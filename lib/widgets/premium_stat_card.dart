import 'dart:ui';

import 'package:flutter/material.dart';

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
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color:       accent.withValues(alpha: 0.18),
                  blurRadius:  18,
                  spreadRadius: 1,
                ),
              ],
            ),
            // FIX: wrap in ClipRect so content never bleeds outside the card,
            // and use Flexible text widgets so they shrink to fit.
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize:   17,   // was 20 — reduced to fit compact cards
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),  // was 12
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 9.5),  // was 10
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
