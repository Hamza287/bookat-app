import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/constants.dart';
import '../../../../app/theme_mode_provider.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/domain/entities/business.dart';
import '../../../booking/domain/entities/my_booking.dart';
import '../../../booking/presentation/widgets/business_image.dart';
import '../../domain/entities/business_payment.dart';
import '../../domain/entities/business_stats.dart';
import '../../domain/entities/resource_category.dart';
import '../providers/business_admin_providers.dart';
import 'business_settings_page.dart';

class BusinessAdminHomePage extends ConsumerStatefulWidget {
  const BusinessAdminHomePage({super.key});

  @override
  ConsumerState<BusinessAdminHomePage> createState() =>
      _BusinessAdminHomePageState();
}

final _adminTabProvider = StateProvider.autoDispose<int>((_) => 0);

class _BusinessAdminHomePageState extends ConsumerState<BusinessAdminHomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Bookings can be made from the web dashboard or by customers while the
  /// owner has the app in the background, so coming back to the foreground
  /// re-reads the day rather than showing whatever was on screen last.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final business = ref.read(activeBusinessProvider);
    if (business == null) {
      return;
    }

    ref.invalidate(businessBookingsProvider(business.id));
    ref.invalidate(businessStatsProvider);
    ref.invalidate(businessPaymentsForMonthProvider);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    // Read through the controller rather than the session so settings saves
    // are reflected everywhere without a re-login.
    final business = ref.watch(activeBusinessProvider);
    final index = ref.watch(_adminTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (business != null) ...[
              BusinessLogo(
                logoUrl: business.logoUrl,
                fallbackText: business.name,
                size: 34,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
            ],
            Expanded(
              child: Text(
                business?.name ?? AppStrings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: business == null
          ? const AppEmptyState(message: AppStrings.noOwnedBusiness)
          : IndexedStack(
              index: index,
              children: [
                _AdminOverviewPage(business: business),
                _AdminBookingsPage(business: business),
                _AdminVenuesPage(business: business),
                _AdminPaymentsPage(business: business),
                const BusinessSettingsView(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(_adminTabProvider.notifier).state = value,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: AppStrings.overview,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: AppStrings.businessBookings,
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_rounded),
            label: AppStrings.venues,
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_rounded),
            label: AppStrings.payments,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewPage extends ConsumerWidget {
  const _AdminOverviewPage({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final statsState = ref.watch(businessStatsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      children: [
        _AdminHeader(
          title: AppStrings.overview,
          subtitle: business.address,
          business: business,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        statsState.when(
          loading: () => const _StatsLoadingGrid(),
          error: (error, _) => _StatsErrorPanel(
            message: error is Failure ? error.message : error.toString(),
            onRetry: () => ref.invalidate(businessStatsProvider),
          ),
          data: (stats) => _StatsOverviewGrid(
            stats: stats,
            currency: business.settings.currency,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        _ProfitComparisonPanel(currency: business.settings.currency),
        const SizedBox(height: AppDimensions.spacingLg),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.revenueOverview,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              SizedBox(
                height: 170,
                child: statsState.when(
                  loading: () => AppShimmerBox(
                    width: double.infinity,
                    height: 170,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  error: (_, _) => Center(
                    child: Text(
                      AppStrings.genericLoadError,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  data: (stats) => CustomPaint(
                    painter: _RevenueChartPainter(
                      lineColor: colors.primary,
                      gridColor: colors.border,
                      points: stats.chartData,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.promoteBusiness,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'https://bookat.tsgtech.co/b/${business.slug}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.primary),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              AppButton(
                label: AppStrings.copyLink,
                icon: Icons.copy_rounded,
                onPressed: () async {
                  final link = 'https://bookat.tsgtech.co/b/${business.slug}';
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Link copied to clipboard: $link'),
                        backgroundColor: colors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                isExpanded: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminBookingsPage extends ConsumerStatefulWidget {
  const _AdminBookingsPage({required this.business});

  final Business business;

  @override
  ConsumerState<_AdminBookingsPage> createState() => _AdminBookingsPageState();
}

final _adminSelectedDateProvider = StateProvider.autoDispose<DateTime>((_) {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day);
});
final _adminSelectedResourceIdProvider = StateProvider.autoDispose<String>(
  (_) => '',
);

class _AdminBookingsPageState extends ConsumerState<_AdminBookingsPage> {
  // Never changes after first build, so it stays a plain computed field
  // rather than provider state.
  late final List<DateTime> _dates = List.generate(14, (index) {
    final date = DateTime.now().add(Duration(days: index));
    return DateTime(date.year, date.month, date.day);
  });

  void _showAddBookingSheet(
    BuildContext context,
    List<BusinessResource> resources,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _AddBookingSheet(business: widget.business, resources: resources),
    );
  }

  /// The rolling strip only covers the next fortnight, so a date chosen from
  /// the calendar has to be spliced in — otherwise it would be selected with
  /// no tile to show for it.
  List<DateTime> _stripDates(DateTime selectedDate) {
    if (_dates.any((date) => _sameDate(date, selectedDate))) {
      return _dates;
    }
    return [..._dates, selectedDate]..sort();
  }

  @override
  Widget build(BuildContext context) {
    // Fetched, not read off the business: `business.resources` is the snapshot
    // captured at login and cached in shared preferences, so a venue added
    // since then is missing from it — which left "Add Booking" disabled and the
    // venue filter empty until the owner signed out and back in.
    final resourcesState = ref.watch(
      businessResourcesProvider(widget.business.id),
    );
    final resources = resourcesState.valueOrNull ?? widget.business.resources;
    final bookingsState = ref.watch(
      businessBookingsProvider(widget.business.id),
    );
    final selectedDate = ref.watch(_adminSelectedDateProvider);
    final selectedResourceId = ref.watch(_adminSelectedResourceIdProvider);
    final selectedResourceLabel = selectedResourceId.isEmpty
        ? 'All venues'
        : _resourceLabel(resources, selectedResourceId);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(businessBookingsProvider(widget.business.id));
        ref.invalidate(businessResourcesProvider(widget.business.id));
        await ref.read(businessBookingsProvider(widget.business.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        // Always scrollable, otherwise a day with no bookings has nothing to
        // drag and the owner cannot pull to refresh it.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _AdminHeader(
            title: AppStrings.businessBookings,
            subtitle: AppStrings.manageReservations,
            business: widget.business,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          AppButton(
            label: AppStrings.addBooking,
            icon: Icons.add_rounded,
            onPressed: resources.isEmpty
                ? null
                : () => _showAddBookingSheet(context, resources),
            isExpanded: true,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          _AdminBookingDateStrip(
            dates: _stripDates(selectedDate),
            selectedDate: selectedDate,
            onChanged: (date) =>
                ref.read(_adminSelectedDateProvider.notifier).state = date,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          _AdminBookingSummaryStrip(
            selectedDate: selectedDate,
            venueLabel: selectedResourceLabel,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          if (resources.isNotEmpty) ...[
            _AdminResourceFilter(
              resources: resources,
              selectedResourceId: selectedResourceId,
              onChanged: (resourceId) {
                ref.read(_adminSelectedResourceIdProvider.notifier).state =
                    resourceId;
              },
            ),
            const SizedBox(height: AppDimensions.spacingLg),
          ],
          bookingsState.when(
            loading: () => const _AdminBookingsLoading(),
            error: (error, _) => AppEmptyState(
              message: error is Failure
                  ? error.message
                  : 'We could not load business bookings.',
              icon: Icons.event_busy_rounded,
            ),
            data: (bookings) {
              final filtered = _filterAdminBookings(
                bookings,
                selectedDate: selectedDate,
                resourceId: selectedResourceId,
              );
              return _Panel(
                child: filtered.isEmpty
                    ? _AdminBookingEmptyTimeline(
                        selectedDate: selectedDate,
                        venueLabel: selectedResourceLabel,
                      )
                    : _AdminBookingsTimeline(
                        bookings: filtered,
                        selectedDate: selectedDate,
                        currency: widget.business.settings.currency,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manual booking
// ---------------------------------------------------------------------------

final _manualVenueIdProvider = StateProvider.autoDispose<String?>((_) => null);

/// Defaults to the next whole hour, which is what an owner taking a walk-in
/// almost always wants — and avoids a start time already in the past.
final _manualStartProvider = StateProvider.autoDispose<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, now.hour + 1);
});

final _manualEndProvider = StateProvider.autoDispose<DateTime?>((_) => null);
final _manualSavingProvider = StateProvider.autoDispose<bool>((_) => false);

/// Mirrors the custom-price field so the summary can show whether the typed
/// override or the calculated price will be charged.
final _manualCustomPriceProvider = StateProvider.autoDispose<String>((_) => '');

class _AddBookingSheet extends ConsumerStatefulWidget {
  const _AddBookingSheet({required this.business, required this.resources});

  final Business business;
  final List<BusinessResource> resources;

  @override
  ConsumerState<_AddBookingSheet> createState() => _AddBookingSheetState();
}

class _AddBookingSheetState extends ConsumerState<_AddBookingSheet> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customPriceController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _customPriceController.dispose();
    super.dispose();
  }

  /// The venue whose price and slot length drive the calculation, falling back
  /// to the first one so the sheet always shows a real figure.
  BusinessResource? get _selectedResource {
    final selectedId = ref.watch(_manualVenueIdProvider);
    for (final resource in widget.resources) {
      if (_resourceId(resource) == selectedId) {
        return resource;
      }
    }
    return widget.resources.isEmpty ? null : widget.resources.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = widget.business.settings.currency;
    final isSaving = ref.watch(_manualSavingProvider);
    final start = ref.watch(_manualStartProvider);
    // An unset end defaults to one slot after the start, so the calculated
    // price is never a meaningless zero on open.
    final resource = _selectedResource;
    final slotMinutes = _resourceSlotMinutes(resource);
    final end =
        ref.watch(_manualEndProvider) ??
        start.add(Duration(minutes: slotMinutes));
    final customPrice = ref.watch(_manualCustomPriceProvider);

    final calculated = _calculatedPrice(
      resource: resource,
      start: start,
      end: end,
    );
    final override = num.tryParse(customPrice.trim());
    final sheetHeight = MediaQuery.sizeOf(context).height * .9;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingMd,
          right: AppDimensions.spacingMd,
          top: AppDimensions.spacingMd,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              AppDimensions.spacingMd,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sheetHeight),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(color: colors.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.addManualBooking,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    AppStrings.addManualBookingHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  _SheetSectionLabel(label: AppStrings.customerInformation),
                  const SizedBox(height: AppDimensions.spacingMd),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final first = TextField(
                        controller: _firstNameController,
                        enabled: !isSaving,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: '${AppStrings.firstName} *',
                        ),
                      );
                      final last = TextField(
                        controller: _lastNameController,
                        enabled: !isSaving,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: '${AppStrings.lastName} *',
                        ),
                      );

                      // Two name fields side by side need real room; below that
                      // they stack rather than squeezing the labels.
                      if (constraints.maxWidth < 340) {
                        return Column(
                          children: [
                            first,
                            const SizedBox(height: AppDimensions.spacingMd),
                            last,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: first),
                          const SizedBox(width: AppDimensions.spacingMd),
                          Expanded(child: last),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  TextField(
                    controller: _emailController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: AppStrings.emailOptional,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  TextField(
                    controller: _phoneController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '${AppStrings.phoneNumber} *',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  _SheetSectionLabel(label: AppStrings.bookingDetails),
                  const SizedBox(height: AppDimensions.spacingMd),
                  DropdownButtonFormField<String>(
                    initialValue: resource == null
                        ? null
                        : _resourceId(resource),
                    isExpanded: true,
                    items: [
                      for (final venue in widget.resources)
                        DropdownMenuItem(
                          value: _resourceId(venue),
                          child: Text(_resourceName(venue)),
                        ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (value) =>
                              ref.read(_manualVenueIdProvider.notifier).state =
                                  value,
                    decoration: const InputDecoration(
                      labelText: '${AppStrings.venue} *',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  _ManualDateTimeField(
                    label: '${AppStrings.startTime} *',
                    value: start,
                    enabled: !isSaving,
                    onChanged: (value) {
                      ref.read(_manualStartProvider.notifier).state = value;
                      // Keep the end after the start; the owner can still move
                      // it afterwards.
                      final currentEnd = ref.read(_manualEndProvider);
                      if (currentEnd == null || !currentEnd.isAfter(value)) {
                        ref.read(_manualEndProvider.notifier).state = value.add(
                          Duration(minutes: slotMinutes),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  _ManualDateTimeField(
                    label: '${AppStrings.endTime} *',
                    value: end,
                    enabled: !isSaving,
                    onChanged: (value) =>
                        ref.read(_manualEndProvider.notifier).state = value,
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  _ManualPricePanel(
                    currency: currency,
                    calculated: calculated,
                    overridePrice: override,
                    controller: _customPriceController,
                    enabled: !isSaving,
                    onChanged: (value) =>
                        ref.read(_manualCustomPriceProvider.notifier).state =
                            value,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cancel = AppButton(
                        label: AppStrings.cancel,
                        type: AppButtonType.outlined,
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        isExpanded: true,
                      );
                      final submit = AppButton(
                        label: AppStrings.addBooking,
                        isLoading: isSaving,
                        onPressed: isSaving
                            ? null
                            : () => _submit(
                                resource: resource,
                                start: start,
                                end: end,
                                override: override,
                              ),
                        isExpanded: true,
                      );

                      if (constraints.maxWidth < 320) {
                        return Column(
                          children: [
                            submit,
                            const SizedBox(height: AppDimensions.spacingMd),
                            cancel,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: cancel),
                          const SizedBox(width: AppDimensions.spacingMd),
                          Expanded(child: submit),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit({
    required BusinessResource? resource,
    required DateTime start,
    required DateTime end,
    required num? override,
  }) async {
    final resourceId = resource == null ? '' : _resourceId(resource);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (resourceId.isEmpty) {
      _showMessage('Please choose a venue.', isError: true);
      return;
    }
    if (firstName.isEmpty || lastName.isEmpty) {
      _showMessage(
        'Please enter the customer\'s first and last name.',
        isError: true,
      );
      return;
    }
    if (phone.isEmpty) {
      _showMessage('Please enter a phone number.', isError: true);
      return;
    }
    if (!end.isAfter(start)) {
      _showMessage(AppStrings.endTimeAfterStart, isError: true);
      return;
    }

    ref.read(_manualSavingProvider.notifier).state = true;

    final error = await ref
        .read(businessAdminActionControllerProvider)
        .createManualBooking(
          resourceId: resourceId,
          startTime: start,
          endTime: end,
          firstName: firstName,
          lastName: lastName,
          email: _emailController.text.trim(),
          phone: phone,
          overridePrice: override,
        );

    if (!mounted) {
      return;
    }

    ref.read(_manualSavingProvider.notifier).state = false;

    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.bookingCreatedForCustomer)),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.primary,
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // The rule sits under the label rather than beside it: a long section name
    // plus an Expanded divider cannot both fit on one line on a small phone.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Divider(color: colors.border),
      ],
    );
  }
}

/// One tap opens the date picker then the time picker, so a full timestamp is
/// chosen without leaving the sheet.
class _ManualDateTimeField extends StatelessWidget {
  const _ManualDateTimeField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.event_rounded),
        ),
        child: Text(
          '${_dayMonthYear(value)}'
          ' · ${_timeLabel(value)}',
          style: TextStyle(color: colors.textPrimary),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 365)),
      lastDate: DateTime(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 365)),
    );

    if (date == null || !context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );

    if (time == null) {
      return;
    }

    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _ManualPricePanel extends StatelessWidget {
  const _ManualPricePanel({
    required this.currency,
    required this.calculated,
    required this.overridePrice,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String currency;
  final num calculated;

  /// Named `overridePrice`, not `override` — a field called `override` shadows
  /// the `@override` annotation inside the class.
  final num? overridePrice;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final charged = overridePrice ?? calculated;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: colors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.calculatedPrice,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$currency ${_money(calculated)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  // Struck through once an override takes over, so it is
                  // obvious which number is actually charged.
                  decoration: overridePrice == null
                      ? TextDecoration.none
                      : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: AppStrings.customPriceLabel,
              hintText: AppStrings.customPriceHint,
            ),
          ),
          if (overridePrice != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Charging $currency ${_money(charged)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _resourceId(BusinessResource resource) {
  return resource.data['id']?.toString() ?? '';
}

String _resourceName(BusinessResource resource) {
  final name = resource.data['name']?.toString() ?? '';
  return _venueName(name.isEmpty ? AppStrings.venue : name);
}

/// A resource's own slot length, defaulting to an hour when it declares none.
int _resourceSlotMinutes(BusinessResource? resource) {
  if (resource == null) {
    return 60;
  }
  final raw = _nestedText(resource.data, ['attributes', 'durationMinutes']);
  final parsed = int.tryParse(raw);
  return parsed == null || parsed <= 0 ? 60 : parsed;
}

/// Prices the booking the way the slot is sold: the venue's base price per
/// slot, pro-rated across however long the owner blocked out. A 90-minute
/// booking of a 60-minute slot therefore costs 1.5 slots.
num _calculatedPrice({
  required BusinessResource? resource,
  required DateTime start,
  required DateTime end,
}) {
  if (resource == null) {
    return 0;
  }

  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) {
    return 0;
  }

  final basePrice = _resourceBasePrice(resource);
  final slotMinutes = _resourceSlotMinutes(resource);
  final price = basePrice * minutes / slotMinutes;

  // Trim floating point noise (2500 * 90 / 60 must read 3750, not 3749.99).
  return num.parse(price.toStringAsFixed(2));
}

num _resourceBasePrice(BusinessResource resource) {
  final direct = resource.data['basePrice'];
  if (direct is num) {
    return direct;
  }

  final parsed = num.tryParse(direct?.toString() ?? '');
  if (parsed != null) {
    return parsed;
  }

  return num.tryParse(
        _nestedText(resource.data, ['attributes', 'basePrice']),
      ) ??
      0;
}

/// Methods the owner can settle a payment against. The server accepts any
/// string, but these are the four the revenue breakdown reports on, so offering
/// anything else would produce a payment that never shows up in the totals.
const _paymentMethods = <String>['CASH', 'ONLINE', 'CARD', 'BANK_TRANSFER'];

/// Method chosen per payment row, before "Mark as Paid" is pressed. Keyed by
/// payment id so two rows can be staged independently.
final _paymentMethodDraftProvider =
    StateProvider.autoDispose<Map<String, String>>((_) => const {});

/// Id of the payment currently being written, so only its own button spins.
final _settlingPaymentIdProvider = StateProvider.autoDispose<String?>(
  (_) => null,
);

class _AdminPaymentsPage extends ConsumerWidget {
  const _AdminPaymentsPage({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsState = ref.watch(businessPaymentsProvider);
    final month = ref.watch(paymentsMonthProvider);
    final currency = business.settings.currency;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(businessPaymentsProvider);
        await ref.read(businessPaymentsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        children: [
          _AdminHeader(
            title: AppStrings.payments,
            subtitle: AppStrings.trackPayments,
            business: business,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          _PaymentsMonthSwitcher(
            month: month,
            onChanged: (value) =>
                ref.read(paymentsMonthProvider.notifier).state = value,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          paymentsState.when(
            loading: () => const _AdminBookingsLoading(),
            error: (error, _) => AppEmptyState(
              message: error is Failure
                  ? error.message
                  : AppStrings.paymentsLoadError,
              icon: Icons.credit_card_off_rounded,
            ),
            data: (payments) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PaymentStatsGrid(stats: payments.stats, currency: currency),
                const SizedBox(height: AppDimensions.spacingLg),
                _PaymentMethodBreakdown(
                  stats: payments.stats,
                  currency: currency,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                if (payments.payments.isEmpty)
                  const _Panel(
                    child: AppEmptyState(
                      message: AppStrings.noPaymentsForMonth,
                      icon: Icons.receipt_long_rounded,
                    ),
                  )
                else
                  for (final payment in payments.payments) ...[
                    _PaymentCard(payment: payment, currency: currency),
                    const SizedBox(height: AppDimensions.spacingMd),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsMonthSwitcher extends StatelessWidget {
  const _PaymentsMonthSwitcher({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _Panel(
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${_monthName(month.month)} ${month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Lays tiles out in as many columns as fit at [minTileWidth], letting each one
/// size its own height.
///
/// A `GridView` with a fixed `childAspectRatio` cannot do this: the ratio pins
/// the height to the column width, so a narrow phone gets a box shorter than its
/// own text and Flutter reports a bottom overflow. Here the height is whatever
/// the content needs, at any width.
class _ResponsiveTileGrid extends StatelessWidget {
  const _ResponsiveTileGrid({required this.tiles, this.minTileWidth = 150});

  final List<Widget> tiles;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppDimensions.spacingMd;
        final available = constraints.maxWidth;

        var columns = ((available + gap) / (minTileWidth + gap)).floor();
        columns = columns.clamp(1, tiles.length);

        // Floor the width so rounding can never push the last tile past the
        // edge and wrap a column early.
        final tileWidth = ((available - gap * (columns - 1)) / columns)
            .floorToDouble();

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _PaymentStatsGrid extends StatelessWidget {
  const _PaymentStatsGrid({required this.stats, required this.currency});

  final BusinessPaymentStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _ResponsiveTileGrid(
      // Narrow enough that three fit side by side on a normal phone, but they
      // drop to two (then one) rather than squeezing the amounts illegibly.
      minTileWidth: 104,
      tiles: [
        _PaymentStatTile(
          label: AppStrings.revenue,
          value: '$currency ${_money(stats.totalRevenue)}',
          valueColor: colors.accent,
        ),
        _PaymentStatTile(
          label: AppStrings.pending,
          value: '$currency ${_money(stats.pendingRevenue)}',
          valueColor: const Color(0xFFD97706),
        ),
        _PaymentStatTile(
          label: AppStrings.payments,
          value: stats.numberOfPayments.toString(),
          valueColor: colors.primary,
        ),
      ],
    );
  }
}

class _PaymentStatTile extends StatelessWidget {
  const _PaymentStatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodBreakdown extends StatelessWidget {
  const _PaymentMethodBreakdown({required this.stats, required this.currency});

  final BusinessPaymentStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final entries = stats.methodBreakdown.entries.toList(growable: false);

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.revenueByMethod,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _ResponsiveTileGrid(
            tiles: [
              for (final entry in entries)
                _PaymentStatTile(
                  label: _titleCaseEnum(entry.key),
                  value: '$currency ${_money(entry.value)}',
                  valueColor: colors.textPrimary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({required this.payment, required this.currency});

  final BusinessPayment payment;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final drafts = ref.watch(_paymentMethodDraftProvider);
    final settlingId = ref.watch(_settlingPaymentIdProvider);
    final isSettling = settlingId == payment.id;

    // The stored method (`VENUE` for pay-at-venue bookings) is not one of the
    // settle options, so fall back to the first rather than feeding the
    // dropdown a value it has no item for.
    final selectedMethod =
        drafts[payment.id] ??
        (_paymentMethods.contains(payment.method.toUpperCase())
            ? payment.method.toUpperCase()
            : _paymentMethods.first);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.customerName.isEmpty
                          ? 'Customer'
                          : payment.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      payment.resourceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (payment.slotStart != null) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        _paymentSlotLabel(payment.slotStart!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              // Flexible, not fixed: a long amount shrinks to fit rather than
              // pushing the row past the card edge.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currency ${_money(payment.amount)}',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    _StatusChip(label: payment.status),
                  ],
                ),
              ),
            ],
          ),
          if (payment.isPending) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              AppStrings.paymentMethod.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            LayoutBuilder(
              builder: (context, constraints) {
                final methodField = DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  isExpanded: true,
                  items: [
                    for (final method in _paymentMethods)
                      DropdownMenuItem(
                        value: method,
                        child: Text(_titleCaseEnum(method)),
                      ),
                  ],
                  onChanged: isSettling
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(_paymentMethodDraftProvider.notifier)
                              .update(
                                (current) => {...current, payment.id: value},
                              );
                        },
                  decoration: const InputDecoration(isDense: true),
                );

                final payButton = AppButton(
                  label: AppStrings.markAsPaid,
                  isLoading: isSettling,
                  onPressed: isSettling
                      ? null
                      : () => _settle(context, ref, selectedMethod),
                  isExpanded: true,
                );

                // Side by side needs room for a readable dropdown *and* the
                // button label; below that they stack instead of clipping.
                if (constraints.maxWidth < 320) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      methodField,
                      const SizedBox(height: AppDimensions.spacingMd),
                      payButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: methodField),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(child: payButton),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    String method,
  ) async {
    ref.read(_settlingPaymentIdProvider.notifier).state = payment.id;

    final error = await ref
        .read(businessAdminActionControllerProvider)
        .settlePayment(paymentId: payment.id, method: method);

    // The row is rebuilt from the refreshed list, so clear the spinner against
    // the provider rather than a `mounted` check on a widget that may be gone.
    ref.read(_settlingPaymentIdProvider.notifier).state = null;

    if (!context.mounted) {
      return;
    }

    final colors = context.appColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? AppStrings.paymentMarkedPaid),
        backgroundColor: error == null ? colors.primary : colors.error,
      ),
    );
  }
}

String _paymentSlotLabel(DateTime slotStart) {
  final local = slotStart.toLocal();
  return '${_dayMonthYear(local)}'
      ' · ${_timeLabel(local)}';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthName(int month) => _monthNames[month - 1];

class _AdminVenuesPage extends ConsumerStatefulWidget {
  const _AdminVenuesPage({required this.business});

  final Business business;

  @override
  ConsumerState<_AdminVenuesPage> createState() => _AdminVenuesPageState();
}

final _adminVenuesTabProvider = StateProvider.autoDispose<int>((_) => 0);

class _AdminVenuesPageState extends ConsumerState<_AdminVenuesPage> {
  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final resourcesState = ref.watch(businessResourcesProvider(business.id));
    final categoriesState = ref.watch(resourceCategoriesProvider(business.id));
    final selectedTab = ref.watch(_adminVenuesTabProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminHeader(
            title: AppStrings.venuesAreas,
            subtitle: AppStrings.manageVenues,
            business: business,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          _AdminSegmentedTabs(
            labels: const [
              'Venues',
              'Categories',
              'Exceptions',
              'Map Configuration',
            ],
            selectedIndex: selectedTab,
            onChanged: (index) =>
                ref.read(_adminVenuesTabProvider.notifier).state = index,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          if (selectedTab == 0) ...[
            AppButton(
              label: AppStrings.addVenue,
              icon: Icons.add_rounded,
              onPressed: () {
                final resources =
                    resourcesState.valueOrNull ?? business.resources;
                final categories = categoriesState.valueOrNull ?? const [];
                _showAddVenueSheet(context, resources, categories);
              },
              isExpanded: true,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Expanded(
              child: resourcesState.when(
                loading: () => const _VenuesLoadingSkeleton(),
                error: (error, _) => AppEmptyState(
                  message: error is Failure
                      ? error.message
                      : 'We could not load business venues.',
                  icon: Icons.location_off_rounded,
                ),
                data: (resources) {
                  if (resources.isEmpty) {
                    return const AppEmptyState(
                      message: 'No venues found.',
                      icon: Icons.location_off_rounded,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacingXl,
                    ),
                    itemCount: resources.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimensions.spacingMd),
                    itemBuilder: (context, index) => _VenueCard(
                      data: resources[index].data,
                      businessId: business.id,
                      categories: categoriesState.valueOrNull ?? const [],
                    ),
                  );
                },
              ),
            ),
          ] else if (selectedTab == 1) ...[
            Expanded(
              child: categoriesState.when(
                loading: () => const _CategoryListSkeleton(),
                error: (error, _) => _CategoryList(
                  businessId: business.id,
                  categories: const [],
                  message: error is Failure
                      ? error.message
                      : 'We could not load venue categories.',
                  onAdd: () => _showAddCategorySheet(context),
                ),
                data: (categories) => _CategoryList(
                  businessId: business.id,
                  categories: categories,
                  onAdd: () => _showAddCategorySheet(context),
                ),
              ),
            ),
          ] else if (selectedTab == 2) ...[
            Expanded(child: _AdminExceptionsView(business: business)),
          ] else ...[
            Expanded(child: _VenueMapBuilderWidget(business: business)),
          ],
        ],
      ),
    );
  }

  void _showAddVenueSheet(
    BuildContext context,
    List<BusinessResource> resources,
    List<ResourceCategory> categories,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddVenueSheet(
        businessId: widget.business.id,
        resources: resources,
        categories: categories,
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCategorySheet(businessId: widget.business.id),
    );
  }
}

class _AdminBookingDateStrip extends StatelessWidget {
  const _AdminBookingDateStrip({
    required this.dates,
    required this.selectedDate,
    required this.onChanged,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // One extra slot at the end holds the calendar tile, so any date beyond
        // the rolling fortnight is still reachable.
        itemCount: dates.length + 1,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppDimensions.spacingSm),
        itemBuilder: (context, index) {
          if (index == dates.length) {
            return _AdminCalendarPickerTile(
              selectedDate: selectedDate,
              onPicked: onChanged,
            );
          }

          final date = dates[index];
          final isSelected = _sameDate(date, selectedDate);
          return Material(
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: InkWell(
              onTap: () => onChanged(date),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: Container(
                width: 68,
                padding: const EdgeInsets.all(AppDimensions.spacingSm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _shortWeekday(date),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? colors.textOnPrimary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      date.day.toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isSelected
                            ? colors.textOnPrimary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Opens a full calendar so the owner can jump to any date, not just the
/// fortnight the strip renders. Unlike the customer picker this allows past
/// dates — an owner reviewing what already happened is a normal case.
class _AdminCalendarPickerTile extends StatelessWidget {
  const _AdminCalendarPickerTile({
    required this.selectedDate,
    required this.onPicked,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: () => _pickDate(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          width: 68,
          padding: const EdgeInsets.all(AppDimensions.spacingSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_rounded, color: colors.primary),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'More',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    final anchor = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: anchor.subtract(const Duration(days: 365)),
      lastDate: anchor.add(const Duration(days: 365)),
    );

    if (picked != null) {
      onPicked(DateTime(picked.year, picked.month, picked.day));
    }
  }
}

class _AdminBookingSummaryStrip extends StatelessWidget {
  const _AdminBookingSummaryStrip({
    required this.selectedDate,
    required this.venueLabel,
  });

  final DateTime selectedDate;
  final String venueLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactStatPill(
            label: 'Date',
            value: _adminDateLabel(selectedDate),
            icon: Icons.event_rounded,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: _CompactStatPill(
            label: 'Venue',
            value: venueLabel,
            icon: Icons.location_on_outlined,
          ),
        ),
      ],
    );
  }
}

class _CompactStatPill extends StatelessWidget {
  const _CompactStatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          children: [
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminResourceFilter extends StatelessWidget {
  const _AdminResourceFilter({
    required this.resources,
    required this.selectedResourceId,
    required this.onChanged,
  });

  final List<BusinessResource> resources;
  final String selectedResourceId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items =
        [
              const MapEntry('', 'All venues'),
              for (final resource in resources)
                MapEntry(
                  resource.data['id']?.toString() ?? '',
                  _venueName(
                    resource.data['name']?.toString() ?? AppStrings.venue,
                  ),
                ),
            ]
            .where((item) => item.key.isNotEmpty || item.value == 'All venues')
            .toList();
    final colors = context.appColors;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppDimensions.spacingSm),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item.key == selectedResourceId;
          return ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            label: Text(item.value),
            avatar: Icon(
              item.key.isEmpty
                  ? Icons.grid_view_rounded
                  : Icons.location_on_outlined,
              size: 18,
              color: isSelected ? colors.textOnPrimary : colors.primary,
            ),
            labelStyle: TextStyle(
              color: isSelected ? colors.textOnPrimary : colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: colors.primary,
            backgroundColor: colors.surface,
            side: BorderSide(
              color: isSelected ? colors.primary : colors.border,
            ),
            onSelected: (_) => onChanged(item.key),
          );
        },
      ),
    );
  }
}

class _AdminBookingEmptyTimeline extends StatelessWidget {
  const _AdminBookingEmptyTimeline({
    required this.selectedDate,
    required this.venueLabel,
  });

  final DateTime selectedDate;
  final String venueLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _adminDateLabel(selectedDate),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                child: Text(
                  '0 bookings',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          venueLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing2xl),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXl,
              vertical: AppDimensions.spacing3xl,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryLight,
                  child: Icon(
                    Icons.event_available_rounded,
                    color: colors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  'No bookings yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Reservations for this date and venue will appear here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminBookingsLoading extends StatelessWidget {
  const _AdminBookingsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppShimmerBox(width: double.infinity, height: 92),
        SizedBox(height: AppDimensions.spacingMd),
        AppShimmerBox(width: double.infinity, height: 92),
        SizedBox(height: AppDimensions.spacingMd),
        AppShimmerBox(width: double.infinity, height: 92),
      ],
    );
  }
}

class _AdminBookingsTimeline extends StatelessWidget {
  const _AdminBookingsTimeline({
    required this.bookings,
    required this.selectedDate,
    required this.currency,
  });

  final List<MyBooking> bookings;
  final DateTime selectedDate;

  /// Taken from the business, not the booking payload: the bookings endpoint
  /// does not nest business settings, so deriving it per booking silently
  /// fell back to PKR.
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final total = bookings.fold<num>(
      0,
      (sum, booking) => sum + booking.totalPrice,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _adminDateLabel(selectedDate),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    '${bookings.length} reservations',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                child: Text(
                  '$currency ${_money(total)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        for (final booking in bookings) ...[
          _AdminBookingCard(booking: booking, currency: currency),
          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ],
    );
  }
}

/// Which booking rows are expanded, keyed by booking id. Collapsed by default
/// so a busy day still reads as a scannable timeline.
final _expandedBookingIdsProvider = StateProvider.autoDispose<Set<String>>(
  (_) => const <String>{},
);

class _AdminBookingCard extends ConsumerWidget {
  const _AdminBookingCard({required this.booking, required this.currency});

  final MyBooking booking;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isExpanded = ref
        .watch(_expandedBookingIdsProvider)
        .contains(booking.id);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: InkWell(
          onTap: () {
            ref.read(_expandedBookingIdsProvider.notifier).update((current) {
              final next = {...current};
              if (!next.remove(booking.id)) {
                next.add(booking.id);
              }
              return next;
            });
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        booking.resourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    _StatusChip(label: booking.status),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Expanded(
                      child: Text(
                        _adminBookingTimeLabel(booking),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Expanded(
                      child: Text(
                        '$currency ${_money(booking.totalPrice)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      booking.paymentStatus.isEmpty
                          ? '--'
                          : booking.paymentStatus,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  Divider(color: colors.border, height: 1),
                  const SizedBox(height: AppDimensions.spacingMd),
                  _AdminBookingDetails(booking: booking, currency: currency),
                ],
                const SizedBox(height: AppDimensions.spacingXs),
                Center(
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The customer behind a booking, revealed when the owner taps the card.
class _AdminBookingDetails extends StatelessWidget {
  const _AdminBookingDetails({required this.booking, required this.currency});

  final MyBooking booking;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final name = booking.customerName;
    final phone = booking.customerPhone;
    final email = booking.customerEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _AdminDetailRow(
          icon: Icons.person_outline_rounded,
          label: name.isEmpty ? 'Name not provided' : name,
        ),
        if (phone.isNotEmpty)
          _AdminDetailRow(icon: Icons.phone_outlined, label: phone),
        if (email.isNotEmpty)
          _AdminDetailRow(icon: Icons.mail_outline_rounded, label: email),
        const SizedBox(height: AppDimensions.spacingMd),
        Text(
          'Booking',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _AdminDetailRow(
          icon: Icons.confirmation_number_outlined,
          label: 'Ref ${_bookingReference(booking.id)}',
        ),
        _AdminDetailRow(
          icon: Icons.credit_card_rounded,
          label: booking.paymentMethod.isEmpty
              ? 'Payment method not set'
              : _titleCaseEnum(booking.paymentMethod),
        ),
        _AdminDetailRow(
          icon: Icons.event_available_rounded,
          label:
              '${booking.slotCount} '
              'slot${booking.slotCount == 1 ? '' : 's'} · '
              '$currency ${_money(booking.totalPrice)}',
        ),
      ],
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Booking ids are UUIDs — far too long to read out over the phone, so the
/// card shows the leading block the API's own dashboards use.
String _bookingReference(String id) {
  if (id.isEmpty) {
    return '--';
  }
  final head = id.split('-').first;
  return head.toUpperCase();
}

String _titleCaseEnum(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.title,
    required this.subtitle,
    required this.business,
  });

  final String title;
  final String subtitle;
  final Business business;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _StatsOverviewGrid extends StatelessWidget {
  const _StatsOverviewGrid({required this.stats, required this.currency});

  final BusinessStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveTileGrid(
      tiles: [
        _MetricCard(
          title: AppStrings.revenueToday,
          value: '$currency ${_money(stats.todayRevenue)}',
          icon: Icons.attach_money_rounded,
        ),
        _MetricCard(
          title: AppStrings.appointmentsToday,
          value: stats.appointmentsToday.toString(),
          icon: Icons.calendar_today_rounded,
        ),
        _MetricCard(
          title: AppStrings.activeVenues,
          value: stats.activeResources.toString(),
          icon: Icons.groups_rounded,
        ),
        _MetricCard(
          title: AppStrings.occupancyRate,
          value: stats.occupancyRate.isEmpty ? '0%' : stats.occupancyRate,
          icon: Icons.monitor_heart_outlined,
        ),
      ],
    );
  }
}

class _StatsLoadingGrid extends StatelessWidget {
  const _StatsLoadingGrid();

  /// Roughly a loaded [_MetricCard], so the grid does not jump height when the
  /// real numbers arrive.
  static const _placeholderHeight = 108.0;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveTileGrid(
      tiles: [
        for (var i = 0; i < 4; i++)
          const AppShimmerBox(
            width: double.infinity,
            height: _placeholderHeight,
          ),
      ],
    );
  }
}

class _StatsErrorPanel extends StatelessWidget {
  const _StatsErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.genericLoadError,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          AppButton(
            label: AppStrings.retry,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Sizes to its content rather than filling a bounded box, so the card
        // works inside a self-sizing grid and can grow with scaled-up text.
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              Icon(icon, color: colors.primary),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: child,
      ),
    );
  }
}

class _VenueCard extends ConsumerWidget {
  const _VenueCard({
    required this.data,
    required this.businessId,
    required this.categories,
  });

  final Map<String, dynamic> data;
  final String businessId;
  final List<ResourceCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isActive = data['isActive'] is bool
        ? data['isActive'] as bool
        : data['isActive']?.toString().toLowerCase() != 'false';
    final category = _nestedText(data, ['category', 'name']);
    final duration = _nestedText(data, ['attributes', 'durationMinutes']);
    final price = data['basePrice']?.toString() ?? '0';
    final length = _nestedText(data, ['attributes', 'size', 'lengthFt']);
    final width = _nestedText(data, ['attributes', 'size', 'widthFt']);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _venueName(data['name']?.toString() ?? AppStrings.venue),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(
                  label: isActive ? AppStrings.active : AppStrings.inactive,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: [
                _CategoryChip(
                  label: category.isEmpty ? 'Uncategorized' : category,
                ),
                _DetailChip(icon: Icons.payments_outlined, label: 'PKR $price'),
                _DetailChip(
                  icon: Icons.schedule_rounded,
                  label: '${duration.isEmpty ? '60' : duration} mins',
                ),
                if (length.isNotEmpty || width.isNotEmpty)
                  _DetailChip(
                    icon: Icons.straighten_rounded,
                    label:
                        '${length.isEmpty ? '--' : length} x '
                        '${width.isEmpty ? '--' : width} ft',
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: AppDimensions.spacingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openEditVenue(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                TextButton.icon(
                  onPressed: () => _confirmDeleteVenue(context, ref),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                    size: 18,
                  ),
                  label: Text('Delete', style: TextStyle(color: colors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditVenue(BuildContext context, WidgetRef ref) {
    final resources =
        ref.read(businessResourcesProvider(businessId)).valueOrNull ??
        const <BusinessResource>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddVenueSheet(
        businessId: businessId,
        resources: resources,
        categories: categories,
        resource: BusinessResource(data: data),
      ),
    );
  }

  Future<void> _confirmDeleteVenue(BuildContext context, WidgetRef ref) async {
    final colors = context.appColors;
    final venueName = _venueName(data['name']?.toString() ?? AppStrings.venue);
    final resourceId = data['id']?.toString() ?? '';
    if (resourceId.isEmpty) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColors = dialogContext.appColors;
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: const Text('Delete venue?'),
          content: Text('Are you sure you want to delete $venueName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final error = await ref
        .read(businessAdminActionControllerProvider)
        .deleteResource(resourceId);
    if (error != null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: colors.error),
      );
      return;
    }

    ref.invalidate(businessResourcesProvider(businessId));
    await ref.read(businessResourcesProvider(businessId).future);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$venueName deleted.'),
        backgroundColor: colors.primary,
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.textSecondary),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: Text(
          label,
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _VenuesLoadingSkeleton extends StatelessWidget {
  const _VenuesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        children: [
          AppShimmerBox(width: double.infinity, height: 58),
          SizedBox(height: AppDimensions.spacingMd),
          AppShimmerBox(width: double.infinity, height: 58),
          SizedBox(height: AppDimensions.spacingMd),
          AppShimmerBox(width: double.infinity, height: 58),
        ],
      ),
    );
  }
}

class _AdminSegmentedTabs extends StatelessWidget {
  const _AdminSegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingLg,
                    vertical: AppDimensions.spacingSm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex == index
                        ? colors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: selectedIndex == index
                          ? colors.textOnPrimary
                          : colors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (index < labels.length - 1)
                const SizedBox(width: AppDimensions.spacingXs),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.businessId,
    required this.categories,
    required this.onAdd,
    this.message,
  });

  final String businessId;
  final List<ResourceCategory> categories;
  final VoidCallback onAdd;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Venue Categories',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        if (message != null)
          Expanded(
            child: AppEmptyState(
              message: message!,
              icon: Icons.category_outlined,
            ),
          )
        else if (categories.isEmpty)
          const Expanded(
            child: AppEmptyState(
              message: 'No categories yet.',
              icon: Icons.category_outlined,
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingXl),
              itemCount: categories.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimensions.spacingMd),
              itemBuilder: (context, index) =>
                  _CategoryCard(category: categories[index]),
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final ResourceCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Icon(Icons.category_outlined, color: colors.primary),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name.isEmpty ? 'Unnamed category' : category.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (category.description.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      category.description,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryListSkeleton extends StatelessWidget {
  const _CategoryListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: AppShimmerBox(height: 20)),
            SizedBox(width: AppDimensions.spacingMd),
            AppShimmerBox(width: 84, height: 40),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMd),
        AppShimmerBox(height: 76),
        SizedBox(height: AppDimensions.spacingMd),
        AppShimmerBox(height: 76),
      ],
    );
  }
}

class _AdminExceptionsView extends ConsumerWidget {
  const _AdminExceptionsView({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final exceptionsState = ref.watch(scheduleExceptionsProvider(business.id));
    final resourcesState = ref.watch(businessResourcesProvider(business.id));
    final resources = resourcesState.valueOrNull ?? business.resources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Exceptions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            FilledButton.icon(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _AddExceptionSheet(
                    businessId: business.id,
                    resources: resources,
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Exception'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Expanded(
          child: exceptionsState.when(
            loading: () => const _CategoryListSkeleton(),
            error: (error, _) => AppEmptyState(
              message: error is Failure ? error.message : error.toString(),
              icon: Icons.block_rounded,
            ),
            data: (exceptions) {
              if (exceptions.isEmpty) {
                return const AppEmptyState(
                  message: 'No schedule exceptions found.',
                  icon: Icons.event_available_rounded,
                );
              }

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  border: Border.all(color: colors.border),
                ),
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.8),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.2),
                      5: FixedColumnWidth(48),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(
                              AppDimensions.radiusMedium,
                            ),
                            topRight: Radius.circular(
                              AppDimensions.radiusMedium,
                            ),
                          ),
                        ),
                        children: [
                          _TableHeaderCell('Staff / Resource'),
                          _TableHeaderCell('Date'),
                          _TableHeaderCell('Time'),
                          _TableHeaderCell('Reason'),
                          _TableHeaderCell('Type'),
                          const SizedBox.shrink(),
                        ],
                      ),
                      for (final item in exceptions)
                        TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: colors.border),
                            ),
                          ),
                          children: [
                            _TableCell(
                              _resourceLabel(resources, item.resourceId),
                              fontWeight: FontWeight.w800,
                            ),
                            _TableCell(
                              '${item.date.month}/${item.date.day}/${item.date.year}',
                            ),
                            _TableCell(
                              item.startTime != null && item.endTime != null
                                  ? '${item.startTime} - ${item.endTime}'
                                  : 'Full Day',
                            ),
                            _TableCell(item.reason ?? '--'),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacingSm,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.spacingSm,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryLight,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    'Blocked',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TableCell(
                              child: IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: colors.error,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final err = await ref
                                      .read(
                                        businessAdminActionControllerProvider,
                                      )
                                      .deleteScheduleException(item.id);
                                  if (err != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(err),
                                        backgroundColor: colors.error,
                                      ),
                                    );
                                  } else {
                                    ref.invalidate(
                                      scheduleExceptionsProvider(business.id),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text, {this.fontWeight});
  final String text;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: fontWeight ?? FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AddExceptionSheet extends ConsumerStatefulWidget {
  const _AddExceptionSheet({required this.businessId, required this.resources});

  final String businessId;
  final List<BusinessResource> resources;

  @override
  ConsumerState<_AddExceptionSheet> createState() => _AddExceptionSheetState();
}

final _exceptionResourceIdProvider = StateProvider.autoDispose<String?>(
  (_) => null,
);
final _exceptionStartDateProvider = StateProvider.autoDispose<DateTime>(
  (_) => DateTime.now(),
);
final _exceptionEndDateProvider = StateProvider.autoDispose<DateTime>(
  (_) => DateTime.now(),
);
final _exceptionStartTimeProvider = StateProvider.autoDispose<TimeOfDay?>(
  (_) => null,
);
final _exceptionEndTimeProvider = StateProvider.autoDispose<TimeOfDay?>(
  (_) => null,
);
final _exceptionIsSubmittingProvider = StateProvider.autoDispose<bool>(
  (_) => false,
);

class _AddExceptionSheetState extends ConsumerState<_AddExceptionSheet> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selectedResourceId = ref.watch(_exceptionResourceIdProvider);
    final startDate = ref.watch(_exceptionStartDateProvider);
    final endDate = ref.watch(_exceptionEndDateProvider);
    final startTime = ref.watch(_exceptionStartTimeProvider);
    final endTime = ref.watch(_exceptionEndTimeProvider);
    final isSubmitting = ref.watch(_exceptionIsSubmittingProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.spacingXl,
        right: AppDimensions.spacingXl,
        top: AppDimensions.spacingXl,
        bottom: AppDimensions.spacingXl + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Exception',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Staff / Resource',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            DropdownButtonFormField<String>(
              initialValue: selectedResourceId,
              hint: const Text('Select resource'),
              items: [
                for (final resource in widget.resources)
                  DropdownMenuItem(
                    value: resource.data['id']?.toString() ?? '',
                    child: Text(
                      _venueName(
                        resource.data['name']?.toString() ?? AppStrings.venue,
                      ),
                    ),
                  ),
              ],
              onChanged: (val) =>
                  ref.read(_exceptionResourceIdProvider.notifier).state = val,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            ref
                                    .read(_exceptionStartDateProvider.notifier)
                                    .state =
                                picked;
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          child: Text(
                            '${startDate.month.toString().padLeft(2, '0')}/${startDate.day.toString().padLeft(2, '0')}/${startDate.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            ref.read(_exceptionEndDateProvider.notifier).state =
                                picked;
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          child: Text(
                            '${endDate.month.toString().padLeft(2, '0')}/${endDate.day.toString().padLeft(2, '0')}/${endDate.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Time (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            ref
                                    .read(_exceptionStartTimeProvider.notifier)
                                    .state =
                                picked;
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.access_time_rounded),
                          ),
                          child: Text(
                            startTime == null
                                ? '--:--'
                                : '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Time (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            ref.read(_exceptionEndTimeProvider.notifier).state =
                                picked;
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.access_time_rounded),
                          ),
                          child: Text(
                            endTime == null
                                ? '--:--'
                                : '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Reason',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g., Sick leave, Vacation, rain',
              ),
            ),
            const SizedBox(height: AppDimensions.spacing2xl),
            AppButton(
              label: isSubmitting ? 'Saving...' : 'Save Exception',
              onPressed: isSubmitting ? null : _save,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final colors = context.appColors;
    final selectedResourceId = ref.read(_exceptionResourceIdProvider);
    if (selectedResourceId == null || selectedResourceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a resource.'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    ref.read(_exceptionIsSubmittingProvider.notifier).state = true;
    final startTime = ref.read(_exceptionStartTimeProvider);
    final endTime = ref.read(_exceptionEndTimeProvider);
    final startTimeStr = startTime == null
        ? '00:00'
        : '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = endTime == null
        ? '23:59'
        : '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    final error = await ref
        .read(businessAdminActionControllerProvider)
        .createScheduleException(
          resourceId: selectedResourceId,
          date: ref.read(_exceptionStartDateProvider),
          endDate: ref.read(_exceptionEndDateProvider),
          startTime: startTimeStr,
          endTime: endTimeStr,
          isBlockout: true,
          reason: _reasonController.text.trim().isEmpty
              ? 'Blockout'
              : _reasonController.text.trim(),
        );

    if (!mounted) return;
    ref.read(_exceptionIsSubmittingProvider.notifier).state = false;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: colors.error),
      );
    } else {
      ref.invalidate(scheduleExceptionsProvider(widget.businessId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Schedule exception created successfully.'),
          backgroundColor: colors.primary,
        ),
      );
    }
  }
}

/// User-dragged overrides for venue map boxes. Anything not present here falls
/// back to the deterministic grid position computed during build.
final _venueMapPositionsProvider =
    StateProvider.autoDispose<Map<String, Offset>>(
      (_) => const <String, Offset>{},
    );

class _VenueMapBuilderWidget extends ConsumerWidget {
  const _VenueMapBuilderWidget({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final resourcesState = ref.watch(businessResourcesProvider(business.id));
    final List<BusinessResource> resources =
        resourcesState.valueOrNull ?? business.resources;

    // Group into parent venues (no parentId) and child venues (has parentId)
    final List<BusinessResource> parentResources = <BusinessResource>[
      for (final r in resources)
        if (r.data['parentId']?.toString() == null ||
            r.data['parentId']?.toString().isEmpty == true ||
            r.data['parentId']?.toString() == 'null')
          r,
    ];

    // Ensure each parent venue gets a unique non-overlapping grid offset,
    // unless the user has dragged it somewhere else.
    final draggedPositions = ref.watch(_venueMapPositionsProvider);
    final positions = <String, Offset>{};
    for (var i = 0; i < parentResources.length; i++) {
      final pId = parentResources[i].data['id']?.toString() ?? i.toString();
      final col = i % 3;
      final row = i ~/ 3;
      positions[pId] =
          draggedPositions[pId] ??
          Offset(20.0 + col * 360.0, 20.0 + row * 340.0);
    }

    final childResourcesMap = <String, List<BusinessResource>>{};
    for (final r in resources) {
      final parentId = r.data['parentId']?.toString();
      if (parentId != null && parentId.isNotEmpty && parentId != 'null') {
        BusinessResource? matchingParent;
        for (final p in parentResources) {
          if (p.data['id']?.toString() == parentId ||
              p.data['name']?.toString().toLowerCase() ==
                  parentId.toLowerCase()) {
            matchingParent = p;
            break;
          }
        }
        final parent =
            matchingParent ??
            (parentResources.isNotEmpty ? parentResources.first : r);
        final key = parent.data['id']?.toString() ?? '';
        childResourcesMap.putIfAbsent(key, () => []).add(r);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Venue Map Builder',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;

              final canvasWidget = DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  border: Border.all(color: colors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  child: InteractiveViewer(
                    constrained: false,
                    minScale: 0.6,
                    maxScale: 2.0,
                    boundaryMargin: const EdgeInsets.all(100),
                    child: SizedBox(
                      width: 1200,
                      height: 800,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: const Size(1200, 800),
                            painter: _GridPainter(gridColor: colors.border),
                          ),
                          for (final parent in parentResources) ...[
                            _buildParentBox(
                              ref: ref,
                              parent: parent,
                              children:
                                  childResourcesMap[parent.data['id']
                                      ?.toString()] ??
                                  const [],
                              colors: colors,
                              positions: positions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );

              final sidebarWidget = Container(
                width: isNarrow ? double.infinity : 240,
                height: isNarrow ? 260 : double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'VENUES',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Expanded(
                      child: ListView.separated(
                        itemCount: resources.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppDimensions.spacingSm),
                        itemBuilder: (context, index) {
                          final r = resources[index];
                          final name = _venueName(
                            r.data['name']?.toString() ?? AppStrings.venue,
                          );
                          final length = _nestedText(r.data, [
                            'attributes',
                            'size',
                            'lengthFt',
                          ]);
                          final width = _nestedText(r.data, [
                            'attributes',
                            'size',
                            'widthFt',
                          ]);

                          return Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingMd,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium,
                              ),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (length.isNotEmpty || width.isNotEmpty)
                                        Text(
                                          '${length.isEmpty ? '--' : length} x ${width.isEmpty ? '--' : width} ft',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Map layout saved successfully.',
                            ),
                            backgroundColor: colors.primary,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Map Layout'),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 380, child: canvasWidget),
                      const SizedBox(height: AppDimensions.spacingLg),
                      sidebarWidget,
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: canvasWidget),
                  const SizedBox(width: AppDimensions.spacingLg),
                  sidebarWidget,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParentBox({
    required WidgetRef ref,
    required BusinessResource parent,
    required List<BusinessResource> children,
    required AppPalette colors,
    required Map<String, Offset> positions,
  }) {
    final parentId = parent.data['id']?.toString() ?? '';
    final name = _venueName(
      parent.data['name']?.toString() ?? AppStrings.venue,
    );
    final pos = positions[parentId] ?? const Offset(20, 20);

    final lengthStr = _nestedText(parent.data, [
      'attributes',
      'size',
      'lengthFt',
    ]);
    final widthStr = _nestedText(parent.data, [
      'attributes',
      'size',
      'widthFt',
    ]);
    final lengthVal = double.tryParse(lengthStr) ?? 50.0;
    final widthVal = double.tryParse(widthStr) ?? 50.0;

    final boxWidth = (widthVal * 4.5).clamp(250.0, 420.0);
    final boxHeight = (lengthVal * 4.5).clamp(240.0, 420.0);

    // Classify children into Left and Right sub-fields
    BusinessResource? leftChild;
    BusinessResource? rightChild;
    final otherChildren = <BusinessResource>[];

    for (final child in children) {
      final childName = (child.data['name']?.toString() ?? '').toLowerCase();
      if (childName.contains('left') ||
          childName.contains('l field') ||
          childName.contains('l-field') ||
          childName == 'l') {
        leftChild = child;
      } else if (childName.contains('right') ||
          childName.contains('r field') ||
          childName.contains('r-field') ||
          childName == 'r') {
        rightChild = child;
      } else {
        otherChildren.add(child);
      }
    }

    // Fill remaining slots sequentially if not explicitly named left/right
    for (final child in otherChildren) {
      if (leftChild == null) {
        leftChild = child;
      } else if (rightChild == null) {
        rightChild = child;
      }
    }

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          ref
              .read(_venueMapPositionsProvider.notifier)
              .update(
                (current) => {
                  ...current,
                  parentId: Offset(
                    (pos.dx + details.delta.dx).clamp(0, 1200),
                    (pos.dy + details.delta.dy).clamp(0, 800),
                  ),
                },
              );
        },
        child: Container(
          width: boxWidth,
          height: boxHeight,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Parent Field Header (Name + Length x Width dimensions)
              Row(
                children: [
                  Icon(
                    Icons.drag_handle_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (lengthStr.isNotEmpty || widthStr.isNotEmpty)
                          Text(
                            'Main Field: ${lengthStr.isEmpty ? '--' : lengthStr} x ${widthStr.isEmpty ? '--' : widthStr} ft',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Split Classified Sub-Fields Container (LEFT FIELD | RIGHT FIELD)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT AREA / FIELD
                    Expanded(
                      child: _buildSubAreaBox(
                        title: 'LEFT FIELD',
                        resource: leftChild,
                        accentColor: const Color(0xFF3B82F6),
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // RIGHT AREA / FIELD
                    Expanded(
                      child: _buildSubAreaBox(
                        title: 'RIGHT FIELD',
                        resource: rightChild,
                        accentColor: const Color(0xFF10B981),
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubAreaBox({
    required String title,
    required BusinessResource? resource,
    required Color accentColor,
    required AppPalette colors,
  }) {
    final name = resource != null
        ? _venueName(resource.data['name']?.toString() ?? title)
        : title;
    final lengthStr = resource != null
        ? _nestedText(resource.data, ['attributes', 'size', 'lengthFt'])
        : '';
    final widthStr = resource != null
        ? _nestedText(resource.data, ['attributes', 'size', 'widthFt'])
        : '';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // A tint of the accent reads correctly on both light and dark surfaces.
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          if (lengthStr.isNotEmpty || widthStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${lengthStr.isEmpty ? '--' : lengthStr} x ${widthStr.isEmpty ? '--' : widthStr} ft',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.gridColor});

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withOpacity(0.15)
      ..strokeWidth = 1;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AddVenueSheet extends ConsumerStatefulWidget {
  const _AddVenueSheet({
    required this.businessId,
    required this.resources,
    required this.categories,
    this.resource,
  });

  final String businessId;
  final List<BusinessResource> resources;
  final List<ResourceCategory> categories;
  final BusinessResource? resource;

  @override
  ConsumerState<_AddVenueSheet> createState() => _AddVenueSheetState();
}

/// Everything the add/edit venue sheet keeps in memory while the user fills it
/// in. Seeded from the resource being edited (or blank defaults when adding).
class _VenueFormState {
  const _VenueFormState({
    required this.isActive,
    required this.isSubResource,
    required this.categoryId,
    required this.parentId,
    required this.pricingRules,
    this.isSaving = false,
    this.images = const <XFile>[],
    this.revision = 0,
  });

  final bool isActive;
  final bool isSubResource;
  final String categoryId;
  final String? parentId;
  final List<_PricingRuleDraft> pricingRules;
  final bool isSaving;
  final List<XFile> images;

  /// Bumped when a pricing rule edits itself in place so the sheet rebuilds.
  final int revision;

  _VenueFormState copyWith({
    bool? isActive,
    bool? isSubResource,
    String? categoryId,
    String? parentId,
    bool clearParentId = false,
    List<_PricingRuleDraft>? pricingRules,
    bool? isSaving,
    List<XFile>? images,
    int? revision,
  }) {
    return _VenueFormState(
      isActive: isActive ?? this.isActive,
      isSubResource: isSubResource ?? this.isSubResource,
      categoryId: categoryId ?? this.categoryId,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      pricingRules: pricingRules ?? this.pricingRules,
      isSaving: isSaving ?? this.isSaving,
      images: images ?? this.images,
      revision: revision ?? this.revision,
    );
  }
}

class _VenueFormNotifier
    extends AutoDisposeFamilyNotifier<_VenueFormState, BusinessResource?> {
  @override
  _VenueFormState build(BusinessResource? resource) {
    // Pricing drafts own text controllers, so they die with the provider.
    ref.onDispose(() {
      for (final rule in state.pricingRules) {
        rule.dispose();
      }
    });

    final data = resource?.data;
    if (data == null) {
      return const _VenueFormState(
        isActive: true,
        isSubResource: false,
        categoryId: '',
        parentId: null,
        pricingRules: <_PricingRuleDraft>[],
      );
    }

    final parentId = data['parentId']?.toString();
    final rules = <_PricingRuleDraft>[];
    final attributes = data['attributes'];
    if (attributes is Map<String, dynamic>) {
      final rawRules = attributes['pricingRules'];
      if (rawRules is List) {
        for (final rule in rawRules.whereType<Map<String, dynamic>>()) {
          rules.add(_PricingRuleDraft.fromMap(rule));
        }
      }
    }

    return _VenueFormState(
      isActive: data['isActive'] is bool
          ? data['isActive'] as bool
          : data['isActive']?.toString().toLowerCase() != 'false',
      isSubResource: (parentId ?? '').isNotEmpty,
      categoryId: _nestedText(data, ['category', 'id']),
      parentId: parentId,
      pricingRules: rules,
    );
  }

  void setActive(bool value) => state = state.copyWith(isActive: value);

  void setCategory(String value) => state = state.copyWith(categoryId: value);

  void setSaving(bool value) => state = state.copyWith(isSaving: value);

  void setImages(List<XFile> images) =>
      state = state.copyWith(images: List<XFile>.unmodifiable(images));

  void setSubResource(bool value) =>
      state = state.copyWith(isSubResource: value, clearParentId: !value);

  void setParent(String? value) =>
      state = state.copyWith(parentId: value, clearParentId: value == null);

  void addPricingRule() => state = state.copyWith(
    pricingRules: [...state.pricingRules, _PricingRuleDraft()],
  );

  void removePricingRuleAt(int index) {
    final rules = [...state.pricingRules];
    final removed = rules.removeAt(index);
    state = state.copyWith(pricingRules: rules);
    removed.dispose();
  }

  void refreshPricingRules() =>
      state = state.copyWith(revision: state.revision + 1);
}

final _venueFormProvider = NotifierProvider.autoDispose
    .family<_VenueFormNotifier, _VenueFormState, BusinessResource?>(
      _VenueFormNotifier.new,
    );

class _AddVenueSheetState extends ConsumerState<_AddVenueSheet> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _priceController = TextEditingController(text: '0');
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _picker = ImagePicker();

  bool get _isEdit => widget.resource != null;
  String get _resourceId => widget.resource?.data['id']?.toString() ?? '';
  _VenueFormNotifier get _form =>
      ref.read(_venueFormProvider(widget.resource).notifier);

  @override
  void initState() {
    super.initState();
    final data = widget.resource?.data;
    if (data == null) {
      return;
    }

    _nameController.text = data['name']?.toString() ?? '';
    _priceController.text = data['basePrice']?.toString() ?? '0';
    _durationController.text =
        _nestedText(data, ['attributes', 'durationMinutes']).isEmpty
        ? '60'
        : _nestedText(data, ['attributes', 'durationMinutes']);
    _lengthController.text = _nestedText(data, [
      'attributes',
      'size',
      'lengthFt',
    ]);
    _widthController.text = _nestedText(data, [
      'attributes',
      'size',
      'widthFt',
    ]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selected = await _picker.pickMultiImage(imageQuality: 82);
    if (selected.isEmpty || !mounted) {
      return;
    }
    _form.setImages(selected);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter a venue name.');
      return;
    }
    if (_isEdit && _resourceId.isEmpty) {
      _showMessage('This venue cannot be updated right now.');
      return;
    }

    final form = ref.read(_venueFormProvider(widget.resource));
    _form.setSaving(true);
    final pricingRules = form.pricingRules
        .map((rule) => rule.toPayload())
        .where((rule) => (rule['value']?.toString() ?? '').isNotEmpty)
        .toList();
    final existingImageUrls = _existingImageUrls();
    final attributes = <String, dynamic>{
      if (_lengthController.text.trim().isNotEmpty ||
          _widthController.text.trim().isNotEmpty)
        'size': {
          'lengthFt': _lengthController.text.trim(),
          'widthFt': _widthController.text.trim(),
        },
      if (_isEdit && existingImageUrls.isNotEmpty)
        'imageUrls': existingImageUrls,
      'pricingRules': pricingRules,
      'durationMinutes': _durationController.text.trim().isEmpty
          ? '60'
          : _durationController.text.trim(),
    };

    final fields = <String, dynamic>{
      'name': name,
      'attributes': jsonEncode(attributes),
      'basePrice': _priceController.text.trim().isEmpty
          ? '0'
          : _priceController.text.trim(),
      'isActive': form.isActive.toString(),
      'services': '[]',
      if (_isUuidLike(form.categoryId)) 'categoryId': form.categoryId,
      if (form.isSubResource && (form.parentId ?? '').isNotEmpty)
        'parentId': form.parentId,
    };

    final imagePaths = form.images.map((image) => image.path).toList();
    final error = _isEdit
        ? await ref
              .read(businessAdminActionControllerProvider)
              .updateResource(
                resourceId: _resourceId,
                fields: fields,
                imagePaths: imagePaths,
              )
        : await ref
              .read(businessAdminActionControllerProvider)
              .createResource(
                businessId: widget.businessId,
                fields: fields,
                imagePaths: imagePaths,
              );

    if (!mounted) {
      return;
    }

    if (error != null) {
      _form.setSaving(false);
      _showMessage(error);
      return;
    }

    ref.invalidate(businessResourcesProvider(widget.businessId));
    await ref.read(businessResourcesProvider(widget.businessId).future);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEdit ? 'Venue updated successfully.' : 'Venue added successfully.',
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _existingImageUrls() {
    final attributes = widget.resource?.data['attributes'];
    if (attributes is! Map<String, dynamic>) {
      return const [];
    }

    final imageUrls = attributes['imageUrls'];
    if (imageUrls is List) {
      return imageUrls
          .map((url) => url?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final form = ref.watch(_venueFormProvider(widget.resource));
    final isSaving = form.isSaving;
    final categories = _categoryOptions(widget.categories);
    final parentVenues = _parentVenueOptions(widget.resources);
    final sheetHeight = MediaQuery.sizeOf(context).height * .88;
    final categoryValue =
        categories.any((option) => option.id == form.categoryId)
        ? form.categoryId
        : '';
    final parentValue = parentVenues.any((option) => option.id == form.parentId)
        ? form.parentId
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingMd,
          right: AppDimensions.spacingMd,
          top: AppDimensions.spacingMd,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              AppDimensions.spacingMd,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sheetHeight),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(color: colors.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEdit ? 'Edit Venue' : AppStrings.addVenue,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    _isEdit
                        ? 'Update venue details, pricing, status, and images.'
                        : 'Create a bookable venue, court, field, or room.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(.07),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                    ),
                    child: Column(
                      children: [
                        _SheetSwitchRow(
                          title: 'Active Status',
                          subtitle: 'Is this available for booking?',
                          value: form.isActive,
                          onChanged: isSaving ? null : _form.setActive,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  DropdownButtonFormField<String>(
                    initialValue: categoryValue,
                    items: [
                      for (final option in categories)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: isSaving
                        ? null
                        : (value) => _form.setCategory(value ?? ''),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  TextField(
                    controller: _nameController,
                    enabled: !isSaving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _durationController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Default Slot Duration (mins)',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (Per Slot)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lengthController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Length (ft)',
                            hintText: 'e.g. 100',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Expanded(
                        child: TextField(
                          controller: _widthController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Width (ft)',
                            hintText: 'e.g. 50',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _pickImages,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      form.images.isEmpty
                          ? 'Choose Venue Images'
                          : '${form.images.length} image${form.images.length == 1 ? '' : 's'} selected',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Upload pictures of this venue.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Divider(color: colors.border),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Custom Pricing & Duration Rules',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: isSaving ? null : _form.addPricingRule,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Rule'),
                      ),
                    ],
                  ),
                  Text(
                    'Override price or duration for specific dates/days.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  for (
                    var index = 0;
                    index < form.pricingRules.length;
                    index++
                  ) ...[
                    const SizedBox(height: AppDimensions.spacingMd),
                    _PricingRuleCard(
                      rule: form.pricingRules[index],
                      enabled: !isSaving,
                      onChanged: _form.refreshPricingRules,
                      onDelete: () => _form.removePricingRuleAt(index),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingMd),
                  _SheetSwitchRow(
                    title: 'This is a sub-section of another venue',
                    subtitle: 'Example: half-court or left field.',
                    value: form.isSubResource,
                    onChanged: isSaving ? null : _form.setSubResource,
                  ),
                  if (form.isSubResource) ...[
                    const SizedBox(height: AppDimensions.spacingMd),
                    DropdownButtonFormField<String>(
                      initialValue: parentValue,
                      items: [
                        for (final option in parentVenues)
                          DropdownMenuItem(
                            value: option.id,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: isSaving ? null : _form.setParent,
                      decoration: const InputDecoration(
                        labelText: 'Select Master Venue',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingXl),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: _isEdit ? 'Save Changes' : 'Save',
                      onPressed: isSaving ? null : _save,
                      isLoading: isSaving,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCategorySheet extends ConsumerStatefulWidget {
  const _AddCategorySheet({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_AddCategorySheet> createState() => _AddCategorySheetState();
}

final _isSavingCategoryProvider = StateProvider.autoDispose<bool>((_) => false);

class _AddCategorySheetState extends ConsumerState<_AddCategorySheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter a category name.');
      return;
    }

    ref.read(_isSavingCategoryProvider.notifier).state = true;
    final error = await ref
        .read(businessAdminActionControllerProvider)
        .createCategory(
          businessId: widget.businessId,
          name: name,
          description: _descriptionController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      ref.read(_isSavingCategoryProvider.notifier).state = false;
      _showMessage(error);
      return;
    }

    ref.invalidate(resourceCategoriesProvider(widget.businessId));
    await ref.read(resourceCategoriesProvider(widget.businessId).future);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category added successfully.')),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSaving = ref.watch(_isSavingCategoryProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingMd,
          right: AppDimensions.spacingMd,
          top: AppDimensions.spacingMd,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              AppDimensions.spacingMd,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Category',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              TextField(
                controller: _nameController,
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. full cricket ground',
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              TextField(
                controller: _descriptionController,
                enabled: !isSaving,
                minLines: 4,
                maxLines: 4,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Write a short description',
                  contentPadding: EdgeInsets.fromLTRB(
                    AppDimensions.spacingMd,
                    AppDimensions.spacingMd,
                    AppDimensions.spacingMd,
                    AppDimensions.spacingMd,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Save',
                  onPressed: isSaving ? null : _save,
                  isLoading: isSaving,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSwitchRow extends StatelessWidget {
  const _SheetSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PricingRuleCard extends StatelessWidget {
  const _PricingRuleCard({
    required this.rule,
    required this.enabled,
    required this.onChanged,
    required this.onDelete,
  });

  final _PricingRuleDraft rule;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: rule.type,
                  items: const [
                    DropdownMenuItem(value: 'DATE', child: Text('Date')),
                    DropdownMenuItem(value: 'DAY', child: Text('Day')),
                  ],
                  onChanged: enabled
                      ? (value) {
                          rule.type = value ?? 'DATE';
                          onChanged();
                        }
                      : null,
                  decoration: const InputDecoration(labelText: 'Rule Type'),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              IconButton(
                onPressed: enabled ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          TextField(
            controller: rule.valueController,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: 'Value',
              hintText: rule.type == 'DATE' ? 'yyyy-mm-dd' : 'e.g. Sunday',
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: rule.priceController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    hintText: 'e.g. 3000',
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: TextField(
                  controller: rule.durationController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    hintText: 'Optional',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PricingRuleDraft {
  String type = 'DATE';
  final valueController = TextEditingController();
  final priceController = TextEditingController();
  final durationController = TextEditingController();

  _PricingRuleDraft();

  factory _PricingRuleDraft.fromMap(Map<String, dynamic> data) {
    final draft = _PricingRuleDraft()
      ..type = data['type']?.toString() ?? 'DATE';
    draft.valueController.text = data['value']?.toString() ?? '';
    draft.priceController.text =
        (data['price'] ?? data['basePrice'])?.toString() ?? '';
    draft.durationController.text =
        (data['durationMinutes'] ?? data['duration'])?.toString() ?? '';
    return draft;
  }

  Map<String, dynamic> toPayload() {
    return {
      'type': type,
      'value': valueController.text.trim(),
      if (priceController.text.trim().isNotEmpty)
        'price': priceController.text.trim(),
      if (durationController.text.trim().isNotEmpty)
        'durationMinutes': durationController.text.trim(),
    };
  }

  void dispose() {
    valueController.dispose();
    priceController.dispose();
    durationController.dispose();
  }
}

class _SelectOption {
  const _SelectOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter({
    required this.lineColor,
    required this.gridColor,
    required this.points,
  });

  final Color lineColor;
  final Color gridColor;
  final List<BusinessChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 28;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) {
      return;
    }

    final maxRevenue = points
        .map((point) => point.revenue)
        .fold<num>(0, (max, revenue) => revenue > max ? revenue : max);
    final divisor = maxRevenue <= 0 ? 1.0 : maxRevenue.toDouble();
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final gap = points.length == 1 ? 0.0 : size.width / (points.length - 1);
    final path = Path();

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = points.length == 1 ? size.width / 2 : gap * index;
      final y =
          chartHeight -
          ((point.revenue.toDouble() / divisor) * (chartHeight * .78));
      final offset = Offset(x, y);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawCircle(offset, 4, dotPaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: point.name,
          style: TextStyle(color: gridColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
          (x - labelPainter.width / 2).clamp(
            0,
            size.width - labelPainter.width,
          ),
          chartHeight + 10,
        ),
      );
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.points != points;
  }
}

String _money(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _shortWeekday(DateTime date) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[date.weekday - 1];
}

String _adminDateLabel(DateTime date) {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final difference = date.difference(normalizedToday).inDays;
  if (difference == 0) {
    return AppStrings.today;
  }
  if (difference == 1) {
    return AppStrings.tomorrow;
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _resourceLabel(List<BusinessResource> resources, String resourceId) {
  for (final resource in resources) {
    if (resource.data['id']?.toString() == resourceId) {
      return _venueName(resource.data['name']?.toString() ?? AppStrings.venue);
    }
  }
  return AppStrings.venue;
}

String _nestedText(Map<String, dynamic> data, List<String> path) {
  Object? current = data;
  for (final key in path) {
    if (current is! Map<String, dynamic>) {
      return '';
    }
    current = current[key];
  }
  return current?.toString() ?? '';
}

bool _isUuidLike(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

List<_SelectOption> _categoryOptions(List<ResourceCategory> categories) {
  final options = <String, _SelectOption>{
    '': const _SelectOption(id: '', label: 'Uncategorized'),
  };

  for (final category in categories) {
    if (category.id.isEmpty || category.name.isEmpty) {
      continue;
    }

    options[category.id] = _SelectOption(id: category.id, label: category.name);
  }

  return options.values.toList();
}

List<_SelectOption> _parentVenueOptions(List<BusinessResource> resources) {
  return resources
      .where(
        (resource) => (resource.data['parentId']?.toString() ?? '').isEmpty,
      )
      .map(
        (resource) => _SelectOption(
          id: resource.data['id']?.toString() ?? '',
          label: _venueName(
            resource.data['name']?.toString() ?? AppStrings.venue,
          ),
        ),
      )
      .where((option) => option.id.isNotEmpty)
      .toList();
}

List<MyBooking> _filterAdminBookings(
  List<MyBooking> bookings, {
  required DateTime selectedDate,
  required String resourceId,
}) {
  final filtered = bookings.where((booking) {
    if (resourceId.isNotEmpty && booking.resourceId != resourceId) {
      return false;
    }

    final date = booking.firstSlotDate?.toLocal();
    if (date == null) {
      return false;
    }

    return _sameDate(date, selectedDate);
  }).toList();

  filtered.sort((left, right) {
    final leftDate =
        left.firstSlotDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate =
        right.firstSlotDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return leftDate.compareTo(rightDate);
  });
  return filtered;
}

String _adminBookingTimeLabel(MyBooking booking) {
  final starts = booking.bookedSlotStarts.map((slot) => slot.toLocal()).toList()
    ..sort();
  if (starts.isEmpty) {
    return AppStrings.notSelected;
  }

  return starts
      .map((start) {
        final end = start.add(Duration(minutes: booking.durationMinutes));
        return '${_timeLabel(start)} - ${_timeLabel(end)}';
      })
      .join(', ');
}

String _timeLabel(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}

String _venueName(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'l field' => 'Left Field',
    'r field' => 'Right Field',
    _ => value,
  };
}

// ---------------------------------------------------------------------------
// Monthly profit comparison
// ---------------------------------------------------------------------------

/// This month against last, built from two calls to the payments endpoint.
///
/// Collected and pending are shown side by side deliberately. The API counts a
/// payment as revenue only once it is `PAID`, so a month full of unsettled
/// bookings reports zero revenue — which reads as a broken dashboard unless the
/// money that *has* been booked is visible next to it.
class _ProfitComparisonPanel extends ConsumerWidget {
  const _ProfitComparisonPanel({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final state = ref.watch(monthlyProfitComparisonProvider);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.profitComparison,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.refresh,
                onPressed: () =>
                    ref.invalidate(businessPaymentsForMonthProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.spacing2xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
              child: AppEmptyState(
                message: error is Failure
                    ? error.message
                    : AppStrings.paymentsLoadError,
                icon: Icons.show_chart_rounded,
              ),
            ),
            data: (comparison) => _ProfitComparisonBody(
              comparison: comparison,
              currency: currency,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitComparisonBody extends StatelessWidget {
  const _ProfitComparisonBody({
    required this.comparison,
    required this.currency,
  });

  final MonthlyProfitComparison comparison;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lastDayOfCurrent = DateTime(
      comparison.currentMonth.year,
      comparison.currentMonth.month + 1,
      0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_dayMonthYear(comparison.currentMonth)}'
          ' - ${_dayMonthYear(lastDayOfCurrent)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        _ProfitDeltaHeadline(comparison: comparison, currency: currency),
        const SizedBox(height: AppDimensions.spacingLg),
        _ProfitBars(comparison: comparison, currency: currency),
        const SizedBox(height: AppDimensions.spacingLg),
        const _ProfitLegend(),
        if (comparison.currentRevenue == 0 &&
            comparison.currentPending > 0) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          _ProfitNote(
            message:
                '${AppStrings.pendingExplainer}'
                ' $currency ${_money(comparison.currentPending)} '
                '${AppStrings.pendingExplainerTail}',
          ),
        ],
      ],
    );
  }
}

/// The single number an owner is actually after: how this month's takings moved
/// against last month's.
class _ProfitDeltaHeadline extends StatelessWidget {
  const _ProfitDeltaHeadline({
    required this.comparison,
    required this.currency,
  });

  final MonthlyProfitComparison comparison;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final percent = comparison.revenueChangePercent;

    final Color deltaColor;
    final IconData deltaIcon;
    if (comparison.isFlat) {
      deltaColor = colors.textSecondary;
      deltaIcon = Icons.trending_flat_rounded;
    } else if (comparison.isUp) {
      deltaColor = colors.accent;
      deltaIcon = Icons.trending_up_rounded;
    } else {
      deltaColor = colors.error;
      deltaIcon = Icons.trending_down_rounded;
    }

    final direction = comparison.isUp
        ? AppStrings.moreThanLastMonth
        : AppStrings.lessThanLastMonth;

    // With no revenue last month a percentage is meaningless, so the change is
    // stated in money instead.
    final String label;
    if (comparison.isFlat) {
      label = AppStrings.noChangeVsLastMonth;
    } else if (percent == null) {
      label = '$currency ${_money(comparison.revenueChange.abs())} $direction';
    } else {
      label = '${percent.abs().toStringAsFixed(1)}% $direction';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(deltaIcon, color: deltaColor, size: 30),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$currency ${_money(comparison.currentRevenue)}',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: deltaColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two stacked bars, laid out rather than painted: heights come from flex
/// factors, so they scale with the panel and cannot overflow.
class _ProfitBars extends StatelessWidget {
  const _ProfitBars({required this.comparison, required this.currency});

  final MonthlyProfitComparison comparison;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Both bars share one scale, otherwise a quiet month would look identical
    // to a busy one.
    final peak = [
      comparison.currentBooked,
      comparison.previousBooked,
    ].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _ProfitBar(
              label: _monthName(comparison.previousMonth.month),
              year: comparison.previousMonth.year,
              collected: comparison.previousRevenue,
              pending: comparison.previousPending,
              peak: peak,
              currency: currency,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingLg),
          Expanded(
            child: _ProfitBar(
              label: _monthName(comparison.currentMonth.month),
              year: comparison.currentMonth.year,
              collected: comparison.currentRevenue,
              pending: comparison.currentPending,
              peak: peak,
              currency: currency,
              isCurrent: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitBar extends StatelessWidget {
  const _ProfitBar({
    required this.label,
    required this.year,
    required this.collected,
    required this.pending,
    required this.peak,
    required this.currency,
    this.isCurrent = false,
  });

  final String label;
  final int year;
  final num collected;
  final num pending;
  final num peak;
  final String currency;
  final bool isCurrent;

  /// Flex factors must be whole numbers, and a segment worth a fraction of the
  /// bar must still round to at least one row of pixels.
  static int _flex(num value) {
    final scaled = (value * 100).round();
    return scaled < 1 ? 1 : scaled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final total = collected + pending;

    // A month with nothing in it still gets a sliver, so the axis reads as a
    // bar chart rather than a blank gap.
    final heightFactor = peak <= 0
        ? 0.02
        : (total / peak).clamp(0.02, 1.0).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$currency ${_money(total)}',
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              widthFactor: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusSmall),
                ),
                child: total <= 0
                    ? ColoredBox(color: colors.border)
                    : Column(
                        children: [
                          if (pending > 0)
                            Expanded(
                              flex: _flex(pending),
                              child: const ColoredBox(color: _pendingColor),
                            ),
                          if (collected > 0)
                            Expanded(
                              flex: _flex(collected),
                              child: ColoredBox(color: colors.accent),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isCurrent ? colors.primary : colors.textSecondary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          year.toString(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

const _pendingColor = Color(0xFFD97706);

class _ProfitLegend extends StatelessWidget {
  const _ProfitLegend();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Wrap(
      spacing: AppDimensions.spacingLg,
      runSpacing: AppDimensions.spacingSm,
      children: [
        _ProfitLegendDot(color: colors.accent, label: AppStrings.collected),
        const _ProfitLegendDot(color: _pendingColor, label: AppStrings.pending),
      ],
    );
  }
}

class _ProfitLegendDot extends StatelessWidget {
  const _ProfitLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfitNote extends StatelessWidget {
  const _ProfitNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dates are shown day/month/year across the admin area.
String _dayMonthYear(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
