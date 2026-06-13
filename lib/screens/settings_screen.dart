// lib/screens/settings_screen.dart  — 3-D UI rebuild
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_registry.dart';
import '../theme/theme_3d.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final tr = context.watch<ThemeRegistry>();
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Settings',
            subtitle: 'App preferences',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Appearance ──────────────────────────────────────────
                const Td3SectionHeader('Appearance'),
                const SizedBox(height: 10),
                Td3Card(
                  elevation: Td3.elevMid,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.palette_rounded,
                        title: 'Theme',
                        subtitle: tr.currentThemeName,
                        onTap: () => _showThemePicker(context, tr),
                      ),
                      const Td3Divider(),
                      _SettingsTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'Dark Mode',
                        subtitle: t.isDark ? 'On' : 'Off',
                        onTap: () => tr.toggleDark(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Notifications ────────────────────────────────────────
                const Td3SectionHeader('Notifications'),
                const SizedBox(height: 10),
                Td3Card(
                  elevation: Td3.elevMid,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Flood Alerts',
                        subtitle: 'Danger & warning levels',
                        trailing: Switch.adaptive(
                          value: true,
                          activeColor: t.accent,
                          onChanged: (_) {},
                        ),
                      ),
                      const Td3Divider(),
                      _SettingsTile(
                        icon: Icons.water_drop_rounded,
                        title: 'Rainfall Alerts',
                        subtitle: 'Heavy rain forecasts',
                        trailing: Switch.adaptive(
                          value: false,
                          activeColor: t.accent,
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Data ─────────────────────────────────────────────────
                const Td3SectionHeader('Data'),
                const SizedBox(height: 10),
                Td3Card(
                  elevation: Td3.elevMid,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.refresh_rounded,
                        title: 'Refresh Interval',
                        subtitle: 'Every 10 minutes',
                        onTap: () {},
                      ),
                      const Td3Divider(),
                      _SettingsTile(
                        icon: Icons.download_rounded,
                        title: 'Export Data',
                        subtitle: 'CSV / JSON',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── About ─────────────────────────────────────────────────
                const Td3SectionHeader('About'),
                const SizedBox(height: 10),
                Td3Card(
                  elevation: Td3.elevLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.water_rounded,
                              color: t.accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('OpsFlood Bihar',
                                  style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800)),
                              Text('Live Flood Intelligence v2.0',
                                  style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Td3Badge(
                            label: 'v2.0',
                            color: t.accent,
                            fontSize: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(
      BuildContext context, ThemeRegistry tr) {
    final t = RiverColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Td3SectionHeader('Choose Theme'),
            const SizedBox(height: 12),
            ...tr.themes.map((theme) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Td3Button(
                    label: theme.name,
                    color: tr.currentThemeName == theme.name
                        ? t.accent
                        : t.stroke,
                    onTap: () {
                      tr.setTheme(theme.name);
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Widget?  trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: t.accent, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10)),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: t.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
