import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/business.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({required this.business, super.key});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final businessInitial = business.name.trim().isEmpty
        ? AppStrings.appName.substring(0, 1)
        : business.name.trim().substring(0, 1).toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  child: Text(
                    businessInitial,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        business.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (business.description != null &&
                business.description!.trim().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                business.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: [
                AppInfoPill(
                  icon: AppMaterialIcons.category,
                  label: business.settings.category,
                ),
                AppInfoPill(
                  icon: AppMaterialIcons.location,
                  label: business.city,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    business.settings.currency,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AppButton(
                  label: AppStrings.viewSlots,
                  icon: AppMaterialIcons.calendar,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
