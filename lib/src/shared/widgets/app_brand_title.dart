import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// How far the wordmark rides above the mark's foot. Small enough to still read
/// as one lockup, big enough to stop the word looking like it is sinking.
const _baselineLift = 2.0;

/// The brand mark plus the "bookat" wordmark, sized for an [AppBar] title.
///
/// Both halves are painted in [AppColors.brand] — the logo's own blue — rather
/// than the palette's primary, so the mark and the word are always the same
/// colour.
///
/// The two are locked together as a lockup: the foot of the mark sits exactly on
/// the wordmark's baseline. Centring them instead leaves the word floating above
/// the mark's visual mass, because the logo's weight is all in the lower bowl.
class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({this.logoSize = 30, this.textStyle, super.key});

  /// Height of the mark. Its width follows the artwork's aspect ratio.
  final double logoSize;

  /// Defaults to `titleLarge`, which suits an app bar. Auth screens pass a
  /// larger style to match their bigger logo.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = (textStyle ?? textTheme.titleLarge)?.copyWith(
      color: AppColors.brand,
      fontWeight: FontWeight.w900,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Padding the mark by the font's descent drops its foot from the bottom
        // of the text box onto the baseline itself.
        Padding(
          padding: EdgeInsets.only(bottom: _descentOf(context, style)),
          child: Image.asset(
            AppImages.brandLogo,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              AppMaterialIcons.brand,
              color: AppColors.brand,
              size: logoSize,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        // A hair of lift off the baseline — optically the word sits better a
        // touch above the mark's foot than dead level with it.
        Padding(
          padding: const EdgeInsets.only(bottom: _baselineLift),
          child: Text(AppStrings.appName, style: style),
        ),
      ],
    );
  }

  /// Space between the wordmark's baseline and the bottom of its text box.
  /// Measured from the real font metrics so it stays correct at any size, and
  /// if the app ever swaps typeface.
  double _descentOf(BuildContext context, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: AppStrings.appName, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();

    final baseline =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final descent = painter.height - baseline;
    painter.dispose();

    return descent;
  }
}
