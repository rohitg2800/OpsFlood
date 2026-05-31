// lib/screens/settings_screen.dart
// OpsFlood — SettingsScreen v1
// Sections: Appearance (language + theme filter) · About
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';
import '../widgets/premium_theme_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc      = RiverColors.of(context);
    final appMode = ref.watch(themeModeProvider);
    final locale  = ref.watch(localeProvider);
    final themeNotifier  = ref.read(themeModeProvider.notifier);
    final localeNotifier = ref.read(localeProvider.notifier);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.cyan.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppPalette.cyan.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: AppPalette.cyan, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color:      AppPalette.textWhite,
                            fontSize:   20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Appearance & App Preferences',
                          style: TextStyle(
                            color:    AppPalette.textGrey.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Appearance section
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Appearance',
                icon:  Icons.palette_outlined,
                children: [
                  // ── Language picker
                  _SettingRow(
                    icon:    Icons.language_rounded,
                    label:   'Language',
                    sublabel: kLocaleLabels[locale.languageCode] ?? locale.languageCode,
                    onTap:   () => _showLanguagePicker(context, locale, localeNotifier),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kLocaleLabels[locale.languageCode] ?? locale.languageCode,
                          style: TextStyle(
                            color:      rc.accent,
                            fontWeight: FontWeight.w700,
                            fontSize:   13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: rc.textSecondary, size: 18),
                      ],
                    ),
                  ),

                  _Divider(),

                  // ── Theme filter picker
                  _SettingRow(
                    icon:    _modeIcon(appMode),
                    label:   'Theme',
                    sublabel: _modeLabel(appMode),
                    onTap:   () => showPremiumThemeSheet(context),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isPremium(appMode))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppPalette.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppPalette.amber.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color:      AppPalette.amber,
                                fontSize:   8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        Text(
                          _modeLabel(appMode),
                          style: TextStyle(
                            color:      rc.accent,
                            fontWeight: FontWeight.w700,
                            fontSize:   13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: rc.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── About section
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'About',
                icon:  Icons.info_outline_rounded,
                children: [
                  _SettingRow(
                    icon:    Icons.water_drop_rounded,
                    label:   'OpsFlood  ·  EQUINOX-BH',
                    sublabel: 'Flood Intelligence Platform',
                    onTap:   null,
                    trailing: Text(
                      'v1.0',
                      style: TextStyle(
                        color:    rc.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _Divider(),
                  _SettingRow(
                    icon:    Icons.source_rounded,
                    label:   'Data Sources',
                    sublabel: 'CWC · IMD · WRIS · GloFAS · Open-Meteo',
                    onTap:   null,
                    trailing: const SizedBox.shrink(),
                  ),
                  _Divider(),
                  _SettingRow(
                    icon:    Icons.location_on_rounded,
                    label:   'Coverage',
                    sublabel: 'Bihar — 32 monitored cities',
                    onTap:   null,
                    trailing: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Language picker bottom sheet
  void _showLanguagePicker(
    BuildContext context,
    Locale current,
    LocaleNotifier notifier,
  ) {
    final rc = RiverColors.of(context);
    showModalBottomSheet(
      context:             context,
      backgroundColor:     Colors.transparent,
      isScrollControlled:  true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color:        AppPalette.abyss3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppPalette.abyssStroke),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        AppPalette.abyssStroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.language_rounded,
                        color: AppPalette.cyan, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Language',
                      style: TextStyle(
                        color:      AppPalette.textWhite,
                        fontSize:   16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...kSupportedLocales.map((l) {
                  final isActive = l.languageCode == current.languageCode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color:        Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          notifier.setLocale(l);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppPalette.cyan.withValues(alpha: 0.12)
                                : AppPalette.abyss2,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? AppPalette.cyan.withValues(alpha: 0.40)
                                  : AppPalette.abyssStroke,
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                kLocaleLabels[l.languageCode] ?? l.languageCode,
                                style: TextStyle(
                                  color: isActive
                                      ? AppPalette.cyan
                                      : AppPalette.textWhite,
                                  fontWeight: FontWeight.w700,
                                  fontSize:   15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l.languageCode.toUpperCase(),
                                style: TextStyle(
                                  color:    AppPalette.textGrey.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              if (isActive)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppPalette.cyan, size: 22)
                              else
                                Icon(Icons.circle_outlined,
                                    color: AppPalette.abyssStroke, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _modeIcon(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.system:  return Icons.brightness_auto_rounded;
      case AppThemeMode.light:   return Icons.wb_sunny_rounded;
      case AppThemeMode.dark:    return Icons.nights_stay_rounded;
      case AppThemeMode.sunset:  return Icons.wb_twilight_rounded;
      case AppThemeMode.ocean:   return Icons.water_rounded;
    }
  }

  String _modeLabel(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.system:  return 'Auto';
      case AppThemeMode.light:   return 'Day River';
      case AppThemeMode.dark:    return 'Night River';
      case AppThemeMode.sunset:  return 'Sunset Warm';
      case AppThemeMode.ocean:   return 'Deep Ocean';
    }
  }

  bool _isPremium(AppThemeMode m) =>
      m == AppThemeMode.sunset || m == AppThemeMode.ocean;
}

// ── Section card ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title, required this.icon, required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(icon, color: AppPalette.cyan, size: 14),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color:         AppPalette.textGrey.withValues(alpha: 0.7),
                    fontSize:      10,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color:        AppPalette.abyss2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.abyssStroke),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ── Individual setting row ────────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final String     sublabel;
  final VoidCallback? onTap;
  final Widget     trailing;
  const _SettingRow({
    required this.icon, required this.label,
    required this.sublabel, required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        AppPalette.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppPalette.cyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color:      AppPalette.textWhite,
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sublabel.isNotEmpty)
                      Text(
                        sublabel,
                        style: TextStyle(
                          color:    AppPalette.textGrey.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: AppPalette.abyssStroke,
      );
}
