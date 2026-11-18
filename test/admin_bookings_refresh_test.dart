import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/domain/entities/my_booking.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_stats.dart';
import 'package:bookat/src/features/business_admin/domain/repositories/business_admin_repository.dart';
import 'package:bookat/src/features/business_admin/presentation/pages/business_admin_home_page.dart';
import 'package:bookat/src/features/business_admin/presentation/providers/business_admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adding a booking from the owner's dashboard must put it straight into the
/// day's timeline. It used to take an app restart to appear.
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
        {
          'id': 'resource-1',
          'name': 'L Field',
          'basePrice': 2500,
          'isActive': true,
          'attributes': {'durationMinutes': '60'},
        },
      ],
    });
  }

  final session = AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AppUser(
      id: 'owner-1',
      email: 'owner@example.com',
      firstName: 'Business',
      lastName: 'Owner',
      phone: '03001234567',
      role: Role.businessAdmin,
      isActive: true,
      isVerified: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      ownedBusinesses: [business()],
    ),
  );

  testWidgets('a new booking appears in the timeline without a restart',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final repository = _FakeRepository(businessResources: business().resources);

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        // The real repository, faked at the boundary: creating a booking adds
        // it to what the next fetch returns, exactly as the server would.
        businessAdminRepositoryProvider.overrideWithValue(repository),
        businessStatsProvider.overrideWith(
          (ref) async => const BusinessStats(
            todayRevenue: 0,
            appointmentsToday: 0,
            activeResources: 1,
            occupancyRate: '0%',
            chartData: [],
          ),
        ),
        businessPaymentsForMonthProvider.overrideWith(
          _EmptyPaymentsNotifier.new,
        ),
        resourceCategoriesProvider.overrideWith((ref, id) async => const []),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BusinessAdminHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookings').first);
    await tester.pumpAndSettle();

    // Nothing booked yet for today.
    expect(find.text('1 reservations'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Add Booking'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'First name *'),
      'Walk',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Last name *'),
      'In',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone Number *'),
      '03001234567',
    );
    await tester.pumpAndSettle();

    // The sheet's own submit button, below the page's; it may sit under the
    // fold, so bring it into view first.
    final submit = find.widgetWithText(FilledButton, 'Add Booking').last;
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.created, 1);

    // The sheet has closed; the timeline behind it must already show the new
    // reservation, with no restart and no manual refresh.
    expect(find.text('1 reservations'), findsOneWidget);
  });

  testWidgets('returning to the foreground re-reads the day', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final repository = _FakeRepository(businessResources: business().resources);

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        businessAdminRepositoryProvider.overrideWithValue(repository),
        businessStatsProvider.overrideWith(
          (ref) async => const BusinessStats(
            todayRevenue: 0,
            appointmentsToday: 0,
            activeResources: 1,
            occupancyRate: '0%',
            chartData: [],
          ),
        ),
        businessPaymentsForMonthProvider.overrideWith(
          _EmptyPaymentsNotifier.new,
        ),
        resourceCategoriesProvider.overrideWith((ref, id) async => const []),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BusinessAdminHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = repository.fetches;
    expect(before, greaterThan(0));

    // A booking made elsewhere — on the web dashboard, or by a customer —
    // while the owner had the app in the background.
    await repository.createManualBooking(
      accessToken: 'token',
      resourceId: 'resource-1',
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 1)),
      firstName: 'Phone',
      lastName: 'Customer',
      email: '',
      phone: '03001234567',
    );

    // Flutter asserts on the transitions, so the app has to walk the whole way
    // out and back: resumed -> inactive -> hidden -> paused -> hidden ->
    // inactive -> resumed.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.fetches, greaterThan(before));

    await tester.tap(find.text('Bookings').first);
    await tester.pumpAndSettle();

    expect(find.text('1 reservations'), findsOneWidget);
  });
}

/// Stands in for the server: bookings created are returned by later fetches.
class _FakeRepository implements BusinessAdminRepository {
  _FakeRepository({required this.businessResources});

  final List<BusinessResource> businessResources;
  final List<MyBooking> _bookings = [];
  int created = 0;

  @override
  Future<Result<void>> createManualBooking({
    required String accessToken,
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    num? overridePrice,
  }) async {
    created++;
    _bookings.add(
      MyBookingModel.fromJson({
        'id': 'booking-$created',
        'status': 'CONFIRMED',
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'totalPrice': overridePrice ?? 2500,
        'paymentStatus': 'UNPAID',
        'customer': {'firstName': firstName, 'lastName': lastName},
        'resource': {'id': resourceId, 'name': 'L Field'},
      }),
    );
    return const Success<void>(null);
  }

  int fetches = 0;

  @override
  Future<Result<List<MyBooking>>> getBusinessBookings({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  }) async {
    fetches++;
    return Success(List<MyBooking>.unmodifiable(_bookings));
  }

  @override
  Future<Result<List<BusinessResource>>> getBusinessResources({
    required String businessId,
    required String accessToken,
  }) async {
    return Success(businessResources);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

/// The payments tab is not what these tests exercise, so every month comes
/// back empty.
class _EmptyPaymentsNotifier extends BusinessPaymentsNotifier {
  @override
  Future<BusinessPayments> build(DateTime month) async {
    return const BusinessPayments(
      payments: [],
      stats: BusinessPaymentStats.empty(),
    );
  }
}
