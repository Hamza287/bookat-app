import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependency_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/domain/entities/business.dart';
import '../../../booking/domain/entities/my_booking.dart';
import '../../domain/entities/business_payment.dart';
import '../../domain/entities/business_stats.dart';
import '../../domain/entities/holiday_booking_check.dart';
import '../../domain/entities/resource_category.dart';
import '../../domain/entities/schedule_exception.dart';

/// The business currently being administered.
///
/// Seeded from the signed-in user's session, then replaced by the server's
/// response after every settings save â€” otherwise the whole admin area would
/// keep rendering the stale copy captured at login.
final activeBusinessProvider =
    NotifierProvider<ActiveBusinessController, Business?>(
  ActiveBusinessController.new,
);

class ActiveBusinessController extends Notifier<Business?> {
  @override
  Business? build() {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final owned = session?.user.ownedBusinesses ?? const <Business>[];
    return owned.isEmpty ? null : owned.first;
  }

  void update(Business business) => state = business;
}

final businessStatsProvider = FutureProvider<BusinessStats>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  final business = ref.watch(activeBusinessProvider);
  if (session == null || business == null) {
    throw const UnexpectedFailure(
      message: 'Please sign in again to view business stats.',
    );
  }

  final useCase = ref.watch(getBusinessStatsProvider);
  // `/businesses/:id/stats` is keyed by business, not owner. Passing the user
  // id silently returns an all-zero payload instead of failing.
  final result = await useCase(
    businessId: business.id,
    accessToken: session.accessToken,
  );

  return switch (result) {
    Success(data: final stats) => stats,
    Fail(failure: final failure) => throw failure,
  };
});

final businessBookingsProvider =
    FutureProvider.family<List<MyBooking>, String>((ref, businessId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const UnexpectedFailure(
      message: 'Please sign in again to view business bookings.',
    );
  }

  final useCase = ref.watch(getBusinessBookingsProvider);
  final result = await useCase(
    businessId: businessId,
    accessToken: session.accessToken,
  );

  return switch (result) {
    Success(data: final bookings) => bookings,
    Fail(failure: final failure) => throw failure,
  };
});

final businessResourcesProvider =
    FutureProvider.family<List<BusinessResource>, String>((ref, businessId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const UnexpectedFailure(
      message: 'Please sign in again to view business venues.',
    );
  }

  final useCase = ref.watch(getBusinessResourcesProvider);
  final result = await useCase(
    businessId: businessId,
    accessToken: session.accessToken,
  );

  return switch (result) {
    Success(data: final resources) => resources,
    Fail(failure: final failure) => throw failure,
  };
});

final resourceCategoriesProvider =
    FutureProvider.family<List<ResourceCategory>, String>((ref, businessId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const UnexpectedFailure(
      message: 'Please sign in again to view venue categories.',
    );
  }

  final useCase = ref.watch(getResourceCategoriesProvider);
  final result = await useCase(
    businessId: businessId,
    accessToken: session.accessToken,
  );

  return switch (result) {
    Success(data: final categories) => categories,
    Fail(failure: final failure) => throw failure,
  };
});

final scheduleExceptionsProvider = FutureProvider.family<
    List<ScheduleException>, String>((ref, businessId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const UnexpectedFailure(
      message: 'Please sign in again to view schedule exceptions.',
    );
  }

  final useCase = ref.watch(getScheduleExceptionsProvider);
  final result = await useCase(
    businessId: businessId,
    accessToken: session.accessToken,
  );

  return switch (result) {
    Success(data: final exceptions) => exceptions,
    Fail(failure: final failure) => throw failure,
  };
});

/// The month the payments screen is showing, as its first day. The endpoint is
/// range-filtered, so the month is part of the request rather than a client-side
/// filter over an unbounded list.
final paymentsMonthProvider = StateProvider.autoDispose<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Payments for one calendar month, keyed by that month's first day.
///
/// Keyed rather than tied to the selected month so several months can be in
/// flight at once — the profit comparison needs two of them side by side, and
/// this way the month the owner is already looking at is served from cache.
final businessPaymentsForMonthProvider = AsyncNotifierProvider.autoDispose
    .family<BusinessPaymentsNotifier, BusinessPayments, DateTime>(
  BusinessPaymentsNotifier.new,
);

