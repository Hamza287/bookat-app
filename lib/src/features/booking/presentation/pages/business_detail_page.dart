import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/business.dart';
import '../../domain/entities/my_booking.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/slot_availability.dart';
import 'my_bookings_page.dart';
import '../providers/booking_providers.dart';
import '../widgets/business_image.dart';
import '../widgets/business_theme_scope.dart';

/// The booking-flow selections for a single [BusinessDetailPage] visit: which
/// venue, which date, which time slots. Kept in Riverpod so every callback that
/// changes one of these is a plain provider write.
final _selectedVenueIdProvider = StateProvider.autoDispose<String?>((_) => null);
final _selectedDateProvider =
    StateProvider.autoDispose<_DateOption>((_) => _dateOptionFor(DateTime.now()));
final _selectedTimesProvider =
    StateProvider.autoDispose<Set<String>>((_) => const <String>{});

class BusinessDetailPage extends ConsumerStatefulWidget {
  const BusinessDetailPage({required this.business, super.key});

  final Business business;

  @override
  ConsumerState<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends ConsumerState<BusinessDetailPage> {
  // The 7-day quick strip never changes after first build, so it stays a
  // plain computed field rather than provider state.
  late final List<_DateOption> _dates = _dateOptions();

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(businessDetailsProvider(widget.business.slug));

    // The venue's own booking-page colours, chosen by its owner in Business
    // Settings, apply from the moment we know them. The list copy carries a
    // theme too, so loading and error states are branded as well.
    return BusinessThemeScope(
      theme: details.valueOrNull?.settings.theme ??
          widget.business.settings.theme,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.appColors.background,
          body: details.when(
            loading: () => _BusinessDetailLoading(business: widget.business),
            error: (error, _) => _BusinessDetailError(
              business: widget.business,
              message:
                  error is Failure ? error.message : AppStrings.genericLoadError,
            ),
            data: _buildDetails,
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(Business business) {
    final colors = context.appColors;
    final venues = _venueOptions(business);
    final isSubmitting = ref.watch(bookingSubmissionLoadingProvider);
    final selectedVenueId = ref.watch(_selectedVenueIdProvider);
    final selectedDate = ref.watch(_selectedDateProvider);
    final selectedTimes = ref.watch(_selectedTimesProvider);

    // Nothing is pre-selected: the date and slot pickers only appear once the
    // customer has actually picked a venue.
    final selectedVenue = _selectedVenue(venues, selectedVenueId);

    void selectVenue(String venueId) {
      ref.read(_selectedVenueIdProvider.notifier).state = venueId;
      ref.read(_selectedTimesProvider.notifier).state = const <String>{};
    }

    return CustomScrollView(
      slivers: [
        _BusinessHero(business: business),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingXl,
            AppDimensions.spacing2xl,
            AppDimensions.spacingXl,
            AppDimensions.spacing3xl,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _DetailSectionTitle(
                  step: '1',
                  title: AppStrings.selectVenueCourt,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                _VenueSelector(
                  venues: venues,
                  selectedVenueId: selectedVenueId,
                  onChanged: selectVenue,
                ),
                const SizedBox(height: AppDimensions.spacing3xl),
                if (selectedVenue == null)
                  const _AwaitingVenuePrompt()
                else ...[
                  _DetailSectionTitle(
                    step: '2',
                    title: AppStrings.chooseDateTime,
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  _DateSelector(
                    dates: _dates,
                    selectedDate: selectedDate,
                    onChanged: (date) {
                      ref.read(_selectedDateProvider.notifier).state = date;
                      ref.read(_selectedTimesProvider.notifier).state =
                          const <String>{};
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Text(
                    AppStrings.availableSlots,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  _AvailabilitySlots(
                    resourceId: selectedVenue.id,
                    date: selectedDate.apiValue,
                    durationMinutes: selectedVenue.durationMinutes,
                    selectedTimes: selectedTimes,
                    onToggle: (time) {
                      final updated = {...selectedTimes};
                      if (!updated.remove(time)) {
                        updated.add(time);
                      }
                      ref.read(_selectedTimesProvider.notifier).state = updated;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacing2xl),
                  _BookingSummary(
                    selectedVenue: selectedVenue,
                    selectedDate: selectedDate,
                    selectedTimes: selectedTimes.toList(growable: false),
                    isSubmitting: isSubmitting,
                    onCheckout: selectedTimes.isEmpty
                        ? null
                        : () => _createBooking(
                              venue: selectedVenue,
                              date: selectedDate,
                              times: selectedTimes,
                            ),
                  ),
                ],
                const SizedBox(height: AppDimensions.spacing3xl),
                _ReviewsSection(businessId: business.id),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _VenueOption? _selectedVenue(List<_VenueOption> venues, String? selectedVenueId) {
    for (final venue in venues) {
      if (venue.id == selectedVenueId) {
        return venue;
      }
    }
    return null;
  }

  Future<void> _createBooking({
    required _VenueOption venue,
    required _DateOption date,
    required Set<String> times,
  }) async {
    if (times.isEmpty) {
      _showMessage(AppStrings.selectSlotFirst, isError: true);
      return;
    }

    final slots = times
        .map((time) => _slotIso(date.value, time))
        .toList(growable: false)
      ..sort();
    final error = await ref.read(bookingActionControllerProvider).createBooking(
          resourceId: venue.id,
          slots: slots,
        );

    if (!mounted) {
      return;
    }

    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    ref.invalidate(myBookingsProvider);
    ref.invalidate(
      availabilityProvider(
        AvailabilityRequest(
          resourceId: venue.id,
          date: date.apiValue,
          tzOffset: _timezoneOffsetMinutes(),
        ),
      ),
    );
    await _showTopSuccess(AppStrings.bookingCreated);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MyBookingsPage()),
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

  Future<void> _showTopSuccess(String message) async {
    final overlay = Overlay.of(context);
    final colors = context.appColors;
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + AppDimensions.spacingMd,
          left: AppDimensions.spacingLg,
          right: AppDimensions.spacingLg,
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: colors.textOnPrimary),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textOnPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    entry.remove();
  }
}

class _BusinessHero extends StatelessWidget {
  const _BusinessHero({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SliverAppBar(
      expandedHeight: 330,
      pinned: true,
      stretch: true,
      backgroundColor: colors.surface,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Row(
        children: [
          BusinessLogo(
            logoUrl: business.logoUrl,
            fallbackText: business.name,
            size: 34,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              business.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            BusinessCoverImage(
              coverUrl: business.coverUrl,
              logoUrl: business.logoUrl,
              fallbackText: business.name,
              height: 330,
              borderRadius: BorderRadius.zero,
              showLogoOverlay: false,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withOpacity(0.12),
                    colors.background.withOpacity(0.92),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingXl,
                  AppDimensions.spacingXl,
                  AppDimensions.spacingXl,
                  AppDimensions.spacing3xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BusinessLogo(
                      logoUrl: business.logoUrl,
                      fallbackText: business.name,
                      size: 86,
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    Text(
                      business.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppMaterialIcons.location,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Flexible(
                          child: Text(
                            business.city.isEmpty ? business.address : business.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessDetailLoading extends StatelessWidget {
  const _BusinessDetailLoading({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _BusinessHero(business: business),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingXl,
            AppDimensions.spacing2xl,
            AppDimensions.spacingXl,
            AppDimensions.spacing3xl,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              const [
                AppShimmerBox(width: 220, height: 30),
                SizedBox(height: AppDimensions.spacingLg),
                AppShimmerBox(width: double.infinity, height: 72),
                SizedBox(height: AppDimensions.spacingMd),
                AppShimmerBox(width: double.infinity, height: 72),
                SizedBox(height: AppDimensions.spacing3xl),
                AppShimmerBox(width: 210, height: 30),
                SizedBox(height: AppDimensions.spacingLg),
                AppShimmerBox(width: double.infinity, height: 86),
                SizedBox(height: AppDimensions.spacingLg),
                AppShimmerBox(width: 160, height: 24),
                SizedBox(height: AppDimensions.spacingMd),
                AppShimmerBox(width: double.infinity, height: 160),
                SizedBox(height: AppDimensions.spacing2xl),
                AppShimmerBox(width: double.infinity, height: 260),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessDetailError extends StatelessWidget {
  const _BusinessDetailError({
    required this.business,
    required this.message,
  });

  final Business business;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _BusinessHero(business: business),
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            message: message,
            icon: Icons.error_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle({required this.step, required this.title});

  final String step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: colors.primaryLight,
          child: Text(
            step,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder that stands in for step 2 until a venue has been picked.
class _AwaitingVenuePrompt extends StatelessWidget {
  const _AwaitingVenuePrompt();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 34,
            color: colors.textSecondary,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            AppStrings.selectVenueToContinue,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            AppStrings.selectVenueToContinueHint,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VenueSelector extends StatelessWidget {
  const _VenueSelector({
    required this.venues,
    required this.selectedVenueId,
    required this.onChanged,
  });

  final List<_VenueOption> venues;
  final String? selectedVenueId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 620;
        if (!useGrid) {
          return Column(
            children: [
              for (final venue in venues) ...[
                _VenueTile(
                  venue: venue,
                  isSelected: venue.id == selectedVenueId,
                  onTap: () => onChanged(venue.id),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
              ],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: venues.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppDimensions.spacingMd,
            mainAxisSpacing: AppDimensions.spacingMd,
            childAspectRatio: 3.4,
          ),
          itemBuilder: (context, index) {
            final venue = venues[index];
            return _VenueTile(
              venue: venue,
              isSelected: venue.id == selectedVenueId,
              onTap: () => onChanged(venue.id),
            );
          },
        );
      },
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({
    required this.venue,
    required this.isSelected,
    required this.onTap,
  });

  final _VenueOption venue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: isSelected ? colors.primaryLight : colors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                venue.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                venue.priceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.dates,
    required this.selectedDate,
    required this.onChanged,
  });

  final List<_DateOption> dates;
  final _DateOption selectedDate;
  final ValueChanged<_DateOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // If the customer picked a date from the calendar that isn't one of the
    // quick 7, pin it at the front so it's still visibly selected rather than
    // scrolled out of a strip that never included it.
    final isCustomSelection =
        !dates.any((date) => date.value == selectedDate.value);
    final displayDates = isCustomSelection ? [selectedDate, ...dates] : dates;

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayDates.length + 1,
        separatorBuilder: (_, _) => const SizedBox(
          width: AppDimensions.spacingMd,
        ),
        itemBuilder: (context, index) {
          if (index == displayDates.length) {
            return _CalendarPickerTile(
              selectedDate: selectedDate.value,
              onPicked: onChanged,
            );
          }

          final date = displayDates[index];
          final isSelected = date.value == selectedDate.value;

          return Material(
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: InkWell(
              onTap: () => onChanged(date),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: Container(
                width: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date.weekday,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isSelected
                                ? colors.textOnPrimary
                                : colors.textSecondary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      date.day,
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

class _CalendarPickerTile extends StatelessWidget {
  const _CalendarPickerTile({
    required this.selectedDate,
    required this.onPicked,
  });

  final DateTime selectedDate;
  final ValueChanged<_DateOption> onPicked;

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
          width: 74,
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
    final firstSelectable = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(firstSelectable)
          ? firstSelectable
          : selectedDate,
      // No date before today is selectable — bookings can't be made in the
      // past.
      firstDate: firstSelectable,
      lastDate: firstSelectable.add(const Duration(days: 365)),
    );

    if (picked != null) {
      onPicked(_dateOptionFor(picked));
    }
  }
}

class _AvailabilitySlots extends ConsumerWidget {
  const _AvailabilitySlots({
    required this.resourceId,
    required this.date,
    required this.durationMinutes,
    required this.selectedTimes,
    required this.onToggle,
  });

  final String? resourceId;
  final String date;
  final int durationMinutes;
  final Set<String> selectedTimes;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (resourceId == null || resourceId!.isEmpty) {
      return const AppEmptyState(message: AppStrings.notSelected);
    }

    final request = AvailabilityRequest(
      resourceId: resourceId!,
      date: date,
      tzOffset: _timezoneOffsetMinutes(),
    );
    final slots = ref.watch(availabilityProvider(request));

    return slots.when(
      loading: () => const _SlotLoadingSkeleton(),
      error: (error, _) => AppEmptyState(
        message: error is Failure ? error.message : AppStrings.genericLoadError,
      ),
      data: (slots) {
        final bookedTimes = _bookedTimesFor(
          ref.watch(myBookingsProvider).valueOrNull ?? const [],
          resourceId!,
          date,
        );
        final mergedSlots = _mergeBookedSlots(slots, bookedTimes);

        if (mergedSlots.isEmpty) {
          return const AppEmptyState(message: AppStrings.noSlotsAvailable);
        }

        return _SlotGrid(
          slots: mergedSlots,
          durationMinutes: durationMinutes,
          selectedTimes: selectedTimes,
          bookedTimes: bookedTimes,
          onToggle: onToggle,
        );
      },
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.durationMinutes,
    required this.selectedTimes,
    required this.bookedTimes,
    required this.onToggle,
  });

  final List<SlotAvailability> slots;
  final int durationMinutes;
  final Set<String> selectedTimes;
  final Set<String> bookedTimes;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      // A start -> end range ("09:00 AM - 10:00 AM") needs materially more
      // width than a single time did, hence 2 columns rather than 3.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimensions.spacingSm,
        mainAxisSpacing: AppDimensions.spacingSm,
        childAspectRatio: 3.2,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final slotKey = _slotKey(slot.time);
        final isSelected = selectedTimes.map(_slotKey).contains(slotKey);
        final isBookedByUser = bookedTimes.map(_slotKey).contains(slotKey);
        return _SlotTile(
          // The start time still drives selection/booking keys — only the
          // displayed label becomes a range.
          label: _slotRangeLabel(slot.time, durationMinutes),
          isAvailable: slot.available,
          isSelected: isSelected,
          isBookedByUser: isBookedByUser,
          onTap: () => onToggle(slot.time),
        );
      },
    );
  }
}

class _SlotLoadingSkeleton extends StatelessWidget {
  const _SlotLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimensions.spacingSm,
        mainAxisSpacing: AppDimensions.spacingSm,
        childAspectRatio: 3.2,
      ),
      itemBuilder: (_, _) => const AppShimmerBox(height: 44),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.isAvailable,
    required this.isSelected,
    required this.isBookedByUser,
    required this.onTap,
  });

  final String label;
  final bool isAvailable;
  final bool isSelected;
  final bool isBookedByUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: isBookedByUser
          ? colors.primaryLight
          : isSelected
          ? colors.primary
          : isAvailable
              ? colors.surface
              : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: isAvailable && !isBookedByUser ? onTap : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isBookedByUser || isSelected ? colors.primary : colors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingXs,
                ),
                // The range label ("09:00 AM - 10:00 AM") is longer than a
                // single time and must never be cut — scale it down rather
                // than truncate the end time the whole point is to show.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? colors.textOnPrimary
                              : isBookedByUser || isAvailable
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                          fontWeight: FontWeight.w900,
                          decoration: isAvailable || isBookedByUser
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                  ),
                ),
              ),
              if (isBookedByUser) ...[
                const SizedBox(height: 2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSm,
                      vertical: 1,
                    ),
                    child: Text(
                      AppStrings.booked,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textOnPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.selectedVenue,
    required this.selectedDate,
    required this.selectedTimes,
    required this.isSubmitting,
    required this.onCheckout,
  });

  final _VenueOption? selectedVenue;
  final _DateOption selectedDate;
  final List<String> selectedTimes;
  final bool isSubmitting;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sortedTimes = [...selectedTimes]..sort(_compareTimeLabels);
    final total = _totalLabel(selectedVenue, sortedTimes.length);
    final durationMinutes = selectedVenue?.durationMinutes ?? 60;
    final rangeLabels = sortedTimes
        .map((time) => _slotRangeLabel(time, durationMinutes))
        .toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
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
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.bookingSummary,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _SummaryRow(
              icon: AppMaterialIcons.location,
              label: AppStrings.venue,
              value: selectedVenue?.name ?? AppStrings.notSelected,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _SummaryRow(
              icon: AppMaterialIcons.calendar,
              label: AppStrings.dateTime,
              value: rangeLabels.isEmpty
                  ? selectedDate.summaryLabel
                  : '${selectedDate.summaryLabel} at ${rangeLabels.join(', ')}',
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.totalAmount,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Text(
                      total,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            AppButton(
              label: AppStrings.continueToCheckout,
              onPressed: isSubmitting ? null : onCheckout,
              isLoading: isSubmitting,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colors.primaryLight,
          child: Icon(icon, color: colors.primary, size: 20),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final reviews = ref.watch(businessReviewsProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, color: colors.accent),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                AppStrings.customerReviews,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => _openWriteReview(context, ref),
              child: const Text(AppStrings.writeReview),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        reviews.when(
          loading: () => const _ReviewsLoading(),
          error: (error, _) => _ReviewsError(
            message: error is Failure ? error.message : AppStrings.reviewsLoadError,
          ),
          data: (data) =>
              data.isEmpty ? const _NoReviewsPanel() : _ReviewsList(reviews: data),
        ),
        const SizedBox(height: AppDimensions.spacing2xl),
        Center(
          child: Text.rich(
            TextSpan(
              text: '${AppStrings.poweredBy} ',
              style: TextStyle(color: colors.textSecondary),
              children: [
                TextSpan(
                  text: AppStrings.appName,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openWriteReview(BuildContext context, WidgetRef ref) {
    final signedIn = ref.read(authControllerProvider).valueOrNull != null;
    if (!signedIn) {
      final colors = context.appColors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.signInToReview),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.appColors.surface,
      builder: (_) => _WriteReviewSheet(businessId: businessId),
    );
  }
}

class _ReviewsLoading extends StatelessWidget {
  const _ReviewsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppShimmerBox(width: double.infinity, height: 84),
        SizedBox(height: AppDimensions.spacingMd),
        AppShimmerBox(width: double.infinity, height: 84),
      ],
    );
  }
}

class _ReviewsError extends StatelessWidget {
  const _ReviewsError({required this.message});

  final String message;

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
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.error),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Text(message, style: TextStyle(color: colors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoReviewsPanel extends StatelessWidget {
  const _NoReviewsPanel();

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingXl,
          vertical: AppDimensions.spacing3xl,
        ),
        child: Column(
          children: [
            Icon(
              Icons.star_border_rounded,
              color: colors.textSecondary,
              size: 52,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              AppStrings.noReviewsYet,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              AppStrings.firstReview,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final average = reviews.map((review) => review.rating).reduce((a, b) => a + b) /
        reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, color: colors.accent, size: 22),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              average.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              '(${reviews.length})',
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        for (final review in reviews) ...[
          _ReviewCard(review: review),
          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _StarRow(rating: review.rating, color: colors.accent, size: 16),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                review.comment,
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.color, this.size = 20});

  final int rating;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: color,
            size: size,
          ),
      ],
    );
  }
}

/// Draft state for the write-a-review sheet. `.autoDispose` (non-family) is
/// fine here since only one review sheet is ever open at a time — it opens
/// via `showModalBottomSheet`, which is inherently modal.
final _reviewSelectedBookingIdProvider = StateProvider.autoDispose<String?>((_) => null);
final _reviewRatingProvider = StateProvider.autoDispose<int>((_) => 0);
final _reviewValidationErrorProvider = StateProvider.autoDispose<String?>((_) => null);

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.businessId});

  final String businessId;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<MyBooking> eligibleBookings) async {
    final bookingId =
        ref.read(_reviewSelectedBookingIdProvider) ?? eligibleBookings.first.id;
    final rating = ref.read(_reviewRatingProvider);

    if (rating == 0) {
      ref.read(_reviewValidationErrorProvider.notifier).state =
          AppStrings.selectRatingValidation;
      return;
    }
    ref.read(_reviewValidationErrorProvider.notifier).state = null;

    final error = await ref.read(bookingActionControllerProvider).submitReview(
          businessId: widget.businessId,
          bookingId: bookingId,
          rating: rating,
          comment: _commentController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    final colors = context.appColors;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: colors.error),
      );
      return;
    }

    ref.invalidate(businessReviewsProvider(widget.businessId));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppStrings.reviewSubmittedSuccess),
        backgroundColor: colors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSubmitting = ref.watch(reviewSubmissionLoadingProvider);
    final eligible = ref.watch(eligibleReviewBookingsProvider(widget.businessId));
    final selectedBookingId = ref.watch(_reviewSelectedBookingIdProvider);
    final rating = ref.watch(_reviewRatingProvider);
    final validationError = ref.watch(_reviewValidationErrorProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.spacingXl,
        right: AppDimensions.spacingXl,
        top: AppDimensions.spacingLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.spacingXl,
      ),
      child: eligible.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => SizedBox(
          height: 120,
          child: Center(
            child: Text(
              error is Failure ? error.message : AppStrings.reviewsLoadError,
              style: TextStyle(color: colors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  AppStrings.noEligibleBookings,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            );
          }

          // Falls back to the first eligible booking for display purposes
          // only; `_submit` applies the identical fallback independently.
          final effectiveBookingId = selectedBookingId ?? bookings.first.id;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.writeReview,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              if (bookings.length > 1) ...[
                Text(
                  AppStrings.selectBookingToReview,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                DropdownButtonFormField<String>(
                  initialValue: effectiveBookingId,
                  isExpanded: true,
                  items: bookings
                      .map(
                        (booking) => DropdownMenuItem(
                          value: booking.id,
                          child: Text(
                            '${booking.resourceName} — ${_bookingDateLabel(booking)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      ref.read(_reviewSelectedBookingIdProvider.notifier).state = value,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
              ],
              Text(
                AppStrings.yourRating,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () {
                        ref.read(_reviewRatingProvider.notifier).state = i;
                        ref.read(_reviewValidationErrorProvider.notifier).state = null;
                      },
                      icon: Icon(
                        i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: colors.accent,
                        size: 32,
                      ),
                    ),
                ],
              ),
              if (validationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
                  child: Text(
                    validationError,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              Text(
                AppStrings.yourReview,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              TextField(
                controller: _commentController,
                maxLines: 4,
                textAlignVertical: TextAlignVertical.top,
                // The app's shared input theme uses a pill-shaped border
                // (radiusPill = 100) sized for single-line fields like the
                // search box and login form — on a 4-line box that shape reads
                // as broken, so this field uses a normal rounded rectangle.
                decoration: InputDecoration(
                  hintText: AppStrings.yourReviewHint,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                    borderSide: BorderSide(color: colors.primary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              AppButton(
                label: isSubmitting
                    ? AppStrings.submittingReview
                    : AppStrings.submitReview,
                isLoading: isSubmitting,
                isExpanded: true,
                onPressed: isSubmitting ? null : () => _submit(bookings),
              ),
            ],
          );
        },
      ),
    );
  }

  String _bookingDateLabel(MyBooking booking) {
    final date = booking.firstSlotDate?.toLocal();
    if (date == null) {
      return AppStrings.notSelected;
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _VenueOption {
  const _VenueOption({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.currency,
    required this.pricePerSlot,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final String priceLabel;
  final String currency;
  final num pricePerSlot;

  /// Length of a single slot. Drives the start -> end range shown for each
  /// available time and in the booking summary.
  final int durationMinutes;
}

class _DateOption {
  const _DateOption({
    required this.value,
    required this.weekday,
    required this.day,
    required this.summaryLabel,
  });

  final DateTime value;
  final String weekday;
  final String day;
  final String summaryLabel;

  String get apiValue => _apiDate(value);
}

List<_VenueOption> _venueOptions(Business business) {
  final options = business.resources.map((resource) {
    final data = resource.data;
    final id = _stringValue(data, ['id', 'resourceId', 'slug']);
    final name = _stringValue(data, ['name', 'title', 'label']);
    final price = _resourcePrice(data);

    return _VenueOption(
      id: id.isEmpty ? name : id,
      name: name.isEmpty ? AppStrings.venue : _venueName(name),
      currency: business.settings.currency,
      pricePerSlot: price,
      priceLabel: price <= 0
          ? business.settings.currency
          : '${business.settings.currency} ${_money(price)}/hr',
      durationMinutes: _durationMinutes(data),
    );
  }).toList(growable: false);

  if (options.isNotEmpty) {
    return options;
  }

  return [
    _VenueOption(
      id: business.id,
      name: business.name,
      priceLabel: business.settings.currency,
      currency: business.settings.currency,
      pricePerSlot: 0,
      durationMinutes: 60,
    ),
  ];
}

String _totalLabel(_VenueOption? venue, int slotCount) {
  if (venue == null || slotCount == 0) {
    return '--';
  }
  if (venue.pricePerSlot <= 0) {
    return venue.priceLabel;
  }

  final total = venue.pricePerSlot * slotCount;
  return '${venue.currency} ${_money(total)}';
}

String _money(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

List<_DateOption> _dateOptions() {
  final now = DateTime.now();

  return List.generate(7, (index) => _dateOptionFor(now.add(Duration(days: index))));
}

/// Shared by the 7-day quick strip and the calendar picker, so a date chosen
/// either way produces an identical, comparable `_DateOption`.
_DateOption _dateOptionFor(DateTime date) {
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  return _DateOption(
    value: DateTime(date.year, date.month, date.day),
    weekday: weekdays[date.weekday - 1],
    day: date.day.toString(),
    summaryLabel: _dateSummaryLabel(date),
  );
}

String _dateSummaryLabel(DateTime date) {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final difference = normalizedDate.difference(normalizedToday).inDays;

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

String _apiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

int _timezoneOffsetMinutes() {
  return DateTime.now().timeZoneOffset.inMinutes * -1;
}

Set<String> _bookedTimesFor(
  List<MyBooking> bookings,
  String resourceId,
  String apiDate,
) {
  final bookedTimes = <String>{};

  for (final booking in bookings) {
    final status = booking.status.toUpperCase();
    if (status == 'CANCELLED' || status == 'REJECTED_BY_SYSTEM') {
      continue;
    }
    if (booking.resourceId != resourceId) {
      continue;
    }

    final slotStarts = booking.bookedSlotStarts;
    if (slotStarts.isNotEmpty) {
      for (final slotStart in slotStarts) {
        final localSlot = slotStart.toLocal();
        if (_apiDate(localSlot) == apiDate) {
          bookedTimes.add(_slotLabelFromDateTime(localSlot));
        }
      }
      continue;
    }

    for (final slot in booking.slots) {
      final bookingDate = booking.firstSlotDate?.toLocal();
      if (bookingDate != null && _apiDate(bookingDate) != apiDate) {
        continue;
      }
      if (slot.trim().isNotEmpty) {
        bookedTimes.add(slot.trim());
      }
    }
  }

  return bookedTimes;
}

List<SlotAvailability> _mergeBookedSlots(
  List<SlotAvailability> slots,
  Set<String> bookedTimes,
) {
  final byTime = <String, SlotAvailability>{
    for (final slot in slots) _slotKey(slot.time): slot,
  };

  for (final time in bookedTimes) {
    byTime.putIfAbsent(
      _slotKey(time),
      () => SlotAvailability(time: time, available: false),
    );
  }

  return byTime.values.toList(growable: false)
    ..sort((left, right) => _compareTimeLabels(left.time, right.time));
}

String _slotIso(DateTime date, String timeLabel) {
  final parts = timeLabel.trim().split(RegExp(r'\s+'));
  if (parts.length != 2) {
    return date.toUtc().toIso8601String();
  }

  final timeParts = parts.first.split(':');
  if (timeParts.length != 2) {
    return date.toUtc().toIso8601String();
  }

  var hour = int.tryParse(timeParts.first) ?? 0;
  final minute = int.tryParse(timeParts.last) ?? 0;
  final period = parts.last.toUpperCase();

  if (period == 'PM' && hour != 12) {
    hour += 12;
  }
  if (period == 'AM' && hour == 12) {
    hour = 0;
  }

  final localDateTime = DateTime(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  );

  return localDateTime.toUtc().toIso8601String();
}

String _slotLabelFromDateTime(DateTime dateTime) {
  final hour12 = dateTime.hour == 0
      ? 12
      : dateTime.hour > 12
          ? dateTime.hour - 12
          : dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${hour12.toString().padLeft(2, '0')}:$minute $period';
}

int _compareTimeLabels(String left, String right) {
  return _minutesFromTimeLabel(left).compareTo(_minutesFromTimeLabel(right));
}

String _slotKey(String timeLabel) {
  return _minutesFromTimeLabel(timeLabel).toString();
}

int _minutesFromTimeLabel(String timeLabel) {
  final parts = timeLabel.trim().split(RegExp(r'\s+'));
  if (parts.length != 2) {
    return 0;
  }

  final timeParts = parts.first.split(':');
  if (timeParts.length != 2) {
    return 0;
  }

  var hour = int.tryParse(timeParts.first) ?? 0;
  final minute = int.tryParse(timeParts.last) ?? 0;
  final period = parts.last.toUpperCase();

  if (period == 'PM' && hour != 12) {
    hour += 12;
  }
  if (period == 'AM' && hour == 12) {
    hour = 0;
  }

  return hour * 60 + minute;
}

String _stringValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }

  return '';
}

/// Slot length in minutes. The API nests this under `attributes` (e.g.
/// `resource.attributes.durationMinutes`, sometimes a string rather than an
/// int) alongside a bare top-level fallback; 60 minutes if neither is set.
int _durationMinutes(Map<String, dynamic> data) {
  final direct = int.tryParse(_stringValue(data, ['durationMinutes']));
  if (direct != null && direct > 0) {
    return direct;
  }

  final attributes = data['attributes'];
  if (attributes is Map<String, dynamic>) {
    final nested = int.tryParse(_stringValue(attributes, ['durationMinutes']));
    if (nested != null && nested > 0) {
      return nested;
    }
  }

  return 60;
}

/// The resource's per-slot price. `num.tryParse` silently returns `null` (and
/// therefore a price of 0) if the API sends the number formatted — a
/// thousands separator ("3,500"), a currency prefix ("PKR 3500"), or a unit
/// suffix — or nests it under `attributes` instead of the top level. Any of
/// these would show as a real venue with no calculable price, which is why
/// this strips non-numeric formatting and checks both locations before
/// giving up.
num _resourcePrice(Map<String, dynamic> data) {
  final direct = _cleanedNum(data, ['basePrice', 'price', 'hourlyRate', 'rate', 'amount']);
  if (direct != null) {
    return direct;
  }

  final attributes = data['attributes'];
  if (attributes is Map<String, dynamic>) {
    final nested = _cleanedNum(
      attributes,
      ['basePrice', 'price', 'hourlyRate', 'rate', 'amount'],
    );
    if (nested != null) {
      return nested;
    }
  }

  return 0;
}

num? _cleanedNum(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) {
      continue;
    }
    if (value is num) {
      return value;
    }

    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) {
      continue;
    }
    final parsed = num.tryParse(cleaned);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

/// Renders a single slot's start time as a start -> end range, e.g.
/// `09:00 AM - 10:00 AM`, using the venue's slot duration. [startLabel] is
/// the "hh:mm AM/PM" string the API returns for the slot's start time.
String _slotRangeLabel(String startLabel, int durationMinutes) {
  final startMinutes = _minutesFromTimeLabel(startLabel);
  final endMinutes = (startMinutes + durationMinutes) % (24 * 60);
  return '${_formatMinutesLabel(startMinutes)} - ${_formatMinutesLabel(endMinutes)}';
}

String _formatMinutesLabel(int totalMinutes) {
  final hour = (totalMinutes ~/ 60) % 24;
  final minute = totalMinutes % 60;
  final hour12 = hour == 0
      ? 12
      : hour > 12
          ? hour - 12
          : hour;
  final period = hour >= 12 ? 'PM' : 'AM';
  return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

String _venueName(String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    'l field' || 'l court' || 'left' || 'left field' || 'left court' =>
      'Left Field',
    'r field' || 'r court' || 'right' || 'right field' || 'right court' =>
      'Right Field',
    'full' || 'full field' || 'full court' || 'ground' || 'full ground' =>
      'Full Ground',
    _ => value
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          return '${word.substring(0, 1).toUpperCase()}${word.substring(1)}';
        })
        .join(' '),
  };
}
