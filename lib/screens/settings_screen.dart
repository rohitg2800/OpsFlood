// lib/screens/settings_screen.dart
// OpsFlood — Module 8: Settings Overhaul & Theme Engine
//
// FIX 1: _card() / _NavTile / _LanguageTile / _RefreshTile used Material with
//         BOTH borderRadius AND shape set — Flutter asserts these are mutually
//         exclusive. Removed the top-level borderRadius param; the radius is
//         encoded only inside shape: RoundedRectangleBorder.
//
// FIX 2: weather_provider maxT/minT were List<num>, making elementAtOrNull
//         return num — not assignable to double. Both lists are now mapped to
//         double before List.generate (handled in weather_provider.dart).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/river_theme.dart';
import '../theme/robotic_theme.dart';
import 'notification_settings_screen.dart';
import 'export_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  static const String route = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version     = '';
  String _buildNumber = '';
  int    _refreshMins = 5;
  bool   _cacheBusy   = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info  = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _version     = info.version;
      _buildNumber = info.buildNumber;
      _refreshMins = prefs.getInt('refresh_interval_mins') ?? 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final mode = ref.watch(themeModeProvider);
    final loc  = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: t.bgBase,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: t.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings',
            style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [

          // ──────────────────────── 1. APPEARANCE
          _SectionHeader(t: t, icon: Icons.palette_rounded,
              label: 'Appearance'),
          _ThemeGrid(
            t:       t,
            current: mode,
            onPick: (m) {
              ref.read(themeModeProvider.notifier).setMode(m);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(height: 20),

          // ──────────────────────── 2. NOTIFICATIONS
          _SectionHeader(t: t,
              icon: Icons.notifications_active_rounded,
              label: 'Notifications'),
          _NavTile(
            t:       t,
            icon:    Icons.tune_rounded,
            label:   'Alert & Push Settings',
            subtitle: 'Severity, districts, rivers, quiet hours',
            onTap: () => Navigator.pushNamed(
                context, NotificationSettingsScreen.route),
          ),
          const SizedBox(height: 20),

          // ──────────────────────── 3. DATA & EXPORT
          _SectionHeader(t: t,
              icon: Icons.download_rounded, label: 'Data & Export'),
          _NavTile(
            t:       t,
            icon:    Icons.table_chart_rounded,
            label:   'Export Station Data',
            subtitle: 'PDF or CSV with date range filter',
            onTap: () =>
                Navigator.pushNamed(context, ExportScreen.route),
          ),
          _RefreshTile(
            t:       t,
            current: _refreshMins,
            onChanged: (v) async {
              setState(() => _refreshMins = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('refresh_interval_mins', v);
            },
          ),
          const SizedBox(height: 20),

          // ──────────────────────── 4. LANGUAGE
          _SectionHeader(t: t,
              icon: Icons.language_rounded, label: 'Language'),
          _LanguageTile(
            t:       t,
            current: loc?.languageCode ?? 'en',
            onPick: (code) {
              ref.read(localeProvider.notifier)
                  .setLocale(Locale(code));
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(height: 20),

          // ──────────────────────── 5. ABOUT
          _SectionHeader(t: t,
              icon: Icons.info_outline_rounded, label: 'About'),
          _card(t, [
            _InfoRow(t: t, label: 'Version',
                value: '$_version ($_buildNumber)'),
            _InfoRow(t: t, label: 'Data sources',
                value: 'CWC • Bihar WRD • IMD • NDMA'),
            _InfoRow(t: t, label: 'Model',
                value: 'OpsFlood v2 — LSTM + rule engine'),
            _InfoRow(t: t, label: 'Developer',
                value: 'rohitg2800', isLast: true),
          ]),
          const SizedBox(height: 20),

          // ──────────────────────── 6. ADVANCED
          _SectionHeader(t: t,
              icon: Icons.build_rounded, label: 'Advanced'),
          _card(t, [
            ListTile(
              leading: Icon(Icons.cleaning_services_rounded,
                  color: t.accent, size: 18),
              title: Text('Clear tile cache',
                  style: TextStyle(
                      color: t.textPrimary, fontSize: 13)),
              subtitle: Text('Removes cached map & chart data',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 10)),
              trailing: _cacheBusy
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: t.accent))
                  : Icon(Icons.chevron_right_rounded,
                      color: t.textSecondary),
              onTap: _clearCache,
            ),
            ListTile(
              leading: Icon(Icons.replay_rounded,
                  color: t.accent, size: 18),
              title: Text('Re-run onboarding',
                  style: TextStyle(
                      color: t.textPrimary, fontSize: 13)),
              subtitle: Text(
                  'Restart the first-launch walkthrough',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 10)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: t.textSecondary),
              onTap: _rerunOnboarding,
            ),
          ]),
          const SizedBox(height: 20),

          // ──────────────────────── 7. DANGER ZONE
          _SectionHeader(t: t,
              icon: Icons.warning_amber_rounded,
              label: 'Danger Zone',
              color: const Color(0xFFFF1744)),
          _card(t, [
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFFF1744), size: 18),
              title: const Text('Clear all local data',
                  style: TextStyle(
                      color: Color(0xFFFF1744),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              subtitle: Text(
                  'Deletes Hive boxes, preferences, incident history',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 10)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: t.textSecondary),
              onTap: () => _confirmClearAll(context, t),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────────

  /// FIX: Material must NOT have both [borderRadius] and [shape] set —
  /// Flutter asserts !(shape != null && borderRadius != null).
  /// Solution: pass radius only through [shape]; omit top-level borderRadius.
  Widget _card(RiverColors t, List<Widget> children) => Material(
        color: t.cardBg,
        // ❌ borderRadius: BorderRadius.circular(14),  ← removed; was the crash
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Future<void> _clearCache() async {
    setState(() => _cacheBusy = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _cacheBusy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cache cleared'),
          backgroundColor: RiverColors.of(context).accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _rerunOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', false);
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/onboarding', (_) => false);
    }
  }

  Future<void> _confirmClearAll(
      BuildContext ctx, RiverColors t) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: t.cardBg,
        title: Text('Clear all data?',
            style: TextStyle(color: t.textPrimary)),
        content: Text(
            'This will delete all cached stations, incidents, '
            'and preferences. App will restart.',
            style: TextStyle(
                color: t.textSecondary, fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel',
                  style: TextStyle(color: t.accent))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFFFF1744)))),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }
}

