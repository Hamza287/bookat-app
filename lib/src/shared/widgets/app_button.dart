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
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(label),
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
