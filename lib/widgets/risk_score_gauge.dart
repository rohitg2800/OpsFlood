import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../providers/risk_score_provider.dart';
import '../utils/flood_severity.dart';

/// Resolves issue #19: AI Risk Score Gauge Widget
/// Animated gauge showing 0-100 risk score with color zones
class RiskScoreGauge extends StatefulWidget {
  final double score;
  final RiskZone zone;
  final double size;

  const RiskScoreGauge({
    super.key,
    required this.score,
    required this.zone,
    this.size = 160,
  });

  @override
  State<RiskScoreGauge> createState() => _RiskScoreGaugeState();
}

class _RiskScoreGaugeState extends State<RiskScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnimation;
  double _previousScore = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _scoreAnimation =
        Tween<double>(begin: 0, end: widget.score).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(RiskScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _scoreAnimation = Tween<double>(
              begin: _previousScore, end: widget.score)
          .animate(CurvedAnimation(
              parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
    _previousScore = widget.score;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _zoneColor(RiskZone zone) {
    switch (zone) {
      case RiskZone.low: return FloodSeverityColor.normal;
      case RiskZone.moderate: return FloodSeverityColor.watch;
      case RiskZone.high: return FloodSeverityColor.warning;
      case RiskZone.veryHigh: return FloodSeverityColor.danger;
      case RiskZone.critical: return FloodSeverityColor.extreme;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scoreAnimation,
      builder: (context, _) {
        final animatedScore = _scoreAnimation.value;
        final currentZone = RiskZone.fromScore(animatedScore);
        final color = _zoneColor(currentZone);

        return SizedBox(
          width: widget.size,
          height: widget.size * 0.7,
          child: CustomPaint(
            painter: _GaugePainter(
              score: animatedScore,
              color: color,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: widget.size * 0.2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      animatedScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: widget.size * 0.22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      widget.zone.label,
                      style: TextStyle(
                        fontSize: widget.size * 0.1,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.42;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false, bgPaint);

    // Colored zone arcs
    final zones = [
      (FloodSeverityColor.normal, 0.0, 0.2),
      (FloodSeverityColor.watch, 0.2, 0.2),
      (FloodSeverityColor.warning, 0.4, 0.2),
      (FloodSeverityColor.danger, 0.6, 0.2),
      (FloodSeverityColor.extreme, 0.8, 0.2),
    ];
    for (final zone in zones) {
      final zonePaint = Paint()
        ..color = (zone.$1).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (zone.$2) * sweepAngle,
        (zone.$3) * sweepAngle,
        false, zonePaint);
    }

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, (score / 100) * sweepAngle, false, scorePaint);

    // Needle
    final needleAngle =
        startAngle + (score / 100) * sweepAngle;
    final needleEnd = Offset(
      center.dx + (radius - 10) * math.cos(needleAngle),
      center.dy + (radius - 10) * math.sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    canvas.drawCircle(center, 6,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}
