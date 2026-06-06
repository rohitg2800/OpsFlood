import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';
import 'premium_theme_sheet.dart';

/// AppBar icon that long-press → full premium sheet, tap → quick cycle.
class ThemeCycleButton extends ConsumerWidget {
  const ThemeCycleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appMode  = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final rc       = RiverColors.of(context);

    final IconData icon;
    switch (appMode) {
      case AppThemeMode.system:  icon = Icons.brightness_auto;  break;
      case AppThemeMode.light:   icon = Icons.wb_sunny;         break;
      case AppThemeMode.dark:    icon = Icons.nights_stay;      break;
      case AppThemeMode.sunset:  icon = Icons.wb_twilight;      break;
      case AppThemeMode.ocean:   icon = Icons.water;            break;
    }

    return Tooltip(
      message: 'Hold for theme picker',
      child: GestureDetector(
        onTap:       () => notifier.cycle(),
        // Fixed: showPremiumThemeSheet() free function doesn't exist;
        // PremiumThemeSheet.show() is the static method.
        onLongPress: () => PremiumThemeSheet.show(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(icon, color: rc.accent, size: 24),
        ),
      ),
    );
  }
}
