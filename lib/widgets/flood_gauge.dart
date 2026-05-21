import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/river_theme.dart';

class FloodGauge extends StatefulWidget {
  final double capacity;
  final String riskLevel;
  final String label;
  final double size;

  const FloodGauge({
    super.key,
    required this.capacity,
    required this.riskLevel,
    this.label = 'Flood Risk',
    this.size = 220,
  });

  @override
  State<FloodGauge> createState() => _FloodGaugeState();
}

class _FloodGaugeState extends State<FloodGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.longAnimDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.capacity).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FloodGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capacity != widget.capacity) {
      _animation = Tween<double>(
        begin: oldWidget.capacity,
        end: widget.capacity,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _riskColor(double value) {
    if (value >= AppConstants.criticalThreshold) return const Color(0xFF8B0000);
    if (value >= AppConstants.highThreshold) return const Color(0xFFEF4444);
    if (value >= AppConstants.moderateThreshold) return const Color(0xFFF59E0B);
    return const Color(0xFF34C759);
  }

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = _animation.value.clamp(0.0, 100.0);
        final color = _riskColor(current);
        // FIX 1: ensure progress is always > 0 so sweep > 0 for SweepGradient
        final safeProgress = (current / 100).clamp(0.001, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rc.cardBg,
                      border: Border.all(
                          color: color.withOpacity(0.18), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.18),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Arc painter — safe progress passed in
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _GaugePainter(
                          progress: safeProgress, color: color),
                    ),
                  ),
                  // Needle
                  Transform.rotate(
                    angle: (-math.pi / 2) +
                        (2 * math.pi * safeProgress),
                    child: Container(
                      width: 3,
                      height: widget.size * 0.35,
                      margin:
                          EdgeInsets.only(bottom: widget.size * 0.33),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // FIX 2: wrap inner Column in FittedBox so text never overflows
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${current.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: rc.textPrimary,
                            fontSize: widget.size * 0.20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.riskLevel,
                          style: TextStyle(
                            color: color,
                            fontSize: (widget.size * 0.085)
                                .clamp(10.0, 14.0),
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: rc.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // always in (0, 1]
  final Color color;

  const _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - stroke;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color.withOpacity(0.12),
    );

    final startAngle = -math.pi / 2;
    final sweep = progress * 2 * math.pi;

    // FIX: only use SweepGradient when sweep is large enough (> tiny epsilon)
    // For very small sweeps just paint a solid arc to avoid the assertion.
    final Paint fg;
    if (sweep > 0.01) {
      fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweep, // guaranteed > startAngle
          colors: [
            color.withOpacity(0.4),
            color,
            color.withOpacity(0.6),
          ],
          tileMode: TileMode.clamp,
        ).createShader(
            Rect.fromCircle(center: center, radius: radius));
    } else {
      fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color.withOpacity(0.4);
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}
