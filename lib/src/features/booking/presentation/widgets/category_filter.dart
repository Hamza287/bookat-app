import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/category_item.dart';

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({super.key});

  static const _categories = [
    CategoryItem(label: AppStrings.categoryAll, icon: AppMaterialIcons.all),
    CategoryItem(
      label: AppStrings.categoryHealth,
      icon: AppMaterialIcons.health,
    ),
    CategoryItem(
      label: AppStrings.categoryBeauty,
      icon: AppMaterialIcons.beauty,
    ),
    CategoryItem(
      label: AppStrings.categoryRepair,
      icon: AppMaterialIcons.repair,
    ),
    CategoryItem(
      label: AppStrings.categoryCreative,
      icon: AppMaterialIcons.creative,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.categoryFilterHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(
          width: AppDimensions.spacingSm,
        ),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = index == 0;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              category.icon,
              size: 18,
              color: isSelected ? AppColors.textOnPrimary : AppColors.primary,
            ),
            label: Text(category.label),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            onSelected: (_) {},
          );
        },
      ),
    );
  }
}
