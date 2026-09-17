import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:bookat/src/features/booking/domain/entities/booking_confirmation.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/domain/entities/business_category.dart';
import 'package:bookat/src/features/booking/domain/entities/my_booking.dart';
import 'package:bookat/src/features/booking/domain/entities/review.dart';
import 'package:bookat/src/features/booking/domain/entities/slot_availability.dart';
import 'package:bookat/src/features/booking/domain/repositories/booking_repository.dart';
import 'package:bookat/src/features/booking/presentation/pages/business_detail_page.dart';
import 'package:bookat/src/features/booking/presentation/providers/booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Business business() {
    return BusinessModel.fromJson({
      'id': 'business-1',
      'name': 'Bats and Balls',
      'slug': 'bats-and-balls',
      'city': 'Islamabad',
      'address': 'Sohni Road',
      'ownerId': 'owner-1',
      'settings': {'currency': 'PKR'},
      'resources': [
        {'id': 'r1', 'name': 'Main Field', 'basePrice': 3500, 'isActive': true},
      ],
    });
  }

  MyBooking eligibleBooking() {
    return MyBookingModel.fromJson({
      'id': 'booking-1',
      'status': 'COMPLETED',
      'startTime': DateTime(2026, 6, 1).toIso8601String(),
      'resource': {'name': 'Main Field'},
    });
  }

  final session = AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AppUser(
      id: 'user-1',
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

  ProviderContainer buildContainer({
    required Business value,
    required List<Review> reviews,
    required List<MyBooking> eligibleBookings,
    BookingRepository? repository,
    bool signedIn = true,
  }) {
    return ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        if (signedIn)
          authControllerProvider.overrideWith(() => _StubAuth(session))
        else
          authControllerProvider.overrideWith(() => _StubAuth(null)),
        businessDetailsProvider(value.slug).overrideWith((ref) async => value),
        availabilityProvider.overrideWith((ref, arg) async => const []),
        businessReviewsProvider(value.id).overrideWith((ref) async => reviews),
        eligibleReviewBookingsProvider(value.id)
            .overrideWith((ref) async => eligibleBookings),
        if (repository != null)
          bookingRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  Widget harness(ProviderContainer container, Business value) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: BusinessDetailPage(business: value),
      ),
    );
  }

  Future<void> scrollToReviews(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('Customer Reviews'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there are no reviews', (tester) async {
    final value = business();
    final container = buildContainer(
      value: value,
      reviews: const [],
      eligibleBookings: const [],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToReviews(tester);

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the average rating and review cards when reviews exist',
      (tester) async {
    final value = business();
    final container = buildContainer(
      value: value,
      reviews: const [
        Review(
          id: 'r1',
          rating: 5,
          comment: 'Great pitch, well maintained.',
          customerName: 'Sara Ahmed',
          createdAt: null,
        ),
        Review(
          id: 'r2',
          rating: 3,
          comment: 'Decent, lighting could be better.',
          customerName: 'Bilal Raza',
          createdAt: null,
        ),
      ],
      eligibleBookings: const [],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToReviews(tester);

    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('Sara Ahmed'), findsOneWidget);
    expect(find.text('Great pitch, well maintained.'), findsOneWidget);
    expect(find.text('Bilal Raza'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prompts sign-in when writing a review while signed out',
      (tester) async {
    final value = business();
    final container = buildContainer(
      value: value,
      reviews: const [],
      eligibleBookings: const [],
      signedIn: false,
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToReviews(tester);

    await tester.tap(find.text('Write a Review'));
    await tester.pumpAndSettle();

    expect(find.text('Please sign in to leave a review.'), findsOneWidget);
    expect(find.text('Your rating'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a message when there are no eligible bookings',
      (tester) async {
    final value = business();
    final container = buildContainer(
      value: value,
      reviews: const [],
      eligibleBookings: const [],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToReviews(tester);

    await tester.tap(find.text('Write a Review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Complete a booking at this venue to write a review.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires a rating before submitting', (tester) async {
    final value = business();
    final container = buildContainer(
      value: value,
      reviews: const [],
      eligibleBookings: [eligibleBooking()],
      repository: _FakeRepository(),
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToReviews(tester);

    await tester.tap(find.text('Write a Review'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    expect(find.text('Please select a rating.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits a review and closes the sheet on success', (tester) async {
    final value = business();
    final repository = _FakeRepository();
    final container = buildContainer(
      value: value,
      reviews: const [],
      eligibleBookings: [eligibleBooking()],
      repository: repository,
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToReviews(tester);

    await tester.tap(find.text('Write a Review'));
    await tester.pumpAndSettle();

    // Tap the 4th star icon to set a rating of 4.
    final starIcons = find.descendant(
      of: find.byType(IconButton),
      matching: find.byIcon(Icons.star_border_rounded),
    );
    await tester.tap(starIcons.at(3));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Loved the venue!');
    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    expect(repository.submittedRating, 4);
    expect(repository.submittedComment, 'Loved the venue!');
    expect(repository.submittedBookingId, 'booking-1');
    expect(find.text('Review submitted. Thank you!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> build() async => _session;
}

class _FakeRepository implements BookingRepository {
  int? submittedRating;
  String? submittedComment;
  String? submittedBookingId;

  @override
  Future<Result<Review>> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    submittedRating = rating;
    submittedComment = comment;
    submittedBookingId = bookingId;
    return Success(
      Review(
        id: 'new-review',
        rating: rating,
        comment: comment,
        customerName: 'You',
        createdAt: DateTime.now(),
      ),
    );
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
  Future<Result<void>> cancelBooking({
    required String accessToken,
    required String bookingId,
  }) =>
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
}
