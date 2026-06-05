// ─────────────────────────────────────────────────────────────────────────────
//  ThemePickerSheet  —  Full-featured bottom sheet for all 5 AppThemeModes
//  Replaces basic theme toggle with a visual picker.
//
//  Usage:
//    ThemePickerSheet.show(context);
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';

class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ProviderScope(
        child: ThemePickerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final rc = RiverColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppPalette.abyssStroke, width: 1),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppPalette.abyssStroke,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.palette_outlined, color: AppPalette.gold, size: 20),
              const SizedBox(width: 10),
              Text(
                'App Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: rc.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how the app looks. System auto follows your device setting.',
            style: TextStyle(fontSize: 12, color: rc.textSecondary),
          ),
          const SizedBox(height: 20),
          // Theme option tiles
          ...AppThemeMode.values.map(
            (mode) => _ThemeTile(
              mode: mode,
              isSelected: current == mode,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(themeModeProvider.notifier).setMode(mode);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  static const _meta = {
    AppThemeMode.system: (
      icon: Icons.brightness_auto_rounded,
      title: 'Auto (System)',
      subtitle: 'Follows your device dark/light setting',
      preview: [Color(0xFF1A1000), Color(0xFFFFF8E7)],
    ),
    AppThemeMode.dark: (
      icon: Icons.nights_stay_rounded,
      title: 'Night River',
      subtitle: 'Deep golden dark theme — easy on the eyes',
      preview: [Color(0xFF0F0A00), Color(0xFF251800)],
    ),
    AppThemeMode.light: (
      icon: Icons.wb_sunny_rounded,
      title: 'Day River',
      subtitle: 'Bright warm-gold theme for daylight use',
      preview: [Color(0xFFFFF8E7), Color(0xFFFFE999)],
    ),
    AppThemeMode.sunset: (
      icon: Icons.wb_twilight_rounded,
      title: 'Sunset Warm',
      subtitle: 'Warm amber tones at golden hour',
      preview: [Color(0xFF3D1A00), Color(0xFFFF6B35)],
    ),
    AppThemeMode.ocean: (
      icon: Icons.water_rounded,
      title: 'Deep Ocean',
      subtitle: 'Cool deep-blue flood monitoring palette',
      preview: [Color(0xFF001A2E), Color(0xFF00C6FF)],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _meta[mode]!;
    final c = isSelected ? AppPalette.gold : AppPalette.abyssStroke;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.gold.withValues(alpha: 0.08)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            // Colour preview swatch
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: meta.preview,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(meta.icon, size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppPalette.gold
                          : AppPalette.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppPalette.gold,
                      size: 20,
                      key: ValueKey('check'),
                    )
                  : const SizedBox(width: 20, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}
