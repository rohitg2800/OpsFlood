// lib/widgets/premium_theme_sheet.dart
// setMode() -> set()  (ThemeModeNotifier uses set(), not setMode())
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';

class PremiumThemeSheet extends ConsumerWidget {
  const PremiumThemeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.abyss2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PremiumThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final col     = RiverColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: col.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose Theme',
            style: TextStyle(
              color: col.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to switch appearance',
            style: TextStyle(color: col.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ...AppThemeMode.values.map((mode) {
            final isSelected = mode == current;
            return GestureDetector(
              onTap: () {
                // Fixed: was setMode(), ThemeModeNotifier exposes set()
                ref.read(themeModeProvider.notifier).set(mode);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppPalette.gold.withValues(alpha: 0.12)
                      : col.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppPalette.gold : col.stroke,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(mode),
                      color: isSelected ? AppPalette.gold : col.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        mode.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppPalette.gold
                              : col.textPrimary,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: AppPalette.gold, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _iconFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system: return Icons.brightness_auto_outlined;
      case AppThemeMode.light:  return Icons.light_mode_outlined;
      case AppThemeMode.dark:   return Icons.dark_mode_outlined;
      case AppThemeMode.sunset: return Icons.wb_twilight_outlined;
      case AppThemeMode.ocean:  return Icons.water_outlined;
    }
  }
}
