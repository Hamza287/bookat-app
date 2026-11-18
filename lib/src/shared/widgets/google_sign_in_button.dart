import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

/// "Continue with Google" — a full-width secondary action for the auth screens.
///
/// Deliberately quieter than the primary email button next to it: a surface
/// fill with a hairline border, so the two never compete for the same tap.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Replaces the mark with a spinner while the picker and the token exchange
  /// are in flight, keeping the button's height fixed.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.6,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: isLoading
                      ? CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colors.primary),
                        )
                      : const GoogleMark(),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                // Flexible so a long label ellipsises rather than overflowing
                // the row on a narrow phone.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled rule, for separating the email form from the Google button.
class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(child: Divider(color: colors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
          ),
        ),
        Expanded(child: Divider(color: colors.border, height: 1)),
      ],
    );
  }
}

/// Google's four-colour "G", drawn rather than shipped as an asset so it stays
/// crisp at any size and in either theme.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _GoogleMarkPainter());
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  // Google's brand colours.
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  // Proportions taken from the official 48x48 mark: a ring of four arcs with
  // the crossbar reaching in from the right.
  static const _strokeRatio = 0.2117;
  static const _radiusRatio = 0.3525;
  static const _barRightRatio = 0.4317;
  static const _barTopRatio = 0.0833;
  static const _barBottomRatio = 0.0940;

  /// Arc spans, in degrees clockwise from three o'clock, taken from the
  /// official 48x48 mark.
  ///
  /// The gap runs from the end of red (312.1) round to the start of blue
  /// (361.4): that upper-right opening is the G's mouth, and the crossbar
  /// reaches in beneath it. Putting the gap at the *lower* right instead
  /// renders the mark upside down.
  static const _segments = <(double, double, Color)>[
    (1.4, 47.5, _blue), // lower right, running down from the crossbar
    (48.9, 104.4, _green), // bottom
    (153.3, 53.4, _yellow), // left
    (206.7, 105.4, _red), // top
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final extent = math.min(size.width, size.height);
    if (extent <= 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final stroke = extent * _strokeRatio;
    final rect = Rect.fromCircle(center: center, radius: extent * _radiusRatio);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      // Butt caps so neighbouring segments meet without overlapping tints.
      ..strokeCap = StrokeCap.butt;

    for (final (start, sweep, color) in _segments) {
      canvas.drawArc(
        rect,
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        arcPaint..color = color,
      );
    }

    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - extent * _barTopRatio,
        center.dx + extent * _barRightRatio,
        center.dy + extent * _barBottomRatio,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
