import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextStyle _t(
    double size,
    FontWeight weight,
    Color color, {
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricBlue,
        onPrimary: Colors.white,
        secondary: AppColors.info,
        onSecondary: AppColors.bgDark,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textDisabled,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.separator,
        thickness: 0.5,
        space: 0.5,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.electricBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgCard,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      textTheme: TextTheme(
        displayLarge: _t(56, FontWeight.w700, AppColors.textPrimary),
        displayMedium: _t(44, FontWeight.w700, AppColors.textPrimary),
        displaySmall: _t(34, FontWeight.w700, AppColors.textPrimary),
        headlineLarge: _t(32, FontWeight.w700, AppColors.textPrimary),
        headlineMedium: _t(26, FontWeight.w700, AppColors.textPrimary),
        headlineSmall: _t(22, FontWeight.w600, AppColors.textPrimary),
        titleLarge: _t(20, FontWeight.w600, AppColors.textPrimary),
        titleMedium: _t(17, FontWeight.w600, AppColors.textPrimary),
        titleSmall: _t(15, FontWeight.w500, AppColors.textSecondary),
        bodyLarge: _t(17, FontWeight.w400, AppColors.textPrimary, height: 1.5),
        bodyMedium: _t(15, FontWeight.w400, AppColors.textPrimary, height: 1.4),
        bodySmall: _t(
          13,
          FontWeight.w400,
          AppColors.textSecondary,
          height: 1.3,
        ),
        labelLarge: _t(15, FontWeight.w600, AppColors.textPrimary),
        labelMedium: _t(13, FontWeight.w500, AppColors.textSecondary),
        labelSmall: _t(12, FontWeight.w500, AppColors.textTertiary),
      ),
    );
  }
}
