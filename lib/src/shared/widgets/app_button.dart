import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';
enum AppButtonType { filled, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = AppButtonType.filled,
    this.isExpanded = false,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final bool isExpanded;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                type == AppButtonType.filled
                    ? colors.textOnPrimary
                    : colors.primary,
              ),
            ),
          )
        : icon == null
        ? Text(label, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: AppDimensions.spacingSm),
              // Flexible so a long label ellipsises instead of overflowing the
              // button when the parent is narrow.
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    final button = switch (type) {
      AppButtonType.filled => FilledButton(
          onPressed: onPressed,
          child: child,
        ),
      AppButtonType.outlined => OutlinedButton(
          onPressed: onPressed,
          child: child,
        ),
      AppButtonType.text => TextButton(
          onPressed: onPressed,
          child: child,
        ),
    };

    if (!isExpanded) {
      return button;
    }

    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }
}
