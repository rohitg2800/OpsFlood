import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  OpsFlood River Theme  –  Day (Light) & Night (Dark)
// ─────────────────────────────────────────────

/// Custom semantic river colours exposed to every widget via [RiverColors.of]
class RiverColors extends ThemeExtension<RiverColors> {
  const RiverColors({
    required this.riverNormal,
    required this.riverWarning,
    required this.riverDanger,
    required this.riverCritical,
    required this.riverSurface,
    required this.riverGlow,
    required this.cardBg,
    required this.chipBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.sparklineColor,
  });

  final Color riverNormal;
  final Color riverWarning;
  final Color riverDanger;
  final Color riverCritical;
  final Color riverSurface;
  final Color riverGlow;
  final Color cardBg;
  final Color chipBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color sparklineColor;

  static RiverColors of(BuildContext context) =>
      Theme.of(context).extension<RiverColors>() ?? _day;

  // Day (light) palette – river at noon, sapphire blue water
  static const RiverColors _day = RiverColors(
    riverNormal:   Color(0xFF0077B6),
    riverWarning:  Color(0xFFF59E0B),
    riverDanger:   Color(0xFFEF4444),
    riverCritical: Color(0xFF8B0000),
    riverSurface:  Color(0xFFB8E4F9),
    riverGlow:     Color(0xFF0096C7),
    cardBg:        Color(0xFFFFFFFF),
    chipBg:        Color(0xFFE8F4FD),
    textPrimary:   Color(0xFF0A2240),
    textSecondary: Color(0xFF5F7A91),
    sparklineColor:Color(0xFF0096C7),
  );

  // Night (dark) palette – river at midnight, teal-cyan glow
  static const RiverColors _night = RiverColors(
    riverNormal:   Color(0xFF24C9E8),
    riverWarning:  Color(0xFFF59E0B),
    riverDanger:   Color(0xFFEF4444),
    riverCritical: Color(0xFF8B0000),
    riverSurface:  Color(0xFF0C3547),
    riverGlow:     Color(0xFF00B4D8),
    cardBg:        Color(0xFF0E1E2B),
    chipBg:        Color(0xFF142535),
    textPrimary:   Color(0xFFE0F2FA),
    textSecondary: Color(0xFF8BA8B8),
    sparklineColor:Color(0xFF24C9E8),
  );

  @override
  RiverColors copyWith({
    Color? riverNormal, Color? riverWarning, Color? riverDanger,
    Color? riverCritical, Color? riverSurface, Color? riverGlow,
    Color? cardBg, Color? chipBg, Color? textPrimary,
    Color? textSecondary, Color? sparklineColor,
  }) {
    return RiverColors(
      riverNormal:    riverNormal    ?? this.riverNormal,
      riverWarning:   riverWarning   ?? this.riverWarning,
      riverDanger:    riverDanger    ?? this.riverDanger,
      riverCritical:  riverCritical  ?? this.riverCritical,
      riverSurface:   riverSurface   ?? this.riverSurface,
      riverGlow:      riverGlow      ?? this.riverGlow,
      cardBg:         cardBg         ?? this.cardBg,
      chipBg:         chipBg         ?? this.chipBg,
      textPrimary:    textPrimary    ?? this.textPrimary,
      textSecondary:  textSecondary  ?? this.textSecondary,
      sparklineColor: sparklineColor ?? this.sparklineColor,
    );
  }

  @override
  RiverColors lerp(RiverColors? other, double t) {
    if (other == null) return this;
    return RiverColors(
      riverNormal:    Color.lerp(riverNormal,    other.riverNormal,    t)!,
      riverWarning:   Color.lerp(riverWarning,   other.riverWarning,   t)!,
      riverDanger:    Color.lerp(riverDanger,    other.riverDanger,    t)!,
      riverCritical:  Color.lerp(riverCritical,  other.riverCritical,  t)!,
      riverSurface:   Color.lerp(riverSurface,   other.riverSurface,   t)!,
      riverGlow:      Color.lerp(riverGlow,      other.riverGlow,      t)!,
      cardBg:         Color.lerp(cardBg,         other.cardBg,         t)!,
      chipBg:         Color.lerp(chipBg,         other.chipBg,         t)!,
      textPrimary:    Color.lerp(textPrimary,    other.textPrimary,    t)!,
      textSecondary:  Color.lerp(textSecondary,  other.textSecondary,  t)!,
      sparklineColor: Color.lerp(sparklineColor, other.sparklineColor, t)!,
    );
  }

  // ── Build full ThemeData
  static ThemeData lightTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C77),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        extensions: const <ThemeExtension<dynamic>>[_day],
      );

  static ThemeData darkTheme() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003D47),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF06101A),
        extensions: const <ThemeExtension<dynamic>>[_night],
      );
}
