// lib/widgets/premium_stat_card.dart
// OpsFlood — PremiumStatCard v3 (Abyss Ops rebuild)
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class PremiumStatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final String?  sub;
  final IconData icon;
  final Color    color;
  final bool     pulse;

  const PremiumStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.color = AppPalette.cyan,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + pulse dot
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (pulse) ...[
                const SizedBox(width: 6),
                _PulseDot(color: color),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppPalette.textGrey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 9,
                color: AppPalette.textGrey.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: 0.5 + 0.5 * _anim.value),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.6 * _anim.value),
            blurRadius: 6,
          ),
        ],
      ),
    ),
  );
}
