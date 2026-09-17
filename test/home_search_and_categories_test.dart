import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/errors/failure.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/booking_confirmation.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/domain/entities/business_category.dart';
import 'package:bookat/src/features/booking/domain/entities/my_booking.dart';
import 'package:bookat/src/features/booking/domain/entities/review.dart';
import 'package:bookat/src/features/booking/domain/entities/slot_availability.dart';
import 'package:bookat/src/features/booking/domain/repositories/booking_repository.dart';
import 'package:bookat/src/features/booking/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `/businesses/search` now does the filtering server-side, and the search
/// box is debounced rather than firing a request per keystroke — both are
/// exercised here against a fake repository that records what it was asked
/// for, since a mistake in the wiring (wrong param, missing debounce) would
/// otherwise only surface as excess API calls in production.
void main() {
  Business business(String name) {
    return BusinessModel.fromJson({
      'id': name,
      'name': name,
      'slug': name.toLowerCase(),
      'city': 'Islamabad',
      'address': 'Somewhere',
      'ownerId': 'owner-1',
      'settings': {'currency': 'PKR'},
    });
  }

  Future<ProviderContainer> readyContainer(_FakeRepository repository) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(null)),
        bookingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await container.read(authControllerProvider.future);
    return container;
  }

  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
    );
  }

  testWidgets('loads businesses with no filters on first open', (tester) async {
    final repository = _FakeRepository(
      categories: const [BusinessCategory(value: 'SPORTS_GROUND', label: 'Sports Ground')],
      businesses: [business('Bats and Balls')],
    );
    final container = await readyContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, [('', '')]);
    expect(find.text('Bats and Balls'), findsOneWidget);
    expect(find.text('Sports Ground'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not search on every keystroke — only after the debounce settles',
      (tester) async {
    final repository = _FakeRepository(businesses: [business('Bats and Balls')]);
    final container = await readyContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    repository.searchCalls.clear();

    await tester.enterText(find.byType(TextField), 'bats');
    // Well under the 400ms debounce — no request yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.searchCalls, isEmpty);

    // Past the debounce window — exactly one request, with the final text.
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.searchCalls, [('bats', '')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a category sends its value as the type filter',
      (tester) async {
    final repository = _FakeRepository(
      categories: const [BusinessCategory(value: 'SPORTS_GROUND', label: 'Sports Ground')],
      businesses: [business('Bats and Balls')],
    );
    final container = await readyContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    repository.searchCalls.clear();

    await tester.tap(find.text('Sports Ground'));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, [('', 'SPORTS_GROUND')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to just the All chip when categories fail to load',
      (tester) async {
    final repository = _FakeRepository(
      businesses: [business('Bats and Balls')],
      categoriesFail: true,
    );
    final container = await readyContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Bats and Balls'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at a narrow width with several categories',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = _FakeRepository(
      categories: const [
        BusinessCategory(value: 'SPORTS_GROUND', label: 'Sports Ground'),
        BusinessCategory(value: 'SALON', label: 'Salon'),
        BusinessCategory(value: 'CLINIC', label: 'Clinic'),
        BusinessCategory(value: 'STUDIO', label: 'Photography Studio'),
      ],
      businesses: [business('Bats and Balls')],
    );
    final container = await readyContainer(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

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
  _FakeRepository({
    this.categories = const [],
    this.businesses = const [],
    this.categoriesFail = false,
  });

  final List<BusinessCategory> categories;
  final List<Business> businesses;
  final bool categoriesFail;
  final List<(String, String)> searchCalls = [];

  @override
  Future<Result<List<Business>>> searchBusinesses({
    String query = '',
    String category = '',
  }) async {
    searchCalls.add((query, category));
    return Success(businesses);
  }

  @override
  Future<Result<List<BusinessCategory>>> getCategories() async {
    if (categoriesFail) {
      return const Fail(UnexpectedFailure(message: 'Could not load categories.'));
    }
    return Success(categories);
  }

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
