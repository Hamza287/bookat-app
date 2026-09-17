import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/business.dart';
import 'business_image.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    required this.business,
    this.onTap,
    super.key,
  });

  final Business business;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BusinessCoverImage(
                  coverUrl: business.coverUrl,
                  logoUrl: business.logoUrl,
                  fallbackText: business.name,
                  height: 148,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Row(
                            children: [
                              Icon(
                                AppMaterialIcons.location,
                                color: colors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: AppDimensions.spacingXs),
                              Expanded(
                                child: Text(
                                  business.city.isEmpty
                                      ? business.address
                                      : business.city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
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
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingLg),
                Row(
                  children: [
                    const Spacer(),
                    AppButton(
                      label: AppStrings.viewSlots,
                      icon: AppMaterialIcons.calendar,
                      onPressed: onTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
