import 'dart:convert';

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
    final color = widget.isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final scale = 1 + (_pulse.value * 0.08);
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.8)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.34),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$latin1: ${widget.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
