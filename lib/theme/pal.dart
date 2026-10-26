import 'package:flutter/material.dart';

/// Neumorphic palette. Mirrors the CSS variables of the HTML design.
class Pal {
  final bool dark;
  final bool psits;
  const Pal({required this.dark, this.psits = false});

  static const red = Color(0xFFE04B4B);

  Color get bg => dark ? const Color(0xFF16241C) : const Color(0xFFE4EEE7);
  Color get tx => dark ? const Color(0xFFE6F3E9) : const Color(0xFF1C3626);
  Color get mut => dark ? const Color(0xFF8AA592) : const Color(0xFF667D6D);
  Color get shL => dark ? const Color(0xFF20362A) : Colors.white;
  Color get shD => dark ? const Color(0xFF0C1510) : const Color(0xFFB7C8BB);
  Color get g => psits ? const Color(0xFF2F6FE4) : const Color(0xFF1FA443);
  Color get gDark => psits ? const Color(0xFF1B4DB0) : const Color(0xFF168A35);
  Color get gLight => psits ? const Color(0xFF5A90F0) : const Color(0xFF2AC351);
  Color get g2 => psits
      ? (dark ? const Color(0xFF1B2C4A) : const Color(0xFFD9E4F7))
      : (dark ? const Color(0xFF1D3326) : const Color(0xFFD6E7DB));
  Color get line => dark ? const Color(0x12FFFFFF) : const Color(0x1F3C5A46);

  List<BoxShadow> get raise => [
        BoxShadow(color: shD, offset: const Offset(6, 6), blurRadius: 14),
        BoxShadow(color: shL, offset: const Offset(-6, -6), blurRadius: 14),
      ];
  List<BoxShadow> get raiseSm => [
        BoxShadow(color: shD, offset: const Offset(3, 3), blurRadius: 7),
        BoxShadow(color: shL, offset: const Offset(-3, -3), blurRadius: 7),
      ];

  /// Flutter has no inset shadow, so a soft diagonal gradient imitates it.
  BoxDecoration inset([double r = 14]) => BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shD.withOpacity(.65), bg, shL.withOpacity(.75)],
          stops: const [0, .55, 1],
        ),
      );

  LinearGradient get priGrad => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gLight, gDark],
      );
}
