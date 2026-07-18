import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/business.dart';
import '../../domain/usecases/search_businesses.dart';
import '../widgets/business_card.dart';
import '../widgets/category_filter.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.searchBusinesses, super.key});

  final SearchBusinesses searchBusinesses;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  late final Future<List<Business>> _businessesFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _businessesFuture = widget.searchBusinesses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  List<Business> _filterBusinesses(List<Business> businesses) {
    if (_searchQuery.isEmpty) {
      return businesses;
    }

    return businesses.where((business) {
      final searchableText = [
        business.name,
        business.slug,
        business.description ?? '',
        business.type,
        business.businessModel,
        business.city,
        business.address,
        business.settings.category,
        business.settings.currency,
      ].join(' ').toLowerCase();

      return searchableText.contains(_searchQuery);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppMaterialIcons.brand, color: AppColors.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              AppStrings.appName,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
              searchQuery: _searchQuery,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            Expanded(
              child: FutureBuilder<List<Business>>(
                future: _businessesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const AppEmptyState(
                      message: AppStrings.genericLoadError,
                    );
                  }

                  final businesses = snapshot.data ?? const <Business>[];
                  final filteredBusinesses = _filterBusinesses(businesses);

                  if (filteredBusinesses.isEmpty) {
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
                          const Icon(
                            AppMaterialIcons.location,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            AppStrings.featuredServices,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                      for (final business in filteredBusinesses) ...[
                        BusinessCard(business: business),
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
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.primary),
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
