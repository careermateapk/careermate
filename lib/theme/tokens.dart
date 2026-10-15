import 'package:flutter/material.dart';

/// Design tokens taken from the CareerMate mockups.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0B1B3F);
  static const navySoft = Color(0xFF1A2850);
  static const blue = Color(0xFF2F6BFF);
  static const blueDark = Color(0xFF1E4FD6);
  static const blueTint = Color(0xFFE5EDFF);

  static const green = Color(0xFF16A34A);
  static const greenText = Color(0xFF15803D);
  static const greenTint = Color(0xFFECFDF3);

  static const amber = Color(0xFFD97706);
  static const amberText = Color(0xFF92400E);
  static const amberTint = Color(0xFFFEF3C7);

  static const red = Color(0xFFDC2626);
  static const redText = Color(0xFFB91C1C);
  static const redTint = Color(0xFFFEE2E2);

  static const surface = Color(0xFFF4F6FB);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8ECF5);
  static const border = Color(0xFFD5DBE8);
  static const textMuted = Color(0xFF5B6478);
  static const textBody = Color(0xFF4A5368);

  // Dark theme
  static const darkBg = Color(0xFF07122B);
  static const darkCard = Color(0xFF111F42);
  static const darkLine = Color(0xFF22325C);
  static const darkTextMuted = Color(0xFFA9B6D6);
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 26.0;
}

class AppSpace {
  AppSpace._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

class AppMotion {
  AppMotion._();
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 450);
  static const slow = Duration(milliseconds: 900);
  static const curve = Cubic(0.2, 0.8, 0.2, 1);
}
