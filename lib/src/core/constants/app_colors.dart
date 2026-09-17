import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  /// The blue of the bookat mark itself, sampled from
  /// `assets/images/bookat_logo.png`. Deliberately not part of [AppPalette]:
  /// the wordmark must stay identical to the artwork beside it in every theme,
  /// and must not drift when a business theme overrides the palette.
  static const brand = Color(0xFF0045E0);

  static const primary = Color(0xFF1F5EFF);
  static const primaryDark = Color(0xFF1747C8);
  static const primaryLight = Color(0xFFEAF1FF);
  static const secondary = Color(0xFF0EA5E9);
  static const accent = Color(0xFF22C55E);

  static const background = Color(0xFFF5F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F4FA);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const shadow = Color(0x120F172A);
  static const error = Color(0xFFB42318);

  static const darkPrimary = Color(0xFF8DB1FF);
  static const darkPrimaryDark = Color(0xFFD7E4FF);
  static const darkPrimaryLight = Color(0xFF17315F);
  static const darkSecondary = Color(0xFF67D4FF);
  static const darkAccent = Color(0xFF5EE28E);

  static const darkBackground = Color(0xFF0B1020);
  static const darkSurface = Color(0xFF121A2C);
  static const darkSurfaceMuted = Color(0xFF1B263B);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFB6C2D2);
  static const darkTextOnPrimary = Color(0xFF07101F);
  static const darkBorder = Color(0xFF26344C);
  static const darkShadow = Color(0x66000000);
  static const darkError = Color(0xFFFF8A80);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.border,
    required this.shadow,
    required this.error,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color border;
  final Color shadow;
  final Color error;

  static const light = AppPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    secondary: AppColors.secondary,
    accent: AppColors.accent,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textOnPrimary: AppColors.textOnPrimary,
    border: AppColors.border,
    shadow: AppColors.shadow,
    error: AppColors.error,
  );

  static const dark = AppPalette(
    primary: AppColors.darkPrimary,
    primaryDark: AppColors.darkPrimaryDark,
    primaryLight: AppColors.darkPrimaryLight,
    secondary: AppColors.darkSecondary,
    accent: AppColors.darkAccent,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceMuted: AppColors.darkSurfaceMuted,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textOnPrimary: AppColors.darkTextOnPrimary,
    border: AppColors.darkBorder,
    shadow: AppColors.darkShadow,
    error: AppColors.darkError,
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnPrimary,
    Color? border,
    Color? shadow,
    Color? error,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      error: error ?? this.error,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appColors => Theme.of(this).extension<AppPalette>()!;
}