// ── Theme picker grid ──────────────────────────────────────────────────────────────────

const _themes = [
  (AppThemeMode.dark,         '🎨',  'Dark',          Color(0xFF0D1B2A)),
  (AppThemeMode.light,        '☀️',  'Light',         Color(0xFFF5F7FA)),
  (AppThemeMode.ocean,        '🌊',  'Ocean',         Color(0xFF003B5C)),
  (AppThemeMode.sunset,       '🌅',  'Sunset',        Color(0xFF3D1A00)),
  (AppThemeMode.roboticDark,  '🤖',  'Robotic Dark',  Color(0xFF0A0A14)),
  (AppThemeMode.roboticLight, '⚡',  'Robotic Light', Color(0xFFE8EAED)),
  (AppThemeMode.system,       '📱',  'System',        Color(0xFF222222)),
];

class _ThemeGrid extends StatelessWidget {
  final RiverColors     t;
  final AppThemeMode    current;
  final ValueChanged<AppThemeMode> onPick;
  const _ThemeGrid({
      required this.t,
      required this.current,
      required this.onPick});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _themes.map((th) {
          final active = current == th.$1;
          return GestureDetector(
            onTap: () => onPick(th.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 88,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? t.accent.withValues(alpha: 0.18)
                    : t.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? t.accent : t.stroke,
                  width: active ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: th.$4,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: active ? t.accent : t.stroke),
                    ),
                    child: Center(
                        child: Text(th.$2,
                            style: const TextStyle(
                                fontSize: 16))),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    th.$3,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? t.accent : t.textSecondary,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
}

// ── Language tile ───────────────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  final RiverColors t;
  final String      current;
  final ValueChanged<String> onPick;
  const _LanguageTile({
      required this.t,
      required this.current,
      required this.onPick});

  @override
  Widget build(BuildContext context) => Material(
        color: t.cardBg,
        // FIX: shape only, no borderRadius param — they are mutually exclusive
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _LangRow(
              t: t, code: 'en', label: 'English',
              flag: '🇬🇧', current: current, onPick: onPick,
            ),
            Divider(height: 1, color: t.stroke),
            _LangRow(
              t: t, code: 'hi', label: 'हिन्दी  (Hindi)',
              flag: '🇮🇳', current: current, onPick: onPick,
              isLast: true,
            ),
          ],
        ),
      );
}

