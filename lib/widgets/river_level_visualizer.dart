import 'dart:ui';

import 'package:flutter/material.dart';

class RiverLevelVisualizer extends StatelessWidget {
  final String city;
  final String river;
  final double currentLevel;
  final double safeLevel;
  final double warningLevel;
  final double dangerLevel;
  final String trend;

  const RiverLevelVisualizer({
    super.key,
    required this.city,
    required this.river,
    required this.currentLevel,
    required this.safeLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.trend,
  });

  double get _ratio {
    final range = (dangerLevel - safeLevel).abs();
    if (range <= 0) return 0;
    return ((currentLevel - safeLevel) / range).clamp(0, 1);
  }

  Color get _levelColor {
    if (currentLevel >= dangerLevel) return const Color(0xFF8B0000);
    if (currentLevel >= warningLevel) return const Color(0xFFEF4444);
    if (currentLevel >= safeLevel + ((dangerLevel - safeLevel) * 0.5)) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF34C759);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 90,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF8B0000),
                            Color(0xFFEF4444),
                            Color(0xFFF59E0B),
                            Color(0xFF34C759),
                          ],
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      height: 90 * _ratio,
                      width: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _levelColor.withOpacity(0.9),
                        boxShadow: [
                          BoxShadow(
                            color: _levelColor.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      river,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${currentLevel.toStringAsFixed(2)} m',
                          style: TextStyle(
                            color: _levelColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          trend.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                'D ${dangerLevel.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
