import 'package:flutter/material.dart';

import '../core/constants/constants.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return _build(Brightness.light, AppPalette.light);
  }

  static ThemeData dark() {
    return _build(Brightness.dark, AppPalette.dark);
  }

  /// Builds the app's theme around a caller-supplied palette. Used to re-skin a
  /// subtree in a business's own booking-page colours.
  static ThemeData fromPalette(Brightness brightness, AppPalette palette) {
    return _build(brightness, palette);
  }

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    const buttonMinimumSize = Size(0, AppDimensions.buttonHeight);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: brightness,
        primary: palette.primary,
        error: palette.error,
        surface: palette.surface,
      ),
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinimumSize,
          backgroundColor: palette.primary,
          foregroundColor: palette.textOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinimumSize,
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        labelStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: AppDimensions.spacingLg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          borderSide: BorderSide(color: palette.error, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.error,
        contentTextStyle: TextStyle(color: palette.textOnPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
