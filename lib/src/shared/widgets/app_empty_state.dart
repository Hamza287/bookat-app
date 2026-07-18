import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.message,
    this.icon,
    super.key,
  });

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 36, color: AppColors.textSecondary),
              const SizedBox(height: AppDimensions.spacingMd),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