/// A notifier rather than a plain future, so settling a payment can change the
/// rows on screen without re-fetching the month.
///
/// Invalidating sent the whole tab back through its loading state, which read
/// as the entire screen flashing to settle one row.
class BusinessPaymentsNotifier
    extends AutoDisposeFamilyAsyncNotifier<BusinessPayments, DateTime> {
  @override
  Future<BusinessPayments> build(DateTime month) => _fetch(month);

  Future<BusinessPayments> _fetch(DateTime month) async {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final business = ref.watch(activeBusinessProvider);
    if (session == null || business == null) {
      throw const UnexpectedFailure(
        message: 'Please sign in again to view payments.',
      );
    }

    // Day 0 of the following month is the last day of this one, which keeps
    // 28/29/30/31-day months correct without a lookup table.
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final result = await ref.watch(getBusinessPaymentsProvider)(
      businessId: business.id,
      accessToken: session.accessToken,
      startDate: DateTime(month.year, month.month),
      endDate: lastDay,
    );

    return switch (result) {
      Success(data: final payments) => payments,
      Fail(failure: final failure) => throw failure,
    };
  }

  /// Marks [paymentIds] settled in the rows already on screen.
  ///
  /// Only the affected cards rebuild; the list, the month switcher and the
  /// stats panel stay exactly as they are.
  void applySettled({
    required Set<String> paymentIds,
    required String status,
    String? method,
  }) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.withSettled(
        paymentIds: paymentIds,
        status: status,
        method: method,
      ),
    );
  }

  /// Re-reads the month without passing through a loading state.
  ///
  /// Used after [applySettled] to pick up the server-computed stats. A failure
  /// is swallowed on purpose: the rows are already right, and replacing the
  /// screen with an error because a background reconcile failed would be worse
  /// than slightly stale totals.
  Future<void> refreshQuietly() async {
    try {
      state = AsyncData(await _fetch(arg));
    } catch (_) {
      // Keep what is on screen.
    }
  }
}

/// First day of the month the payments tab is bound to, as the family key.
///
/// Screens watch [businessPaymentsForMonthProvider] with this directly. An
/// earlier `businessPaymentsProvider` wrapped it in a second `FutureProvider`
/// that awaited `.future`, and that indirection was why settling a payment
/// flashed the whole screen: each time the notifier emitted, the wrapper
/// re-ran and published an `AsyncLoading` of its own, so the tab rendered its
/// skeleton even though the notifier had never left `AsyncData`.
DateTime paymentsMonthKey(DateTime month) {
  return DateTime(month.year, month.month);
}

/// This month's takings against last month's.
///
/// Both months are fetched together rather than sequentially — one is not
/// needed to request the other, and awaiting them in turn would double the
/// time the dashboard sits on a spinner.
final monthlyProfitComparisonProvider =
    FutureProvider.autoDispose<MonthlyProfitComparison>((ref) async {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  // Month 0 rolls back into December of the previous year on its own.
  final lastMonth = DateTime(now.year, now.month - 1);

  final results = await Future.wait([
    ref.watch(businessPaymentsForMonthProvider(thisMonth).future),
    ref.watch(businessPaymentsForMonthProvider(lastMonth).future),
  ]);

  return MonthlyProfitComparison(
    currentMonth: thisMonth,
    previousMonth: lastMonth,
    current: results[0].stats,
    previous: results[1].stats,
  );
});

final businessAdminActionControllerProvider =
    Provider<BusinessAdminActionController>((ref) {
  return BusinessAdminActionController(ref);
});

class BusinessAdminActionController {
  const BusinessAdminActionController(this._ref);

  final Ref _ref;

  /// Saves the business profile. [settings] must already be a full, merged
  /// settings object â€” see [BusinessAdminRepository.updateBusiness].
  Future<String?> saveBusinessDetails({
    required String name,
    required String slug,
    required String city,
    required String address,
    required BusinessSettings settings,
    String? logoPath,
    String? coverPath,
  }) async {
    return _guard((session, business) async {
      final result = await _ref.read(updateBusinessProvider)(
        businessId: business.id,
        accessToken: session.accessToken,
        name: name,
        slug: slug,
        city: city,
        address: address,
        settings: settings,
        logoPath: logoPath,
        coverPath: coverPath,
      );

      return _applyBusiness(result);
    }, 'Please sign in again to change these settings.');
  }

  Future<String?> saveOperatingHours(
    List<BusinessOperatingHour> operatingHours,
  ) async {
    return _guard((session, business) async {
      final result = await _ref.read(updateOperatingHoursProvider)(
        businessId: business.id,
        accessToken: session.accessToken,
        operatingHours: operatingHours,
      );

      return _applyBusiness(result);
    }, 'Please sign in again to change your operating hours.');
  }

