import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';
import '../services/api_service.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';

// FIX #1: RealTimeService.startPolling() is now called here in initState(),
//         AFTER runApp() has built the widget tree.  This guarantees that
//         the first notifyListeners() from _loadFallbackImmediately() has
//         at least one active listener and is not fired into a void.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo entrance
  late AnimationController _entranceCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _titleOpacity;
  late Animation<Offset>   _titleSlide;

  // Pulse ring
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseScale;
  late Animation<double>   _pulseOpacity;

  // Red sweep line
  late AnimationController _sweepCtrl;
  late Animation<double>   _sweepPos;

  // Status text fade
  late AnimationController _statusCtrl;
  late Animation<double>   _statusOpacity;

  String _statusText    = 'Initializing...';
  bool   _backendOnline = false;

  @override
  void initState() {
    super.initState();

    // ── Animation controllers ────────────────────────────────────────────────
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entranceCtrl, curve: const Interval(0.0, 0.4)));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entranceCtrl, curve: const Interval(0.4, 0.8)));
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseScale   = Tween<double>(begin: 1.0, end: 1.6).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeIn));

    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _sweepPos = Tween<double>(begin: -1.0, end: 1.0).animate(
        CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeInOut));

    _statusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _statusOpacity = CurvedAnimation(
        parent: _statusCtrl, curve: Curves.easeIn);

    _entranceCtrl.forward().then((_) {
      _sweepCtrl.forward();
      _statusCtrl.forward();
    });

    // ── FIX #1: Start polling here, after widget tree is live ────────────────
    _bootServices();
  }

  Future<void> _bootServices() async {
    // Start the real-time service NOW — widget tree is alive, listeners work.
    await RealTimeService().startPolling();
    await BackgroundService.init();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    _setStatus('Connecting to backend...');
    final health = await ApiService().checkHealth();
    _backendOnline =
        health['status'] != 'offline' && health['status'] != 'error';
    _setStatus(
        _backendOnline ? 'Systems online  ✅' : 'Backend waking up  ⏳');
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() => _statusText = s);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _sweepCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppPalette.carbon0,
      body: Stack(
        children: [
          // ── Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.9,
                colors: [
                  Color(0xFF300000),
                  AppPalette.carbon0,
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // ── Diagonal carbon-fibre grid (static)
          CustomPaint(
            size: size,
            painter: _CarbonGridPainter(),
          ),

          // ── Sweep line
          AnimatedBuilder(
            animation: _sweepCtrl,
            builder: (_, __) {
              final x = _sweepPos.value * size.width;
              return Positioned(
                left: x,
                top: 0,
                bottom: 0,
                width: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppPalette.ferrari.withOpacity(0),
                        AppPalette.ferrari.withOpacity(0.7),
                        AppPalette.ferrari.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with pulse ring
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _entranceCtrl, _pulseCtrl,
                  ]),
                  builder: (_, __) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // pulse ring
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppPalette.ferrari.withOpacity(
                                          _pulseOpacity.value),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // logo container
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0xFF5A0000),
                                      AppPalette.ferrari,
                                    ],
                                    stops: [0.0, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppPalette.ferrari
                                          .withOpacity(0.6),
                                      blurRadius: 32,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.water_drop,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Title
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleOpacity,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [
                              AppPalette.ferrari,
                              AppPalette.goldLight,
                              Colors.white,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ).createShader(bounds),
                          child: const Text(
                            'OpsFlood',
                            style: TextStyle(
                              fontSize:      44,
                              fontWeight:    FontWeight.w900,
                              color:         Colors.white,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'AI-POWERED FLOOD INTELLIGENCE',
                          style: TextStyle(
                            fontSize:      11,
                            fontWeight:    FontWeight.w700,
                            color:         AppPalette.gold,
                            letterSpacing: 3.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 64),

                // Status
                FadeTransition(
                  opacity: _statusOpacity,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _backendOnline
                                ? AppPalette.safe
                                : AppPalette.ferrari,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color:         AppPalette.textGrey,
                          fontSize:      13,
                          fontWeight:    FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom version tag
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v2.1  •  SCUDERIA BUILD',
                style: TextStyle(
                  color:         AppPalette.ferrari.withOpacity(0.5),
                  fontSize:      10,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carbon fibre grid painter ─────────────────────────────────────────────────
class _CarbonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
      canvas.drawLine(Offset(i, 0), Offset(i - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_CarbonGridPainter old) => false;
}
