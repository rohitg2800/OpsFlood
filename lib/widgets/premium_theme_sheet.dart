import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';

// ─── Premium filter colour swatches ────────────────────────────────────────────
const _kFilters = [
  _FilterMeta(
    mode:     AppThemeMode.system,
    label:    'Auto',
    subtitle: 'Follows device',
    icon:     Icons.brightness_auto,
    gradient: [Color(0xFF2A3A5C), Color(0xFF3A5080)],
    isPremium: false,
  ),
  _FilterMeta(
    mode:     AppThemeMode.light,
    label:    'Day River',
    subtitle: 'Bright & clear',
    icon:     Icons.wb_sunny,
    gradient: [Color(0xFF0A1628), Color(0xFF1A3060)],
    isPremium: false,
  ),
  _FilterMeta(
    mode:     AppThemeMode.dark,
    label:    'Night River',
    subtitle: 'Deep abyss',
    icon:     Icons.nights_stay,
    gradient: [Color(0xFF010810), Color(0xFF071525)],
    isPremium: false,
  ),
  _FilterMeta(
    mode:     AppThemeMode.amoled,
    label:    'AMOLED',
    subtitle: 'Pure black',
    icon:     Icons.circle,
    gradient: [Color(0xFF000000), Color(0xFF0A0A0A)],
    isPremium: false,
  ),
  _FilterMeta(
    mode:     AppThemeMode.saffron,
    label:    'Saffron Tide',
    subtitle: 'Warm & bold',
    icon:     Icons.local_fire_department,
    gradient: [Color(0xFF3D1A00), Color(0xFF7A3800)],
    isPremium: true,
  ),
  _FilterMeta(
    mode:     AppThemeMode.emerald,
    label:    'Emerald Delta',
    subtitle: 'Rich greens',
    icon:     Icons.eco,
    gradient: [Color(0xFF00280F), Color(0xFF00501E)],
    isPremium: true,
  ),
];

// ─── Sheet widget ──────────────────────────────────────────────────────────────────
class PremiumThemeSheet extends ConsumerWidget {
  const PremiumThemeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A58),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'APPEARANCE',
            style: TextStyle(
              color: Color(0xFF00B4D8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            _kFilters.length,
            (i) => _FilterTile(
              meta:      _kFilters[i],
              isActive:  _kFilters[i].mode == current,
              onTap: () {
                ref.read(themeModeProvider.notifier).set(_kFilters[i].mode);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile ──────────────────────────────────────────────────────────────────────────
class _FilterTile extends StatelessWidget {
  final _FilterMeta meta;
  final bool        isActive;
  final VoidCallback onTap;

  const _FilterTile({
    required this.meta,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: meta.gradient,
            begin: Alignment.centerLeft,
            end:   Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00B4D8)
                : Colors.white.withValues(alpha: 0.06),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(meta.icon, size: 18,
                color: isActive ? const Color(0xFF00B4D8) : Colors.white54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        meta.label,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (meta.isPremium) ...[const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9A825).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF9A825).withValues(alpha: 0.4)),
                          ),
                          child: const Text('PRO', style: TextStyle(color: Color(0xFFF9A825), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(meta.subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00B4D8), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Meta ──────────────────────────────────────────────────────────────────────────
class _FilterMeta {
  final AppThemeMode mode;
  final String       label;
  final String       subtitle;
  final IconData     icon;
  final List<Color>  gradient;
  final bool         isPremium;

  const _FilterMeta({
    required this.mode,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.isPremium,
  });
}
