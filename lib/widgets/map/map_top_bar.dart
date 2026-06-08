// lib/widgets/map/map_top_bar.dart
// MapTopBar       — COMMAND CENTER header + view-mode toggle chips.
// MapIconBtn      — square icon button reused by MapScreen.
// MapToggleChip   — animated Bihar / National mode chip.
import 'package:flutter/material.dart';
import '../../providers/map_command_provider.dart';
import '../../theme/rx.dart';

// ── MapTopBar ─────────────────────────────────────────────────────────────────
class MapTopBar extends StatelessWidget {
  final MapViewMode  mode;
  final SyncMeta     syncMeta;
  final bool         drawerOpen;
  final VoidCallback onToggle;
  final VoidCallback onDrawerToggle;

  const MapTopBar({
    super.key,
    required this.mode,
    required this.syncMeta,
    required this.drawerOpen,
    required this.onToggle,
    required this.onDrawerToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rc      = context.rc;
    final isBihar = mode == MapViewMode.bihar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        rc.cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: rc.stroke, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radar_rounded,
                        color: rc.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'COMMAND CENTER',
                      style: TextStyle(
                        color:         rc.textPrimary,
                        fontSize:      13,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            MapIconBtn(
              icon:    drawerOpen
                           ? Icons.close_rounded
                           : Icons.list_rounded,
              onTap:   onDrawerToggle,
              tooltip: 'Live Telemetry',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MapToggleChip(
              label:  '🗺 Bihar',
              active: isBihar,
              onTap:  isBihar ? null : onToggle,
            ),
            const SizedBox(width: 8),
            MapToggleChip(
              label:  '🇮🇳 National',
              active: !isBihar,
              onTap:  isBihar ? onToggle : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:        rc.cardBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(
                color: rc.stroke.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_rounded, size: 13, color: rc.accent),
              const SizedBox(width: 6),
              Text(
                'Data last synced: ${syncMeta.freshnessLabel}',
                style: TextStyle(
                  color:      rc.textSecondary,
                  fontSize:   11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── MapIconBtn ────────────────────────────────────────────────────────────────
class MapIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final String       tooltip;

  const MapIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color:        rc.cardBg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: rc.stroke),
          ),
          child: Icon(icon, color: rc.accent, size: 20),
        ),
      ),
    );
  }
}

// ── MapToggleChip ─────────────────────────────────────────────────────────────
class MapToggleChip extends StatelessWidget {
  final String        label;
  final bool          active;
  final VoidCallback? onTap;

  const MapToggleChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? rc.accent.withValues(alpha: 0.15)
              : rc.cardBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? rc.accent : rc.stroke,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      active ? rc.accent : rc.textSecondary,
            fontSize:   12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