  Future<Result<HolidayBookingCheck>> checkHolidayBookings({
    required DateTime date,
    required DateTime endDate,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    final business = _ref.read(activeBusinessProvider);
    if (session == null || business == null) {
      return const Fail(
        UnexpectedFailure(message: 'Please sign in again to close a date.'),
      );
    }

    return _ref.read(checkHolidayBookingsProvider)(
      businessId: business.id,
      accessToken: session.accessToken,
      date: date,
      endDate: endDate,
    );
  }

  Future<String?> createHoliday({
    required DateTime date,
    required DateTime endDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    return _guard((session, business) async {
      final result = await _ref.read(createBusinessHolidayProvider)(
        businessId: business.id,
        accessToken: session.accessToken,
        date: date,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
      );

      return switch (result) {
        Success() => null,
        Fail(failure: final failure) => failure.message,
      };
    }, 'Please sign in again to close a date.');
  }

  Future<String?> _applyBusiness(Result<Business> result) async {
    switch (result) {
      case Success(data: final business):
        _ref.read(activeBusinessProvider.notifier).update(business);
        // Persist into the cached session too, otherwise the edit is lost the
        // next time the app reads `ownedBusinesses` from shared preferences.
        await _ref
            .read(authControllerProvider.notifier)
            .updateOwnedBusiness(business);
        return null;
      case Fail(failure: final failure):
        return failure.message;
    }
  }

  Future<String?> _guard(
    Future<String?> Function(AuthSession session, Business business) action,
    String signedOutMessage,
  ) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    final business = _ref.read(activeBusinessProvider);
    if (session == null || business == null) {
      return signedOutMessage;
    }

    return action(session, business);
  }

  Future<String?> createResource({
    required String businessId,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to create this venue.';
    }

    final result = await _ref.read(createBusinessResourceProvider)(
      businessId: businessId,
      accessToken: session.accessToken,
      fields: fields,
      imagePaths: imagePaths,
    );

    return switch (result) {
      Success() => null,
      Fail(failure: final failure) => failure.message,
    };
  }

  Future<String?> createCategory({
    required String businessId,
    required String name,
    required String description,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to create this category.';
    }

    final result = await _ref.read(createResourceCategoryProvider)(
      businessId: businessId,
      accessToken: session.accessToken,
      name: name,
      description: description,
    );

    return switch (result) {
      Success() => null,
      Fail(failure: final failure) => failure.message,
    };
  }

  Future<String?> updateResource({
    required String resourceId,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to update this venue.';
    }

    final result = await _ref.read(updateBusinessResourceProvider)(
      resourceId: resourceId,
      accessToken: session.accessToken,
      fields: fields,
      imagePaths: imagePaths,
    );

    return switch (result) {
      Success() => null,
      Fail(failure: final failure) => failure.message,
    };
  }

  Future<String?> deleteResource(String resourceId) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to delete this venue.';
    }

    final result = await _ref.read(deleteBusinessResourceProvider)(
      resourceId: resourceId,
      accessToken: session.accessToken,
    );

