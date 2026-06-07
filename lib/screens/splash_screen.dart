// lib/screens/splash_screen.dart
// Bihar Flood Command — Splash / Boot HUD v3
// Robotic boot sequence with Bihar branding.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/river_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  static const route = '/';
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _boot;
  late final AnimationController _fade;
  late final Animation<double> _fadeAnim;

  final List<String> _bootLines = [
    'INITIALIZING BIHAR FLOOD COMMAND CENTER...',
    'CONNECTING TO CWC LIVE FEED...',
    'LOADING 38 DISTRICT NODES...',
    'SYNCING KOSI · GANDAK · GANGA · BAGMATI...',
    'BSDMA ADVISORY FEED ACTIVE...',
    'IMD PRECIPITATION DATA RECEIVED...',
    'NDMA ALERT CHANNEL OPEN...',
    'ALL SYSTEMS OPERATIONAL · BIHAR',
  ];
  int _lineIdx = 0;
  String _currentLine = '';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ring = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();

    _boot = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..forward();

    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeOut);

    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    for (int i = 0; i < _bootLines.length; i++) {
      await Future.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;
      setState(() {
        _lineIdx = i;
        _currentLine = _bootLines[i];
      });
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 200));
    _fade.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(HomeScreen.route);
  }

  @override
  void dispose() {
    _ring.dispose();
    _boot.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: Stack(
        children: [
          // Animated rings background
          Center(
            child: AnimatedBuilder(
              animation: _ring,
              builder: (_, __) {
                return CustomPaint(
                  size: const Size(300, 300),
                  painter: _RingPainter(_ring.value),
                );
              },
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppPalette.cyan.withValues(alpha: 0.20),
                            AppPalette.abyss2,
                          ]),
                          border: Border.all(
                              color: AppPalette.cyan.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: const Icon(Icons.water_damage_rounded,
                            color: AppPalette.cyan, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('EQUINOX',
                          style: TextStyle(
                            color: AppPalette.textWhite,
                            fontSize: 28, fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          )),
                      const SizedBox(height: 4),
                      Text('BIHAR FLOOD COMMAND CENTER',
                          style: TextStyle(
                            color: AppPalette.cyan.withValues(alpha: 0.85),
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          )),
                      const SizedBox(height: 4),
                      Container(
                        width: 120, height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppPalette.cyan.withValues(alpha: 0),
                            AppPalette.cyan.withValues(alpha: 0.60),
                            AppPalette.cyan.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('BSDMA · CWC · IMD · NDMA',
                          style: TextStyle(
                            color: AppPalette.textDim.withValues(alpha: 0.6),
                            fontSize: 8, letterSpacing: 2,
                          )),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // Boot log
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.abyss2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppPalette.cyan.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _done
                                  ? AppPalette.safe
                                  : AppPalette.cyan.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _done ? 'BOOT COMPLETE' : 'BOOTING SYSTEM...',
                            style: TextStyle(
                              color: _done ? AppPalette.safe : AppPalette.cyan,
                              fontSize: 9, fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Spacer(),
                          Text('${_lineIdx + 1}/${_bootLines.length}',
                              style: const TextStyle(
                                color: AppPalette.textDim, fontSize: 9)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      AnimatedBuilder(
                        animation: _boot,
                        builder: (_, __) {
                          final pct = (_lineIdx + 1) / _bootLines.length;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: AppPalette.abyss4,
                                  valueColor: AlwaysStoppedAnimation(
                                      _done ? AppPalette.safe : AppPalette.cyan),
                                  minHeight: 2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(_currentLine,
                                  style: TextStyle(
                                    color: _done
                                        ? AppPalette.safe
                                        : AppPalette.textGrey,
                                    fontSize: 9.5, height: 1.4,
                                    fontWeight: _done
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  )),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Version
                Text('v3.0 · BIHAR EDITION · 38 DISTRICTS',
                    style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 8.5,
                      letterSpacing: 1.5,
                    )),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Fade-to-black transition
          FadeTransition(
            opacity: _fadeAnim,
            child: Container(color: AppPalette.abyss0),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radii = [60.0, 100.0, 140.0];
    for (int i = 0; i < radii.length; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final alpha = (math.sin(phase * math.pi) * 0.18).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radii[i], paint);
    }
    // Scan line
    final angle = t * 2 * math.pi;
    final scanPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.8,
        endAngle: angle,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0),
          const Color(0xFF00E5FF).withValues(alpha: 0.25),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 140))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 140, scanPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
