import 'package:flutter/material.dart';

class AnimatedAlertBadge extends StatefulWidget {
  final int count;
  final bool isCritical;
  final String label;

  const AnimatedAlertBadge({
    super.key,
    required this.count,
    this.isCritical = false,
    this.label = 'Active Alerts',
  });

  @override
  State<AnimatedAlertBadge> createState() => _AnimatedAlertBadgeState();
}

class _AnimatedAlertBadgeState extends State<AnimatedAlertBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // FIX: removed Transform.scale which caused the badge to visually
        // grow outside its layout box and overlap the gauge below it.
        // Replaced with a subtle opacity pulse which stays within bounds.
        final opacity = 0.75 + (_pulse.value * 0.25);
        return Opacity(
          opacity: opacity,
          child: Container(
            // FIX: full-width row instead of min-width bubble that could
            // render outside safe bounds when scaled.
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.7)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 0,
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.7), blurRadius: 6)
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.label}: ${widget.count}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