    return switch (result) {
      Success() => null,
      Fail(failure: final failure) => failure.message,
    };
  }

  Future<String?> createScheduleException({
    required String resourceId,
    required DateTime date,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required bool isBlockout,
    required String reason,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to create this exception.';
    }

    final result = await _ref.read(createScheduleExceptionProvider)(
      accessToken: session.accessToken,
      resourceId: resourceId,
      date: date,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      isBlockout: isBlockout,
      reason: reason,
    );

    return switch (result) {
      Success() => null,
      Fail(failure: final failure) => failure.message,
    };
  }

  /// Moves a booking to a new state. Returns null on success, or a message.
  Future<String?> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    final business = _ref.read(activeBusinessProvider);
    if (session == null || business == null) {
      return 'Please sign in again to update this booking.';
    }

    final result = await _ref.read(updateBookingStatusProvider)(
      bookingId: bookingId,
      accessToken: session.accessToken,
      status: status,
    );

    switch (result) {
      case Success():
        // The timeline shows the new state, and the day's takings change with
        // it — a cancelled booking drops out of the total.
        _ref.invalidate(businessBookingsProvider(business.id));
        _ref.invalidate(businessStatsProvider);
        _ref.invalidate(businessPaymentsForMonthProvider);
        return null;
      case Fail(failure: final failure):
        return failure.message;
    }
  }

  /// Books a walk-in or phone customer. [overridePrice] is sent only when the
  /// owner typed one — otherwise the server prices the slot itself.
  Future<String?> createManualBooking({
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    num? overridePrice,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    final business = _ref.read(activeBusinessProvider);
    if (session == null || business == null) {
      return 'Please sign in again to create this booking.';
    }

    final result = await _ref.read(createManualBookingProvider)(
      accessToken: session.accessToken,
      resourceId: resourceId,
      startTime: startTime,
      endTime: endTime,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      overridePrice: overridePrice,
    );

    switch (result) {
      case Success():
        // The new reservation has to show up in the timeline, the dashboard
        // totals and the payments ledger it just created a row in.
        _ref.invalidate(businessBookingsProvider(business.id));
        _ref.invalidate(businessStatsProvider);
        // Invalidate the family: every cached month, the screen bound to the
        // selected one, and the profit comparison derived from two of them.
        _ref.invalidate(businessPaymentsForMonthProvider);
        return null;
      case Fail(failure: final failure):
        return failure.message;
    }
  }

  /// Settles a payment. The method and the status are separate endpoints, so
  /// the method is written first — if that fails the payment is left untouched
  /// rather than marked paid against the wrong method.
  Future<String?> settlePayment({
    required String paymentId,
    required String method,
    String status = 'PAID',
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to update this payment.';
    }

    final useCase = _ref.read(updatePaymentProvider);

    if (method.isNotEmpty) {
      final methodResult = await useCase.method(
        paymentId: paymentId,
        accessToken: session.accessToken,
        method: method,
      );
      if (methodResult case Fail(failure: final failure)) {
        return failure.message;
      }
    }

    final result = await useCase.status(
      paymentId: paymentId,
      accessToken: session.accessToken,
      status: status,
    );

    switch (result) {
      case Success():
        _applySettled({paymentId}, status: status, method: method);
        return null;
      case Fail(failure: final failure):
        return failure.message;
    }
  }

  /// Settles several payments at once.
  ///
  /// The status goes in a single bulk request. The method does not — the bulk
  /// endpoint only carries a status — so the methods are written first, in
  /// parallel, and only then are the payments marked paid. A method that fails
  /// aborts before anything is settled, for the same reason as the single-row
  /// path: better untouched than paid against the wrong method.
  Future<String?> settlePayments({
    required List<String> paymentIds,
    required String method,
    String status = 'PAID',
  }) async {
    if (paymentIds.isEmpty) {
      return null;
    }

    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to update these payments.';
    }

    final useCase = _ref.read(updatePaymentProvider);

    if (method.isNotEmpty) {
      final methodResults = await Future.wait([
        for (final paymentId in paymentIds)
          useCase.method(
            paymentId: paymentId,
            accessToken: session.accessToken,
            method: method,
          ),
      ]);

      for (final methodResult in methodResults) {
        if (methodResult case Fail(failure: final failure)) {
          return failure.message;
        }
      }
    }

    final result = await useCase.bulkStatus(
      paymentIds: paymentIds,
      accessToken: session.accessToken,
      status: status,
    );

    switch (result) {
      case Success():
        _applySettled(paymentIds.toSet(), status: status, method: method);
        return null;
      case Fail(failure: final failure):
        return failure.message;
    }
  }

  /// Updates the rows on screen, then reconciles the server-computed stats in
  /// the background.
  ///
  /// The screen never passes through a loading state, so settling a payment
  /// changes the cards it affects and nothing else. The other cached months
  /// are invalidated instead — they are off screen, so refetching them costs
  /// nothing visually, and the profit comparison is derived from them.
  void _applySettled(
    Set<String> paymentIds, {
    required String status,
    required String method,
  }) {
    final month = _ref.read(paymentsMonthProvider);
    final key = DateTime(month.year, month.month);
    final notifier = _ref.read(businessPaymentsForMonthProvider(key).notifier);

    notifier.applySettled(
      paymentIds: paymentIds,
      status: status,
      method: method.isEmpty ? null : method,
    );

    unawaited(notifier.refreshQuietly());
  }

  Future<String?> deleteScheduleException(String exceptionId) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return 'Please sign in again to delete this exception.';
    }

    final result = await _ref.read(deleteScheduleExceptionProvider)(
      exceptionId: exceptionId,
      accessToken: session.accessToken,
    );

    return switch (result) {
      Success() => null,
      Fail(failure: final failure) => failure.message,
    };
  }
}
