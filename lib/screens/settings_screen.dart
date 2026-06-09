// lib/screens/settings_screen.dart
// OpsFlood — SettingsScreen v4
// v4: Added “Reset Onboarding” tile under a new ADVANCED section.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/onboarding_provider.dart';
import '../theme/river_theme.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  static const String route = '/settings';
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final s      = context.l10n;
    final mode   = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: t.scaffoldBg,
                  border: Border(
                      bottom: BorderSide(
                          color: t.stroke.withValues(alpha: 0.5),
                          width: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: t.accent.withValues(alpha: 0.10),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.28),
                            width: 1.5),
                      ),
                      child: Icon(Icons.settings_rounded,
                          color: t.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s.settings.toUpperCase(),
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ─────────────── LANGUAGE ──────────────────
                    _SectionLabel(s.appLanguage, t: t),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _LangChip(
                          label: 'English',
                          nativeLabel: 'English',
                          flag: '\ud83c\uddec\ud83c\udde7',
                          active: locale.languageCode == 'en',
                          t: t,
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await ref
                                .read(localeProvider.notifier)
                                .setLocale(const Locale('en'));
                            if (context.mounted) {
                              _showToast(context,
                                  context.l10n.restartRequired, t);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _LangChip(
                          label: 'Hindi',
                          nativeLabel: '\u0939\u093f\u0928\u094d\u0926\u0940',
                          flag: '\ud83c\uddee\ud83c\uddf3',
                          active: locale.languageCode == 'hi',
                          t: t,
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await ref
                                .read(localeProvider.notifier)
                                .setLocale(const Locale('hi'));
                            if (context.mounted) {
                              _showToast(context,
                                  context.l10n.restartRequired, t);
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ──────────────── THEME ───────────────────
                    _SectionLabel(s.selectTheme, t: t),
                    const SizedBox(height: 10),
                    ...AppThemeMode.values.map((m) => _ThemeTile(
                          mode: m,
                          selected: mode == m,
                          t: t,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(m);
                          },
                        )),

                    const SizedBox(height: 28),

                    // ─────────────── ADVANCED ─────────────────
                    _SectionLabel('Advanced', t: t),
                    const SizedBox(height: 10),
                    _ResetOnboardingTile(t: t),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(BuildContext ctx, String msg, RiverColors t) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: TextStyle(
                color: t.textPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: t.cardBg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Reset Onboarding Tile ────────────────────────────────────────────────

class _ResetOnboardingTile extends ConsumerWidget {
  final RiverColors t;
  const _ResetOnboardingTile({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        // Confirm before resetting
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: t.cardBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Reset Onboarding',
                style: TextStyle(
                    color: t.textPrimary, fontWeight: FontWeight.w800)),
            content: Text(
              'This will show the onboarding tutorial again on next app launch.',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: t.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reset',
                    style: TextStyle(
                        color: t.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await ref.read(onboardingProvider.notifier).reset();
          if (context.mounted) {
            Navigator.pushReplacementNamed(
                context, OnboardingScreen.route);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.replay_rounded,
                color: t.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset Onboarding',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Replay the intro tutorial',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: t.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Language chip ────────────────────────────────────────────────────────────────

class _LangChip extends StatelessWidget {
  final String   label;
  final String   nativeLabel;
  final String   flag;
  final bool     active;
  final RiverColors t;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.nativeLabel,
    required this.flag,
    required this.active,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? t.accent.withValues(alpha: 0.12)
                : t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? t.accent.withValues(alpha: 0.55)
                  : t.stroke,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [BoxShadow(color: t.accentGlow, blurRadius: 10)]
                : [],
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeLabel,
                      style: TextStyle(
                        color: active ? t.accent : t.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (active)
                Icon(Icons.check_circle_rounded,
                    color: t.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme tile ──────────────────────────────────────────────────────────────────

class _ThemeTile extends StatelessWidget {
  final AppThemeMode mode;
  final bool         selected;
  final RiverColors  t;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.mode,
    required this.selected,
    required this.t,
    required this.onTap,
  });

  static String _label(AppThemeMode m, BuildContext ctx) {
    final s = ctx.l10n;
    switch (m) {
      case AppThemeMode.system:       return s.themeAuto;
      case AppThemeMode.light:        return s.themeDay;
      case AppThemeMode.dark:         return s.themeDark;
      case AppThemeMode.sunset:       return s.themeSunset;
      case AppThemeMode.ocean:        return s.themeOcean;
      case AppThemeMode.roboticDark:  return 'Robotic Dark';
      case AppThemeMode.roboticLight: return 'Robotic Light';
    }
  }

  static IconData _icon(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.system:       return Icons.brightness_auto_rounded;
      case AppThemeMode.light:        return Icons.wb_sunny_rounded;
      case AppThemeMode.dark:         return Icons.dark_mode_rounded;
      case AppThemeMode.sunset:       return Icons.wb_twilight_rounded;
      case AppThemeMode.ocean:        return Icons.waves_rounded;
      case AppThemeMode.roboticDark:  return Icons.memory_rounded;
      case AppThemeMode.roboticLight: return Icons.memory_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.09)
              : t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? t.accent.withValues(alpha: 0.45)
                : t.stroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(_icon(mode),
                color: selected ? t.accent : t.textSecondary,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _label(mode, context),
                style: TextStyle(
                  color: selected ? t.accent : t.textPrimary,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: t.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final RiverColors t;
  const _SectionLabel(this.text, {required this.t});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: t.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}
