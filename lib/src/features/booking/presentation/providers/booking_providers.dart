import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependency_providers.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/business.dart';
import '../../domain/entities/business_category.dart';
import '../../domain/entities/my_booking.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/slot_availability.dart';

/// The current search query entered by the user, updated on every keystroke
/// so the text field and clear button stay responsive.
final searchQueryProvider = StateProvider.autoDispose<String>((_) => '');

/// The query actually sent to the server, updated only after typing pauses.
/// Widgets debounce writes to this provider (see `HomePage`) rather than
/// firing a network request per keystroke.
final debouncedSearchQueryProvider = StateProvider.autoDispose<String>((_) => '');

/// The selected category's API value (e.g. `SPORTS_GROUND`), or empty for
/// "All". This is the raw value sent as the search endpoint's `type` param —
/// not the display label.
final selectedCategoryProvider = StateProvider.autoDispose<String>((_) => '');

/// Fetches businesses from the server, filtered by [debouncedSearchQueryProvider]
/// and [selectedCategoryProvider]. Filtering happens server-side via
/// `/businesses/search`, so this re-fetches whenever either changes rather
/// than filtering a client-side list.
final businessesProvider =
    FutureProvider.autoDispose<List<Business>>((ref) async {
  final useCase = ref.watch(searchBusinessesProvider);
  final query = ref.watch(debouncedSearchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final result = await useCase(query: query, category: category);

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

/// The categories customers can filter by, from `/config/categories`.
final businessCategoriesProvider =
    FutureProvider<List<BusinessCategory>>((ref) async {
  final useCase = ref.watch(getBusinessCategoriesProvider);
  final result = await useCase();

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

final businessDetailsProvider =
    FutureProvider.autoDispose.family<Business, String>((ref, slug) async {
  final useCase = ref.watch(getBusinessBySlugProvider);
  final result = await useCase(slug);

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

final availabilityProvider = FutureProvider.autoDispose
    .family<List<SlotAvailability>, AvailabilityRequest>((ref, request) async {
  final useCase = ref.watch(getAvailabilityProvider);
  final result = await useCase(
    resourceId: request.resourceId,
    date: request.date,
    tzOffset: request.tzOffset,
  );

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

final myBookingsProvider =
    FutureProvider.autoDispose<List<MyBooking>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const UnexpectedFailure(message: AppStrings.signInAgainBeforeBooking);
  }

  final useCase = ref.watch(getMyBookingsProvider);
  final result = await useCase(session.accessToken);

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

/// Reviews for a business's public listing — no auth required to view.
final businessReviewsProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, businessId) async {
  final useCase = ref.watch(getBusinessReviewsProvider);
  final result = await useCase(businessId);

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

/// The signed-in customer's bookings at this business that are eligible to
/// review. Empty (not an error) when signed out, since "write a review"
/// simply isn't offered in that case.
final eligibleReviewBookingsProvider = FutureProvider.autoDispose
    .family<List<MyBooking>, String>((ref, businessId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const [];
  }

  final useCase = ref.watch(getEligibleReviewBookingsProvider);
  final result = await useCase(
    accessToken: session.accessToken,
    businessId: businessId,
  );

  return switch (result) {
    Success(:final data) => data,
    Fail(:final failure) => throw failure,
  };
});

class AvailabilityRequest {
  const AvailabilityRequest({
    required this.resourceId,
    required this.date,
    required this.tzOffset,
  });

  final String resourceId;
  final String date;
  final int tzOffset;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AvailabilityRequest &&
            runtimeType == other.runtimeType &&
            resourceId == other.resourceId &&
            date == other.date &&
            tzOffset == other.tzOffset;
  }

  @override
  int get hashCode => Object.hash(resourceId, date, tzOffset);
}

final bookingSubmissionLoadingProvider =
    StateProvider.autoDispose<bool>((_) => false);

/// Per-booking cancellation-in-flight flag, keyed by booking id so cancelling
/// one booking doesn't show a spinner on every card in the list.
final bookingCancellationLoadingProvider =
    StateProvider.autoDispose.family<bool, String>((_, _) => false);

final reviewSubmissionLoadingProvider =
    StateProvider.autoDispose<bool>((_) => false);

final bookingActionControllerProvider = Provider<BookingActionController>((ref) {
  return BookingActionController(ref);
});

class BookingActionController {
  const BookingActionController(this._ref);

  final Ref _ref;

  Future<String?> createBooking({
    required String resourceId,
    required List<String> slots,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return AppStrings.signInAgainBeforeBooking;
    }

    _ref.read(bookingSubmissionLoadingProvider.notifier).state = true;
    final user = session.user;
    final result = await _ref.read(createBookingProvider)(
      accessToken: session.accessToken,
      resourceId: resourceId,
      slots: slots,
      paymentMethod: 'VENUE',
      customerDetails: {
        'firstName': user.firstName,
        'lastName': user.lastName,
        'email': user.email,
        'phone': user.phone,
      },
    );
    _ref.read(bookingSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success() => null,
      Fail(:final failure) => failure.message,
    };
  }

  /// Server-enforced: the API checks the venue's cancellation policy (set by
  /// the business owner in Settings) and rejects the call if the booking is
  /// outside that window. The client does not try to predict the outcome.
  Future<String?> cancelBooking(String bookingId) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return AppStrings.signInAgainBeforeBooking;
    }

    _ref.read(bookingCancellationLoadingProvider(bookingId).notifier).state = true;
    final result = await _ref.read(cancelBookingProvider)(
      accessToken: session.accessToken,
      bookingId: bookingId,
    );
    _ref.read(bookingCancellationLoadingProvider(bookingId).notifier).state = false;

    return switch (result) {
      Success() => null,
      Fail(:final failure) => failure.message,
    };
  }

  Future<String?> submitReview({
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    final session = _ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return AppStrings.signInAgainBeforeBooking;
    }

    _ref.read(reviewSubmissionLoadingProvider.notifier).state = true;
    final result = await _ref.read(createReviewProvider)(
      accessToken: session.accessToken,
      businessId: businessId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );
    _ref.read(reviewSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success() => null,
      Fail(:final failure) => failure.message,
    };
  }
}
