// ─────────────────────────────────────────────────────────────────────────────
//  ShimmerLoader  —  Skeleton loading widgets matching EQUINOX-BR05 theme
//
//  Usage examples:
//    ShimmerLoader.card()                  // single card skeleton
//    ShimmerLoader.stationList(count: 5)   // list of station card skeletons
//    ShimmerLoader.statRow()               // horizontal stat row skeleton
//    ShimmerLoader.box(w: 120, h: 40)      // arbitrary sized box
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({super.key, required this.child});

  final Widget child;

  // ── Convenience factories ─────────────────────────────────────────────────
  static Widget box({double? w, double? h, double radius = 12}) =>
      ShimmerLoader(
        child: Container(
          width: w,
          height: h ?? 16,
          decoration: BoxDecoration(
            color: AppPalette.abyss3,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );

  static Widget card({double height = 110}) => ShimmerLoader(
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.abyss2,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppPalette.abyssStroke),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppPalette.abyss3,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          box(h: 14, w: 160),
                          const SizedBox(height: 6),
                          box(h: 11, w: 100),
                        ],
                      ),
                    ),
                    box(w: 60, h: 26, radius: 8),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    box(h: 11, w: 80),
                    const Spacer(),
                    box(h: 11, w: 60),
                    const Spacer(),
                    box(h: 11, w: 70),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  static Widget stationList({int count = 4}) => Column(
        children: List.generate(count, (_) => card()),
      );

  static Widget statRow({int count = 3}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: List.generate(
            count,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                height: 72,
                decoration: BoxDecoration(
                  color: AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.abyssStroke),
                ),
                child: ShimmerLoader(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        box(h: 20, w: 50),
                        const SizedBox(height: 6),
                        box(h: 10, w: 70),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            AppPalette.abyss2,
            AppPalette.abyss4,
            AppPalette.abyssStroke,
            AppPalette.abyss4,
            AppPalette.abyss2,
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          transform: _SlidingGradientTransform(_anim.value),
        ).createShader(bounds),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
}
