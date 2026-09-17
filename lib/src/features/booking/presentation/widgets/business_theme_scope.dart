import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/constants.dart';
import '../../domain/entities/business.dart';

/// Re-skins its subtree in a business's booking-page colours.
///
/// Owners choose these in Business Settings; customers see them when they open
/// that venue to book. Only the colours the owner actually controls are taken
/// from [BusinessTheme] — the rest of the palette is derived so contrast and
/// component styling stay coherent whatever they pick.
class BusinessThemeScope extends StatelessWidget {
  const BusinessThemeScope({
    required this.theme,
    required this.child,
    super.key,
  });

  final BusinessTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final palette = venuePalette(theme, brightness);

    return Theme(
      data: AppTheme.fromPalette(brightness, palette),
      child: child,
    );
  }
}

/// Maps the seven owner-controlled colours onto the full [AppPalette].
///
/// Falls back to the app palette for any value that cannot be parsed, so a
/// malformed hex from the API degrades to Bookat branding rather than an
/// unreadable screen.
AppPalette venuePalette(BusinessTheme theme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = isDark ? AppPalette.dark : AppPalette.light;

  final primary = _parseHex(theme.primaryColor, base.primary);
  final background = _parseHex(
    isDark ? theme.darkBackground : theme.lightBackground,
    base.background,
  );
  final surface = _parseHex(
    isDark ? theme.darkSurface : theme.lightSurface,
    base.surface,
  );
  final textPrimary = _parseHex(
    isDark ? theme.darkText : theme.lightText,
    base.textPrimary,
  );

  return base.copyWith(
    primary: primary,
    primaryDark: _shade(primary, isDark ? 0.18 : -0.18),
    primaryLight: Color.alphaBlend(primary.withValues(alpha: 0.14), surface),
    background: background,
    surface: surface,
    surfaceMuted: Color.alphaBlend(
      textPrimary.withValues(alpha: 0.05),
      surface,
    ),
    textPrimary: textPrimary,
    textSecondary: Color.alphaBlend(
      textPrimary.withValues(alpha: 0.62),
      surface,
    ),
    // Chosen against the owner's primary so button labels stay legible even if
    // they pick a very light or very dark brand colour.
    textOnPrimary: _onColor(primary),
    border: Color.alphaBlend(textPrimary.withValues(alpha: 0.14), surface),
  );
}

Color _parseHex(String hex, Color fallback) {
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) {
    value = 'ff$value';
  }
  if (value.length != 8) {
    return fallback;
  }

  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

/// Lightens for [amount] > 0, darkens for [amount] < 0.
Color _shade(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color _onColor(Color background) {
  return background.computeLuminance() > 0.5
      ? const Color(0xFF0F172A)
      : const Color(0xFFFFFFFF);
}
