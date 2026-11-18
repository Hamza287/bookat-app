import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/my_booking.dart';
import '../providers/booking_providers.dart';

class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    final colors = context.appColors;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.myBookings)),
        body: SafeArea(
          child: bookings.when(
            loading: () => const _BookingsLoadingSkeleton(),
            error: (error, _) => AppEmptyState(
              message: error is Failure
                  ? error.message
                  : AppStrings.genericLoadError,
              icon: Icons.event_busy_rounded,
            ),
            data: (items) {
              final upcoming = items.where((item) => !item.isPast).toList();
              final past = items.where((item) => item.isPast).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.spacingXl,
                      AppDimensions.spacingXl,
                      AppDimensions.spacingXl,
                      AppDimensions.spacingMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppStrings.myBookings,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.near_me_rounded),
                              tooltip: AppStrings.bookNewVenue,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          AppStrings.myBookingsSubtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: colors.primary,
                    tabs: [
                      Tab(text: '${AppStrings.upcoming} (${upcoming.length})'),
                      Tab(text: '${AppStrings.past} (${past.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _BookingsList(bookings: upcoming),
                        _BookingsList(bookings: past),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  const _BookingsList({required this.bookings});

  final List<MyBooking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const AppEmptyState(
        message: AppStrings.noBookingsFound,
        icon: Icons.event_note_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.spacingLg),
      itemBuilder: (context, index) {
        return _BookingCard(booking: bookings[index]);
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final MyBooking booking;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(status: booking.status),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppStrings.totalPaid.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      booking.totalPaid,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing2xl),
            Text(
              booking.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _BookingInfoRow(
              icon: AppMaterialIcons.location,
              label: booking.resourceName,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _BookingTimePill(label: bookingSlotLabel(booking)),
            if (_isCancellable(booking)) ...[
              const SizedBox(height: AppDimensions.spacingLg),
              Divider(color: colors.border),
              const SizedBox(height: AppDimensions.spacingMd),
              _CancelBookingButton(booking: booking),
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether cancellation is worth offering at all. The venue's actual
/// cancellation policy is enforced server-side (see [BookingActionController.
/// cancelBooking]) — this is only a client-side gate against showing a Cancel
/// button on a booking that's already over or already settled.
bool _isCancellable(MyBooking booking) {
  if (booking.isPast) {
    return false;
  }
  final status = booking.status.toUpperCase();
  return status == 'PENDING' || status == 'CONFIRMED';
}

class _CancelBookingButton extends ConsumerWidget {
  const _CancelBookingButton({required this.booking});

  final MyBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(bookingCancellationLoadingProvider(booking.id));
    final colors = context.appColors;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : () => _confirmCancel(context, ref),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.error),
          foregroundColor: colors.error,
        ),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.error),
                ),
              )
            : const Icon(Icons.cancel_outlined, size: 18),
        label: Text(
          isLoading ? AppStrings.cancellingBooking : AppStrings.cancelBooking,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColors = dialogContext.appColors;

        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: const Text(AppStrings.cancelBookingTitle),
          content: const Text(AppStrings.cancelBookingMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.keepBooking),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(AppStrings.cancelBooking),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !context.mounted) {
      return;
    }

    final error = await ref
        .read(bookingActionControllerProvider)
        .cancelBooking(booking.id);

    if (!context.mounted) {
      return;
    }

    if (error != null) {
      // The server explains why — e.g. "Cancellation not allowed within 1 hours
      // of the booking time" — which is far more use than a generic refusal.
      AppTopAlert.show(context, error, isError: true);
      return;
    }

    ref.invalidate(myBookingsProvider);
    AppTopAlert.show(context, AppStrings.bookingCancelledSuccess);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

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
          status.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _BookingInfoRow extends StatelessWidget {
  const _BookingInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Icon(icon, color: colors.textSecondary, size: 20),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class _BookingTimePill extends StatelessWidget {
  const _BookingTimePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          children: [
            Icon(AppMaterialIcons.calendar, color: colors.primary, size: 20),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsLoadingSkeleton extends StatelessWidget {
  const _BookingsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      children: const [
        AppShimmerBox(width: 210, height: 36),
        SizedBox(height: AppDimensions.spacingSm),
        AppShimmerBox(width: 280, height: 20),
        SizedBox(height: AppDimensions.spacing2xl),
        AppShimmerBox(width: double.infinity, height: 240),
        SizedBox(height: AppDimensions.spacingLg),
        AppShimmerBox(width: double.infinity, height: 240),
      ],
    );
  }
}

/// The date and time(s) a booking covers, as one line.
///
/// Back-to-back slots read as a single stretch: booking 3–4 and 4–5 shows
/// "3:00 PM - 5:00 PM", not "3:00 PM - 4:00 PM, 4:00 PM - 5:00 PM". Slots with
/// a gap between them stay listed separately, since they really are two
/// separate periods.
String bookingSlotLabel(MyBooking booking) {
  final ranges = _slotRanges(booking);

  if (ranges.isEmpty) {
    final slots = booking.slots;
    return slots.isEmpty ? AppStrings.notSelected : slots.first;
  }

  final times = ranges
      .map((range) => '${_timeLabel(range.start)} - ${_timeLabel(range.end)}')
      .join(', ');

  return '${_dateLabel(ranges.first.start)} - $times';
}

/// The booking's slots collapsed into as few continuous periods as possible.
List<_SlotRange> _slotRanges(MyBooking booking) {
  final duration = Duration(minutes: booking.durationMinutes);
  final starts = booking.slots
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .map((slot) => slot.toLocal())
      .toList()
    ..sort();

  // The API sends either a list of slots or a plain start/end pair. Given a
  // pair there is nothing to merge — the booking already is one period, and
  // its own end time is more trustworthy than the venue's default slot length.
  if (starts.length < 2) {
    final start = booking.startDate?.toLocal() ?? starts.firstOrNull;
    if (start == null) {
      return const [];
    }
    return [_SlotRange(start, booking.endDate?.toLocal() ?? start.add(duration))];
  }

  final ranges = <_SlotRange>[];
  var rangeStart = starts.first;
  var rangeEnd = starts.first.add(duration);

  for (final start in starts.skip(1)) {
    // `!isAfter` rather than an equality check, so a duplicated or overlapping
    // slot folds into the run instead of splitting it.
    if (!start.isAfter(rangeEnd)) {
      final candidate = start.add(duration);
      if (candidate.isAfter(rangeEnd)) {
        rangeEnd = candidate;
      }
      continue;
    }

    ranges.add(_SlotRange(rangeStart, rangeEnd));
    rangeStart = start;
    rangeEnd = start.add(duration);
  }

  return [...ranges, _SlotRange(rangeStart, rangeEnd)];
}

class _SlotRange {
  const _SlotRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

String _dateLabel(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeLabel(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}
