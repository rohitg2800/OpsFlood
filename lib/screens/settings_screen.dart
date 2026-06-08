// lib/screens/settings_screen.dart
// OpsFlood — SettingsScreen v5  (AdMob banner placed)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/premium_theme_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  static const String route = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc      = RiverColors.of(context);
    final appMode = ref.watch(themeModeProvider);
    final locale  = ref.watch(localeProvider);

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
                        color: AppPalette.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppPalette.gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: AppPalette.gold, size: 22),
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
                  _SettingRow(
                    icon:    Icons.language_rounded,
                    label:   'Language',
                    sublabel: kLocaleLabels[locale.languageCode] ?? locale.languageCode,
                    onTap:   () => _showLanguagePicker(context, ref),
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
                              color: AppPalette.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppPalette.gold.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color:      AppPalette.gold,
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

            // ── AdMob Banner ───────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Center(child: AdBannerWidget()),
            ),

            // ── Developer section ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Developer',
                icon:  Icons.code_rounded,
                children: [
                  _DeveloperTile(),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final rc             = RiverColors.of(context);
    final localeNotifier = ref.read(localeProvider.notifier);

    showModalBottomSheet(
      context:             context,
      backgroundColor:     Colors.transparent,
      isScrollControlled:  true,
      builder: (ctx) => Consumer(
        builder: (consumerCtx, sheetRef, _) {
          final locale = sheetRef.watch(localeProvider);
          return Container(
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
                            color: AppPalette.gold, size: 20),
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
                      final isActive = l.languageCode == locale.languageCode;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color:        Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              localeNotifier.setLocale(l);
                              Navigator.pop(ctx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve:    Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppPalette.gold.withValues(alpha: 0.15)
                                    : AppPalette.abyss2,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? AppPalette.gold.withValues(alpha: 0.5)
                                      : AppPalette.abyssStroke,
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    kLocaleLabels[l.languageCode] ?? l.languageCode,
                                    style: TextStyle(
                                      color: isActive
                                          ? AppPalette.gold
                                          : AppPalette.textWhite,
                                      fontWeight: FontWeight.w700,
                                      fontSize:   15,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isActive)
                                    const Icon(Icons.check_circle,
                                        color: AppPalette.gold, size: 20)
                                  else
                                    Icon(Icons.circle_outlined,
                                        color: AppPalette.abyssStroke,
                                        size: 20),
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
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Developer tile
// ─────────────────────────────────────────────────────────────────────────────
class _DeveloperTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppPalette.gold, AppPalette.goldDark],
              ),
              boxShadow: AppPalette.glowShadow(AppPalette.gold, blur: 14),
            ),
            child: const Center(
              child: Text(
                'R',
                style: TextStyle(
                  color:      AppPalette.abyss0,
                  fontSize:   20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Rohit28',
                      style: TextStyle(
                        color:      AppPalette.textWhite,
                        fontSize:   15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppPalette.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppPalette.gold.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'DEV',
                        style: TextStyle(
                          color:         AppPalette.gold,
                          fontSize:      8,
                          fontWeight:    FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Developer  ·  OpsFlood',
                  style: TextStyle(
                    color:    AppPalette.textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.star_rounded, color: AppPalette.gold, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

bool _isPremium(AppThemeMode m) =>
    m == AppThemeMode.sunset || m == AppThemeMode.ocean;

// Fixed: exhaustive switch — all 7 AppThemeMode values covered
String _modeLabel(AppThemeMode m) => switch (m) {
  AppThemeMode.system       => 'Auto',
  AppThemeMode.light        => 'Day River',
  AppThemeMode.dark         => 'Night River',
  AppThemeMode.sunset       => 'Sunset Warm',
  AppThemeMode.ocean        => 'Deep Ocean',
  AppThemeMode.roboticDark  => 'Tactical Dark',
  AppThemeMode.roboticLight => 'System Light',
};

IconData _modeIcon(AppThemeMode m) => switch (m) {
  AppThemeMode.system       => Icons.brightness_auto,
  AppThemeMode.light        => Icons.wb_sunny,
  AppThemeMode.dark         => Icons.nights_stay,
  AppThemeMode.sunset       => Icons.wb_twilight,
  AppThemeMode.ocean        => Icons.water,
  AppThemeMode.roboticDark  => Icons.memory_rounded,
  AppThemeMode.roboticLight => Icons.developer_board_rounded,
};

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String      title;
  final IconData    icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(icon, color: rc.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color:          rc.textSecondary,
                    fontSize:       10,
                    fontWeight:     FontWeight.w700,
                    letterSpacing:  1.2,
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    required this.trailing,
  });
  final IconData  icon;
  final String    label;
  final String    sublabel;
  final VoidCallback? onTap;
  final Widget    trailing;

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
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
                  color:        rc.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: rc.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          color:      rc.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize:   14,
                        )),
                    Text(sublabel,
                        style: TextStyle(
                          color:    rc.textSecondary,
                          fontSize: 11,
                        )),
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
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: AppPalette.abyssStroke,
      );
}
