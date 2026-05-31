// lib/screens/splash_screen.dart
// EQUINOX-BR05 — SplashScreen v6  (Deep Space — ultra-minimal premium)
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../services/api_service.dart';
import '../theme/river_theme.dart';
import 'home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late AnimationController _ringCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _ringRot;
  late Animation<double>   _logoFade;
  late Animation<double>   _logoScale;
  late Animation<double>   _textFade;
  late Animation<Offset>   _textSlide;
  late Animation<double>   _barProgress;

  String _status = 'Initializing system…';
  bool   _online = false;
  Timer? _msgTimer;
  int    _msgIdx = 0;

  static const _msgs = [
    'Connecting to backend…',
    'Loading river data…',
    'Syncing flood sensors…',
    'Almost ready…',
  ];

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _ringRot = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.linear));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _logoFade  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0, 0.5)));
    _logoScale = Tween<double>(begin: 0.7, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOutCubic)));
    _textFade  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.4, 0.85)));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)));
    _barProgress = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.3, 1.0)));

    _fadeCtrl.forward();

    _msgTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() {
        _msgIdx = (_msgIdx + 1) % _msgs.length;
        _status = _msgs[_msgIdx];
      });
    });

    Future.delayed(const Duration(milliseconds: 600), _checkBackend);
  }

  Future<void> _checkBackend() async {
    try {
      final h = await _apiService.checkHealth();
      if (mounted) setState(() { _online = h; });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    _msgTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, a, __) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _fadeCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RadialGlowPainter()),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_ringCtrl, _fadeCtrl]),
                  builder: (_, __) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: SizedBox(
                        width: 120, height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: _ringRot.value,
                              child: CustomPaint(
                                size: const Size(120, 120),
                                painter: _ArcRingPainter(),
                              ),
                            ),
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.abyss2,
                                border: Border.all(
                                    color: AppPalette.cyan.withValues(alpha: 0.25),
                                    width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppPalette.cyan.withValues(alpha: 0.18),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.water_drop_rounded,
                                  color: AppPalette.cyan, size: 32),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const Column(
                      children: [
                        Text('EQUINOX-BR05',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textWhite,
                              letterSpacing: 1.5,
                            )),
                        SizedBox(height: 6),
                        Text('Real-time flood intelligence',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.textGrey,
                              letterSpacing: 0.8,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                AnimatedBuilder(
                  animation: _barProgress,
                  builder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: _barProgress.value,
                          backgroundColor: AppPalette.abyssStroke,
                          valueColor: const AlwaysStoppedAnimation(AppPalette.cyan),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_status,
                      key: ValueKey(_status),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.textGrey,
                          letterSpacing: 0.6)),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_online ? AppPalette.safe : AppPalette.textGrey)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_online ? AppPalette.safe : AppPalette.textGrey)
                          .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _online ? AppPalette.safe : AppPalette.textGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_online ? 'Backend online' : 'Connecting…',
                          style: TextStyle(
                            fontSize: 10,
                            color: _online ? AppPalette.safe : AppPalette.textGrey,
                            letterSpacing: 0.5,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF00C6FF).withValues(alpha: 0.07),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.4),
          radius: size.width * 0.6));
    canvas.drawRect(Offset.zero & size, paint);
  }
  @override bool shouldRepaint(_) => false;
}

class _ArcRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF00C6FF).withValues(alpha: 0.12);
    canvas.drawCircle(Offset(cx, cy), r, paint);

    paint.shader = SweepGradient(colors: [
      Colors.transparent,
      const Color(0xFF00C6FF).withValues(alpha: 0.9),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0, math.pi * 1.5, false, paint,
    );
  }
  @override bool shouldRepaint(_) => false;
}
