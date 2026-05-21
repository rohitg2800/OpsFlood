import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';

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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = _animation.value.clamp(0.0, 100.0).toDouble();
        final color = _riskColor(current);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.22),
                          blurRadius: 30,
                          spreadRadius: 4,
                        )
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter:
                        _GaugePainter(progress: current / 100, color: color),
                  ),
                  Transform.rotate(
                    angle: (-math.pi / 2) + (2 * math.pi * (current / 100)),
                    child: Container(
                      width: 3,
                      height: widget.size * 0.35,
                      margin: EdgeInsets.only(bottom: widget.size * 0.33),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${current.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.size * 0.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.riskLevel,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - stroke;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = Colors.white.withOpacity(0.14);

    canvas.drawCircle(center, radius, bg);

    final start = -math.pi / 2;
    final sweep = progress * 2 * math.pi;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [
          color.withOpacity(0.35),
          color,
          color.withOpacity(0.55),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
