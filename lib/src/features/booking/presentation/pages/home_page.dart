import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/business.dart';
import 'business_detail_page.dart';
import '../providers/booking_providers.dart';
import '../widgets/business_card.dart';
import '../widgets/category_filter.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _debounceDuration = Duration(milliseconds: 400);

  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;

    // The search box now hits `/businesses/search` on the server, so typing
    // is debounced to avoid firing a request per keystroke.
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(debouncedSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(debouncedSearchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    final filteredBusinesses = ref.watch(businessesProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: AppStrings.menuTooltip,
              icon: const Icon(Icons.menu_rounded),
            );
          },
        ),
        title: const AppBrandTitle(),
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: AppStrings.notificationsTooltip,
            icon: const Icon(AppMaterialIcons.notifications),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _HomeSearchHeader(
              controller: _searchController,
              searchQuery: searchQuery,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            Expanded(
              child: filteredBusinesses.when(
                loading: () => const _HomeLoadingSkeleton(),
                error: (error, _) => AppEmptyState(
                  message: error is Failure
                      ? error.message
                      : AppStrings.genericLoadError,
                ),
                data: (businesses) {
                  if (businesses.isEmpty) {
                    return const AppEmptyState(
                      message: AppStrings.noBusinessesFound,
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.spacingXl,
                      AppDimensions.spacingXl,
                      AppDimensions.spacingXl,
                      AppDimensions.spacing2xl,
                    ),
                    children: [
                      const CategoryFilter(),
                      const SizedBox(height: AppDimensions.spacing2xl),
                      Row(
                        children: [
                          Icon(
                            AppMaterialIcons.location,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Expanded(
                            child: Text(
                              AppStrings.featuredServices,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleLarge?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                      for (final business in businesses) ...[
                        BusinessCard(
                          business: business,
                          onTap: () => _openBusiness(context, business),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBusiness(BuildContext context, Business business) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BusinessDetailPage(business: business),
      ),
    );
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingXl,
        AppDimensions.spacingXl,
        AppDimensions.spacingXl,
        AppDimensions.spacing2xl,
      ),
      children: const [
        // Mirrors the real category filter, which also scrolls horizontally —
        // fixed-width placeholder chips can otherwise overflow on narrow
        // screens.
        SizedBox(
          height: AppDimensions.categoryFilterHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                AppShimmerBox(
                  width: 86,
                  height: AppDimensions.categoryFilterHeight,
                ),
                SizedBox(width: AppDimensions.spacingSm),
                AppShimmerBox(
                  width: 104,
                  height: AppDimensions.categoryFilterHeight,
                ),
                SizedBox(width: AppDimensions.spacingSm),
                AppShimmerBox(
                  width: 92,
                  height: AppDimensions.categoryFilterHeight,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppDimensions.spacing2xl),
        AppShimmerBox(width: 210, height: 28),
        SizedBox(height: AppDimensions.spacingLg),
        _BusinessCardSkeleton(),
        SizedBox(height: AppDimensions.spacingMd),
        _BusinessCardSkeleton(),
        SizedBox(height: AppDimensions.spacingMd),
        _BusinessCardSkeleton(),
      ],
    );
  }
}

class _BusinessCardSkeleton extends StatelessWidget {
  const _BusinessCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: colors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppShimmerBox(width: double.infinity, height: 148),
            SizedBox(height: AppDimensions.spacingLg),
            AppShimmerBox(width: 180, height: 22),
            SizedBox(height: AppDimensions.spacingSm),
            AppShimmerBox(width: 240, height: 16),
            SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                AppShimmerBox(width: 110, height: 34),
                SizedBox(width: AppDimensions.spacingSm),
                AppShimmerBox(width: 130, height: 34),
              ],
            ),
            SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                AppShimmerBox(width: 54, height: 18),
                Spacer(),
                AppShimmerBox(width: 118, height: AppDimensions.buttonHeight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchHeader extends StatelessWidget {
  const _HomeSearchHeader({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.primary),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingXl,
          AppDimensions.spacingLg,
          AppDimensions.spacingXl,
          AppDimensions.spacingLg,
        ),
        child: AppTextField(
          controller: controller,
          hintText: AppStrings.homeSearchHint,
          prefixIcon: AppMaterialIcons.search,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          suffixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  tooltip: AppStrings.clearSearchTooltip,
                  icon: const Icon(AppMaterialIcons.close),
                ),
        ),
      ),
    );
  }
}
