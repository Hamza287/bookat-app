import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/core/constants/constants.dart';
import 'package:bookat/src/shared/widgets/app_brand_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mark and the wordmark form one lockup: the foot of the "b" lands just
/// below the wordmark's baseline, which rides a hair above it. Centring them
/// (the old behaviour) left the word floating near the top of the logo, because
/// the logo's visual mass is all in its lower bowl.
const _baselineLift = 2.0;
void main() {
  Widget harness(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  /// Distance from the top of the row to the wordmark's alphabetic baseline.
  double baselineY(WidgetTester tester) {
    final textBox = tester.getRect(find.text(AppStrings.appName));
    final painter = TextPainter(
      text: TextSpan(
        text: AppStrings.appName,
        style: tester.widget<Text>(find.text(AppStrings.appName)).style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.dispose();
    return textBox.top + baseline;
  }

  for (final logoSize in const [30.0, 42.0, 46.0]) {
    testWidgets('the wordmark rides just above the mark foot at $logoSize',
        (tester) async {
      await tester.pumpWidget(harness(AppBrandTitle(logoSize: logoSize)));
      await tester.pumpAndSettle();

      final logoBottom = tester.getRect(find.byType(Image)).bottom;

      // The baseline sits exactly `_baselineLift` above the mark's foot — the
      // lockup holds at every size rather than drifting with the font.
      expect(
        logoBottom - baselineY(tester),
        moreOrLessEquals(_baselineLift, epsilon: 0.5),
      );
    });
  }

  testWidgets('the mark keeps the artwork aspect ratio, with no dead margin',
      (tester) async {
    await tester.pumpWidget(harness(const AppBrandTitle(logoSize: 40)));
    await tester.pumpAndSettle();

    final logo = tester.getRect(find.byType(Image));

    expect(logo.height, 40);
    // 310x512 artwork — a square box would pad ~20% dead space either side and
    // push the wordmark away from the mark.
    expect(logo.width / logo.height, moreOrLessEquals(310 / 512, epsilon: 0.02));
  });

  testWidgets('mark and wordmark share the brand colour', (tester) async {
    await tester.pumpWidget(harness(const AppBrandTitle()));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(AppStrings.appName));

    expect(text.style?.color, AppColors.brand);
  });
}
