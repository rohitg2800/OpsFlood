// lib/screens/india_river_explorer_screen.dart
library;

import 'package:flutter/material.dart';
import '../l10n/context_l10n.dart';
import '../theme/river_theme.dart';

class IndiaRiverExplorerScreen extends StatelessWidget {
  static const String route = '/india_river_explorer';
  const IndiaRiverExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final s = context.l10n;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.scaffoldBg,
        title: Text(
          s.rivers,
          style: TextStyle(
            color: t.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: 0.10),
                  border: Border.all(color: t.accent.withValues(alpha: 0.28)),
                ),
                child: Icon(Icons.map_rounded, size: 42, color: t.accent),
              ),
              const SizedBox(height: 18),
              Text(
                s.rivers,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.comingSoon,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