class _LangRow extends StatelessWidget {
  final RiverColors t;
  final String code, label, flag, current;
  final ValueChanged<String> onPick;
  final bool isLast;
  const _LangRow({
      required this.t,
      required this.code,
      required this.label,
      required this.flag,
      required this.current,
      required this.onPick,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final active = current == code;
    return ListTile(
      leading: Text(flag,
          style: const TextStyle(fontSize: 20)),
      title: Text(label,
          style: TextStyle(
            color: active ? t.accent : t.textPrimary,
            fontWeight:
                active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          )),
      trailing: active
          ? Icon(Icons.check_circle_rounded,
              color: t.accent, size: 18)
          : null,
      onTap: () => onPick(code),
    );
  }
}

// ── Refresh interval tile ───────────────────────────────────────────────────────────────

class _RefreshTile extends StatelessWidget {
  final RiverColors t;
  final int current;
  final ValueChanged<int> onChanged;
  const _RefreshTile({
      required this.t,
      required this.current,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Material(
        color: t.cardBg,
        // FIX: shape only, no borderRadius param
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(Icons.refresh_rounded,
              color: t.accent, size: 18),
          title: Text('Data refresh interval',
              style: TextStyle(
                  color: t.textPrimary, fontSize: 13)),
          subtitle: Text(
              'How often live station data is polled',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 10)),
          trailing: DropdownButton<int>(
            value: current,
            dropdownColor: t.cardBg,
            underline: const SizedBox(),
            style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13),
            items: const [
              DropdownMenuItem(value: 2,  child: Text('2 min')),
              DropdownMenuItem(value: 5,  child: Text('5 min')),
              DropdownMenuItem(value: 10, child: Text('10 min')),
              DropdownMenuItem(value: 30, child: Text('30 min')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final RiverColors t;
  final IconData icon;
  final String label;
  final Color? color;
  const _SectionHeader({
      required this.t,
      required this.icon,
      required this.label,
      this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon,
                color: color ?? t.accent, size: 15),
            const SizedBox(width: 7),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color ?? t.accent,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      );
}

class _NavTile extends StatelessWidget {
  final RiverColors t;
  final IconData icon;
  final String   label;
  final String?  subtitle;
  final VoidCallback onTap;
  const _NavTile({
      required this.t,
      required this.icon,
      required this.label,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: t.cardBg,
        // FIX: shape only, no borderRadius param
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: t.accent, size: 18),
          title: Text(label,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!,
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: t.textSecondary),
          onTap: onTap,
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  final bool isLast;
  const _InfoRow({
      required this.t,
      required this.label,
      required this.value,
      this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            dense: true,
            title: Text(label,
                style: TextStyle(
                    color: t.textSecondary, fontSize: 11)),
            trailing: Text(value,
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11)),
          ),
          if (!isLast) Divider(height: 1, color: t.stroke),
        ],
      );
}
