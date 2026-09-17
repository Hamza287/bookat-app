import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/core/constants/constants.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/presentation/widgets/business_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const venueTheme = BusinessTheme(
    primaryColor: '#ef4444',
    lightBackground: '#fffbeb',
    lightSurface: '#ffffff',
    lightText: '#1c1917',
    darkBackground: '#0c0a09',
    darkSurface: '#1c1917',
    darkText: '#fafaf9',
  );

  group('venuePalette', () {
    test('maps the owner-controlled colours for light mode', () {
      final palette = venuePalette(venueTheme, Brightness.light);

      expect(palette.primary, const Color(0xFFEF4444));
      expect(palette.background, const Color(0xFFFFFBEB));
      expect(palette.surface, const Color(0xFFFFFFFF));
      expect(palette.textPrimary, const Color(0xFF1C1917));
    });

    test('uses the dark set for dark mode', () {
      final palette = venuePalette(venueTheme, Brightness.dark);

      expect(palette.background, const Color(0xFF0C0A09));
      expect(palette.surface, const Color(0xFF1C1917));
      expect(palette.textPrimary, const Color(0xFFFAFAF9));
      // Primary is brand-wide, so it is shared across both modes.
      expect(palette.primary, const Color(0xFFEF4444));
    });

    test('picks a legible label colour for light and dark brand colours', () {
      final onLight = venuePalette(
        venueTheme.copyWith(primaryColor: '#fde047'),
        Brightness.light,
      );
      final onDark = venuePalette(
        venueTheme.copyWith(primaryColor: '#1e1b4b'),
        Brightness.light,
      );

      expect(onLight.textOnPrimary, const Color(0xFF0F172A));
      expect(onDark.textOnPrimary, const Color(0xFFFFFFFF));
    });

    test('falls back to app branding when the hex is malformed', () {
      final palette = venuePalette(
        const BusinessTheme(
          primaryColor: 'not-a-colour',
          lightBackground: '#12',
          lightSurface: '',
          lightText: '#zzzzzz',
          darkBackground: '',
          darkSurface: '',
          darkText: '',
        ),
        Brightness.light,
      );

      expect(palette.primary, AppPalette.light.primary);
      expect(palette.background, AppPalette.light.background);
      expect(palette.surface, AppPalette.light.surface);
      expect(palette.textPrimary, AppPalette.light.textPrimary);
    });

    test('accepts hex with and without the leading hash', () {
      final withHash = venuePalette(venueTheme, Brightness.light);
      final without = venuePalette(
        venueTheme.copyWith(primaryColor: 'ef4444'),
        Brightness.light,
      );

      expect(without.primary, withHash.primary);
    });
  });

  testWidgets('BusinessThemeScope re-skins its subtree', (tester) async {
    late AppPalette outer;
    late AppPalette inner;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            outer = context.appColors;
            return BusinessThemeScope(
              theme: venueTheme,
              child: Builder(
                builder: (context) {
                  inner = context.appColors;
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(outer.primary, AppPalette.light.primary);
    expect(inner.primary, const Color(0xFFEF4444));
    expect(inner.background, const Color(0xFFFFFBEB));
  });
}
