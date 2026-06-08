// lib/widgets/universe_splash_painter.dart
// Universe-theme boot animation — generative deep-space starfield with
// pulsing galactic core. Runs at 60 FPS via RepaintBoundary + CustomPainter.
// Consumed by SplashPage (lib/screens/splash_screen.dart).

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Data model for a single star ─────────────────────────────────────────

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.layer,   // 0 = far (slow), 1 = mid, 2 = near (fast)
    required this.twinkleOffset,
  });

  double x, y;
  final double radius;
  final double opacity;
  final int    layer;
  final double twinkleOffset;
}

// ─── CustomPainter ─────────────────────────────────────────────────────────

class UniversePainter extends CustomPainter {
  UniversePainter({
    required this.animation,
    required this.stars,
    required this.coreGlow,
    required this.fadeOut,   // 0.0 = fully visible, 1.0 = fully faded out
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Star>       stars;
  final Animation<double> coreGlow;   // 0..1 pulse
  final double            fadeOut;    // 0..1

  static const _bgColor    = Color(0xFF030508);
  static const _coreColor1 = Color(0xFF00FFB2);
  static const _coreColor2 = Color(0xFF004FFF);
  static const _coreColor3 = Color(0xFF9B00FF);

  // Parallax speed per layer
  static const _layerSpeed = [0.003, 0.007, 0.013];

  @override
  void paint(Canvas canvas, Size size) {
    final t      = animation.value;  // 0..1 continuous
    final master = 1.0 - fadeOut;

    // ── Background ──────────────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _bgColor.withValues(alpha: master),
    );
    if (master < 0.01) return;

    final cx = size.width  * 0.5;
    final cy = size.height * 0.46;

    // ── Starfield with parallax ──────────────────────────────────────────
    for (final s in stars) {
      final drift = _layerSpeed[s.layer] * t * size.width;
      final sx    = (s.x + drift) % size.width;
      final sy    = s.y;

      // Subtle twinkle
      final twinkle = 0.6 + 0.4 * math.sin(t * math.pi * 6 + s.twinkleOffset);
      final alpha   = (s.opacity * twinkle * master).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(sx, sy),
        s.radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // ── Galactic core ────────────────────────────────────────────────────
    final pulse  = coreGlow.value;              // 0..1
    final coreR  = size.width * (0.18 + 0.04 * pulse);
    final glowR  = size.width * (0.38 + 0.06 * pulse);

    // Outer diffuse halo
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _coreColor1.withValues(alpha: 0.12 * master),
            _coreColor3.withValues(alpha: 0.05 * master),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR)),
    );

    // Mid-core glow ring
    canvas.drawCircle(
      Offset(cx, cy),
      coreR * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _coreColor2.withValues(alpha: 0.20 * master),
            _coreColor1.withValues(alpha: 0.08 * master),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR * 1.6)),
    );

    // Bright core nucleus
    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * master),
            _coreColor1.withValues(alpha: 0.7  * master),
            _coreColor2.withValues(alpha: 0.3  * master),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR)),
    );

    // Lens flare cross-hairs
    _drawLensFlare(canvas, Offset(cx, cy), coreR * 0.05, master);
  }

  void _drawLensFlare(Canvas canvas, Offset center, double r, double alpha) {
    final paint = Paint()
      ..color       = Colors.white.withValues(alpha: 0.15 * alpha)
      ..strokeWidth = 1
      ..strokeCap   = StrokeCap.round;
    const len = 40.0;
    canvas.drawLine(center.translate(-len, 0), center.translate(len, 0),  paint);
    canvas.drawLine(center.translate(0, -len), center.translate(0, len),  paint);
    canvas.drawLine(center.translate(-len * 0.7, -len * 0.7),
                    center.translate( len * 0.7,  len * 0.7), paint);
    canvas.drawLine(center.translate( len * 0.7, -len * 0.7),
                    center.translate(-len * 0.7,  len * 0.7), paint);
  }

  @override
  bool shouldRepaint(UniversePainter old) =>
      old.fadeOut != fadeOut || old.animation.value != animation.value;
}

// ─── Factory to build the star field once ─────────────────────────────────

List<_Star> buildStarField(int count, Size size) {
  final rng = math.Random(42);
  return List.generate(count, (_) {
    final layer = rng.nextInt(3);  // 0=far,1=mid,2=near
    return _Star(
      x:             rng.nextDouble() * size.width,
      y:             rng.nextDouble() * size.height,
      radius:        0.4 + rng.nextDouble() * (layer == 2 ? 1.8 : layer == 1 ? 1.2 : 0.7),
      opacity:       0.3 + rng.nextDouble() * 0.7,
      layer:         layer,
      twinkleOffset: rng.nextDouble() * math.pi * 2,
    );
  });
}
