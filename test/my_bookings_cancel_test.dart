import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/errors/failure.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:bookat/src/features/booking/domain/entities/booking_confirmation.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/domain/entities/business_category.dart';
import 'package:bookat/src/features/booking/domain/entities/my_booking.dart';
import 'package:bookat/src/features/booking/domain/entities/review.dart';
import 'package:bookat/src/features/booking/domain/entities/slot_availability.dart';
import 'package:bookat/src/features/booking/domain/repositories/booking_repository.dart';
import 'package:bookat/src/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:bookat/src/features/booking/presentation/providers/booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cancellation is server-enforced (the API reads the venue's cancellation
/// policy), so the client only offers the action and surfaces whatever the
/// server decides — it does not try to predict the outcome itself.
void main() {
  MyBooking booking({
    String id = 'booking-1',
    String status = 'PENDING',
    DateTime? startTime,
  }) {
    return MyBookingModel.fromJson({
      'id': id,
      'status': status,
      'totalPrice': 2500,
      'startTime':
          (startTime ?? DateTime.now().add(const Duration(days: 3)))
              .toIso8601String(),
      'resource': {'name': 'Main Field', 'basePrice': 2500},
      'business': {
        'name': 'Bats and Balls',
        'settings': {'currency': 'PKR'},
      },
    });
  }

  final session = AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AppUser(
      id: 'customer-1',
      email: 'customer@example.com',
      firstName: 'Ali',
      lastName: 'Khan',
      phone: '03001234567',
      role: Role.customer,
      isActive: true,
      isVerified: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      ownedBusinesses: const [],
    ),
  );

  ProviderContainer buildContainer(
    List<MyBooking> bookings,
    BookingRepository repository,
  ) {
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        myBookingsProvider.overrideWith((ref) async => bookings),
        bookingRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const MyBookingsPage()),
    );
  }

  /// `authControllerProvider` isn't watched anywhere in `MyBookingsPage`'s own
  /// tree (only `myBookingsProvider`, which is overridden directly) — so
  /// nothing forces its async `build()` to resolve on its own. Without this,
  /// the cancel button's tap handler would read it mid-flight and see
  /// `AsyncLoading`, not the stubbed session.
  Future<ProviderContainer> readyContainer(
    List<MyBooking> bookings,
    BookingRepository repository,
  ) async {
    final container = buildContainer(bookings, repository);
    await container.read(authControllerProvider.future);
    return container;
  }

  testWidgets('shows a Cancel button for a pending upcoming booking',
      (tester) async {
    final container = await readyContainer([booking()], _FakeRepository());
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Booking'), findsOneWidget);
  });

  testWidgets('hides the Cancel button for a completed booking', (tester) async {
    final container =
        await readyContainer([booking(status: 'COMPLETED')], _FakeRepository());
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Booking'), findsNothing);
  });

  testWidgets('hides the Cancel button for a past booking', (tester) async {
    final container = await readyContainer(
      [booking(startTime: DateTime.now().subtract(const Duration(days: 3)))],
      _FakeRepository(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    // Past bookings render in the "Past" tab, not "Upcoming" — switch tabs.
    await tester.tap(find.text('Past (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Booking'), findsNothing);
  });

  testWidgets('confirming cancel calls the API and shows success', (tester) async {
    final repository = _FakeRepository();
    final container = await readyContainer([booking()], repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this booking?'), findsOneWidget);

    // The dialog's confirm button shares its label with the card's button —
    // the FilledButton is unique to the dialog, so target it by type.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, ['booking-1']);
    expect(find.text('Booking cancelled.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces the server rejection when outside the cancellation window',
      (tester) async {
    const rejection =
        'This booking is outside the venue\'s cancellation window and can no longer be cancelled.';
    final repository = _FakeRepository(
      cancelResult: const Fail(ServerFailure(message: rejection)),
    );
    final container = await readyContainer([booking()], repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(rejection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declining the dialog does not call the API', (tester) async {
    final repository = _FakeRepository();
    final container = await readyContainer([booking()], repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep booking'));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, isEmpty);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

class _FakeRepository implements BookingRepository {
  _FakeRepository({Result<void>? cancelResult})
      : _cancelResult = cancelResult ?? const Success(null);

  final Result<void> _cancelResult;
  final List<String> cancelCalls = [];

  @override
  Future<Result<void>> cancelBooking({
    required String accessToken,
    required String bookingId,
  }) async {
    cancelCalls.add(bookingId);
    return _cancelResult;
  }

  @override
  Future<Result<List<Business>>> searchBusinesses({
    String query = '',
    String category = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<List<BusinessCategory>>> getCategories() =>
      throw UnimplementedError();

  @override
  Future<Result<Business>> getBusinessBySlug(String slug) =>
      throw UnimplementedError();

  @override
  Future<Result<List<SlotAvailability>>> getAvailability({
    required String resourceId,
    required String date,
    required int tzOffset,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<BookingConfirmation>> createBooking({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<List<MyBooking>>> getMyBookings(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<Result<List<Review>>> getBusinessReviews(String businessId) =>
      throw UnimplementedError();

  @override
  Future<Result<List<MyBooking>>> getEligibleReviewBookings({
    required String accessToken,
    required String businessId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<Review>> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) =>
      throw UnimplementedError();
}
