import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../domain/entities/business_category.dart';
import '../providers/booking_providers.dart';

class CategoryFilter extends ConsumerWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(businessCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final colors = context.appColors;

    // A category fetch failing (or still loading) shouldn't block browsing —
    // fall back to just the "All" chip rather than erroring the whole row.
    final chips = categories.maybeWhen(
      data: (data) => data,
      orElse: () => const <BusinessCategory>[],
    );

    return SizedBox(
      height: AppDimensions.categoryFilterHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(
          width: AppDimensions.spacingSm,
        ),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final value = isAll ? '' : chips[index - 1].value;
          final label = isAll ? AppStrings.categoryAll : chips[index - 1].label;
          final isSelected = value == selectedCategory;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              isAll ? AppMaterialIcons.all : _iconFor(value),
              size: 18,
              color: isSelected ? colors.textOnPrimary : colors.primary,
            ),
            label: Text(label),
            labelStyle: TextStyle(
              color: isSelected ? colors.textOnPrimary : colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: colors.surface,
            selectedColor: colors.primary,
            side: BorderSide(
              color: isSelected ? colors.primary : colors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            onSelected: (_) {
              ref.read(selectedCategoryProvider.notifier).state = value;
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String value) {
    return switch (value.toUpperCase()) {
      'SALON' || 'BEAUTY' => AppMaterialIcons.beauty,
      'CLINIC' || 'HEALTH' || 'HOSPITAL' => AppMaterialIcons.health,
      'REPAIR' || 'AUTO' => AppMaterialIcons.repair,
      'STUDIO' || 'CREATIVE' || 'PHOTOGRAPHY' => AppMaterialIcons.creative,
      _ => AppMaterialIcons.category,
    };
  }
}
