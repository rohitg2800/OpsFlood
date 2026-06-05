// ─────────────────────────────────────────────────────────────────────────────
//  LiveAlertBanner  —  Dismissible top-of-dashboard alert banner
//  Shows when one or more stations are in Danger or Extreme status.
//
//  Usage:
//    LiveAlertBanner(
//      message: 'Ganga at Hathidah: DANGER level crossed',
//      severity: FloodSeverity.danger,
//      onTap: () => Navigator.pushNamed(context, '/live_stations'),
//    )
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';

class LiveAlertBanner extends StatefulWidget {
  const LiveAlertBanner({
    super.key,
    required this.message,
    required this.severity,
    this.subMessage,
    this.onTap,
    this.onDismiss,
    this.autoDismissSeconds,
  });

  final String message;
  final String? subMessage;
  final FloodSeverity severity;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  /// Auto-dismiss after N seconds (null = stays until manually dismissed)
  final int? autoDismissSeconds;

  @override
  State<LiveAlertBanner> createState() => _LiveAlertBannerState();
}

class _LiveAlertBannerState extends State<LiveAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (widget.autoDismissSeconds != null) {
      Future.delayed(Duration(seconds: widget.autoDismissSeconds!), _dismiss);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || _dismissed) return;
    setState(() => _dismissed = true);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final c = FloodSeverityHelper.color(widget.severity);
    final glow = FloodSeverityHelper.glowColor(widget.severity);
    final icon = FloodSeverityHelper.icon(widget.severity);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap?.call();
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(color: glow, blurRadius: 14, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              // Pulsing alert icon
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnim.value,
                  child: Icon(icon, color: c, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c,
                        height: 1.2,
                      ),
                    ),
                    if (widget.subMessage != null) ...
                      [
                        const SizedBox(height: 2),
                        Text(
                          widget.subMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.textGrey,
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // View arrow
              if (widget.onTap != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    color: c.withValues(alpha: 0.8), size: 14),
              const SizedBox(width: 6),
              // Dismiss X
              GestureDetector(
                onTap: _dismiss,
                child: Icon(
                  Icons.close_rounded,
                  color: AppPalette.textGrey,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stack multiple banners for multiple simultaneous alerts
class LiveAlertBannerStack extends StatelessWidget {
  const LiveAlertBannerStack({super.key, required this.alerts});

  final List<LiveAlertBanner> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    // Show max 3 banners at once to avoid flooding the screen
    final visible = alerts.take(3).toList();
    return Column(children: visible);
  }
}
