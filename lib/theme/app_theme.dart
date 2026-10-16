import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  /// Headings use Sora, body text uses Manrope.
  static TextStyle display(BuildContext context, {double size = 24, Color? color}) =>
      GoogleFonts.getFont('Sora', fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.2);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: b,
    ).copyWith(
      primary: AppColors.blue,
      onPrimary: Colors.white,
      secondary: AppColors.navy,
      error: AppColors.red,
      surface: isDark ? AppColors.darkCard : AppColors.card,
      onSurface: isDark ? Colors.white : AppColors.navy,
      outline: isDark ? AppColors.darkLine : AppColors.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final text = _manrope(base.textTheme).apply(
      bodyColor: isDark ? Colors.white : AppColors.navy,
      displayColor: isDark ? Colors.white : AppColors.navy,
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: isDark ? AppColors.darkLine : AppColors.border, width: 1.5),
    );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: isDark ? Colors.white : AppColors.navy,
        titleTextStyle: GoogleFonts.getFont('Sora',
            fontSize: 19, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.navy),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: AppColors.blue, width: 2)),
        errorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
        focusedErrorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: AppColors.red, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.getFont('Manrope', fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: isDark ? Colors.white : AppColors.navy,
          side: BorderSide(color: isDark ? AppColors.darkLine : AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.getFont('Manrope', fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFFF1F5FF) : AppColors.navy,
        contentTextStyle: GoogleFonts.getFont('Manrope',
            fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? AppColors.navy : Colors.white),
        actionTextColor: isDark ? AppColors.blue : const Color(0xFF9DBBFF),
        actionBackgroundColor: isDark ? AppColors.blue.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      dividerTheme: DividerThemeData(color: isDark ? AppColors.darkLine : AppColors.line, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }

  /// Applies Manrope to every text style while keeping each style's
  /// size and weight (each weight is loaded on demand).
  static TextTheme _manrope(TextTheme t) {
    TextStyle? f(TextStyle? s) => s == null ? null : GoogleFonts.getFont('Manrope', textStyle: s);
    return t.copyWith(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }
}
