import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/service.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, super.key});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.companyName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(AppMaterialIcons.star, color: colorScheme.tertiary),
                const SizedBox(width: AppDimensions.spacingXs),
                Text(service.rating.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(service.title, style: textTheme.bodyLarge),
            const SizedBox(height: AppDimensions.spacingMd),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: [
                AppInfoPill(
                  icon: AppMaterialIcons.category,
                  label: service.category,
                ),
                AppInfoPill(
                  icon: AppMaterialIcons.location,
                  label: service.location,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.priceLabel,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                AppButton(
                  label: AppStrings.book,
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
