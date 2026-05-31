import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';

// ─── Premium filter colour swatches ──────────────────────────────────────────
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
    mode:     AppThemeMode.sunset,
    label:    'Sunset Warm',
    subtitle: 'Golden hour glow',
    icon:     Icons.wb_twilight,
    gradient: [Color(0xFF7B2D00), Color(0xFFE06000)],
    isPremium: true,
  ),
  _FilterMeta(
    mode:     AppThemeMode.ocean,
    label:    'Deep Ocean',
    subtitle: 'Midnight depths',
    icon:     Icons.water,
    gradient: [Color(0xFF001428), Color(0xFF003366)],
    isPremium: true,
  ),
];

@immutable
class _FilterMeta {
  final AppThemeMode mode;
  final String       label;
  final String       subtitle;
  final IconData     icon;
  final List<Color>  gradient;
  final bool         isPremium;
  const _FilterMeta({
    required this.mode, required this.label, required this.subtitle,
    required this.icon, required this.gradient, required this.isPremium,
  });
}

// ─── Public helper ────────────────────────────────────────────────────────────
// FIX: use builder: (ctx) not builder: (_) so the sheet receives the correct
// BuildContext that is still inside the root ProviderScope widget tree.
void showPremiumThemeSheet(BuildContext context) {
  showModalBottomSheet(
    context:          context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PremiumThemeSheet(),
  );
}

// ─── Sheet widget ─────────────────────────────────────────────────────────────
class _PremiumThemeSheet extends ConsumerWidget {
  const _PremiumThemeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current  = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final rc       = RiverColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color:        rc.cardBgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: rc.stroke, width: 1),
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
                  color:        rc.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.palette_outlined, color: rc.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Select Theme',
                    style: TextStyle(
                      color:      rc.textPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._kFilters.map((f) => _FilterTile(
                meta:      f,
                isActive:  current == f.mode,
                onTap:     () {
                  notifier.setMode(f.mode);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.meta,
    required this.isActive,
    required this.onTap,
  });

  final _FilterMeta meta;
  final bool        isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve:    Curves.easeOutCubic,
            padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(colors: meta.gradient)
                  : null,
              color: isActive ? null : rc.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? meta.gradient.last : rc.stroke,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // swatch circle
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: meta.gradient),
                    shape:    BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20), width: 1.5,
                    ),
                  ),
                  child: Icon(meta.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            meta.label,
                            style: TextStyle(
                              color:      isActive ? Colors.white : rc.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize:   14,
                            ),
                          ),
                          if (meta.isPremium) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:        AppPalette.amber.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppPalette.amber.withValues(alpha: 0.50)),
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color:      AppPalette.amber,
                                  fontSize:   9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.subtitle,
                        style: TextStyle(
                          color:    isActive
                              ? Colors.white.withValues(alpha: 0.75)
                              : rc.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(Icons.check_circle, color: Colors.white, size: 22)
                else
                  Icon(Icons.circle_outlined, color: rc.stroke, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
