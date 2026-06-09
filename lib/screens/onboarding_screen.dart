// lib/screens/onboarding_screen.dart
// OpsFlood — OnboardingScreen
//
// 4-page swipe onboarding shown only on first launch.
// After "Get Started" it sets onboardingProvider = true
// and navigates to MainShell.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_provider.dart';
import '../theme/river_theme.dart';
import 'main_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  static const String route = '/onboarding';
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _page = PageController();
  int _current = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.flood_rounded,
      color: Color(0xFF00BFFF),
      title: 'Real-Time Flood
Intelligence',
      subtitle:
          'Live data from 32 Bihar WRD gauge stations, GloFAS discharge and IMD rainfall — updated every 5 minutes.',
    ),
    _OnboardPage(
      icon: Icons.map_rounded,
      color: Color(0xFF7C3AED),
      title: 'Interactive
River Map',
      subtitle:
          'Colour-coded risk pins across Bihar rivers. Tap any station to see current level vs danger threshold instantly.',
    ),
    _OnboardPage(
      icon: Icons.psychology_rounded,
      color: Color(0xFF10B981),
      title: 'ML Flood
Prediction',
      subtitle:
          'Enter river level + rainfall and get an instant AI risk assessment: Safe, Warning, Danger or Critical.',
    ),
    _OnboardPage(
      icon: Icons.sos_rounded,
      color: Color(0xFFEF4444),
      title: 'SOS &
Emergency Help',
      subtitle:
          'One-tap SOS calls NDRF / SDRF. Access helplines, evacuation guides and nearest relief camps instantly.',
    ),
  ];

  void _next() {
    HapticFeedback.selectionClick();
    if (_current < _pages.length - 1) {
      _page.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) {
      Navigator.pushReplacementNamed(context, MainShell.route);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final page = _pages[_current];
    final last = _current == _pages.length - 1;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [

            // ── Skip ────────────────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 13)),
              ),
            ),

            // ── PageView ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageContent(
                    page: _pages[i], t: t, isActive: i == _current),
              ),
            ),

            // ── Dots ────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width:  active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active ? page.color : t.stroke,
                  ),
                );
              }),
            ),

            const SizedBox(height: 28),

            // ── CTA Button ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: GestureDetector(
                onTap: _next,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        page.color,
                        Color.lerp(page.color, Colors.white, 0.18)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: page.color.withValues(alpha: 0.38),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      last ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Single page content ───────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  final RiverColors  t;
  final bool         isActive;
  const _PageContent(
      {required this.page, required this.t, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: isActive ? 1.0 : 0.7),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: page.color.withValues(alpha: 0.10),
                border: Border.all(
                    color: page.color.withValues(alpha: 0.35), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: page.color.withValues(alpha: 0.25),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: Icon(page.icon, color: page.color, size: 64),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ───────────────────────────────────────────────────────────────

class _OnboardPage {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
