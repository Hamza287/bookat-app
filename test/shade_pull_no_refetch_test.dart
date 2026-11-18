import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/domain/entities/my_booking.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_stats.dart';
import 'package:bookat/src/features/business_admin/domain/entities/resource_category.dart';
import 'package:bookat/src/features/business_admin/domain/repositories/business_admin_repository.dart';
import 'package:bookat/src/features/business_admin/presentation/pages/business_admin_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dashboard refreshes when the owner comes back to it, because bookings
/// can be made elsewhere meanwhile. It must not refresh when the app is merely
/// interrupted — pulling down the notification shade sends `inactive` then
/// `resumed`, and reloading on that made the screen refetch every time the
/// shade was opened.
void main() {
  Business business() {
    return BusinessModel.fromJson({
      'id': 'business-1',
      'name': 'Bats and Balls',
      'slug': 'bats-and-balls',
      'city': 'Islamabad',
      'address': 'Sohni Road, Islamabad, Pakistan',
      'ownerId': 'owner-1',
      'settings': {'currency': 'PKR'},
      'resources': const <dynamic>[],
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

  late _CountingRepository repository;

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    repository = _CountingRepository();

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        businessAdminRepositoryProvider.overrideWithValue(repository),
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
  }

  Future<void> send(
    WidgetTester tester,
    List<AppLifecycleState> states,
  ) async {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('pulling down the shade refetches nothing', (tester) async {
    await pumpDashboard(tester);
    final before = repository.bookingsCalls;
    expect(before, greaterThan(0), reason: 'the first load should have run');

    // What the shade actually produces: interrupted, then straight back.
    await send(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(repository.bookingsCalls, before);
    expect(repository.statsCalls, greaterThan(0));
  });

  testWidgets('opening it repeatedly still refetches nothing', (tester) async {
    await pumpDashboard(tester);
    final before = repository.bookingsCalls;

    for (var i = 0; i < 4; i++) {
      await send(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    }

    expect(repository.bookingsCalls, before);
  });

  testWidgets('actually leaving and coming back does refetch', (tester) async {
    await pumpDashboard(tester);
    final before = repository.bookingsCalls;

    // The full transition Flutter emits for the launcher and back.
    await send(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    expect(repository.bookingsCalls, greaterThan(before));
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

/// Counts how often the dashboard goes back to the server.
class _CountingRepository implements BusinessAdminRepository {
  int bookingsCalls = 0;
  int statsCalls = 0;
  int paymentsCalls = 0;

  @override
  Future<Result<List<MyBooking>>> getBusinessBookings({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  }) async {
    bookingsCalls++;
    return const Success(<MyBooking>[]);
  }

  @override
  Future<Result<BusinessStats>> getBusinessStats({
    required String businessId,
    required String accessToken,
  }) async {
    statsCalls++;
    return const Success(
      BusinessStats(
        todayRevenue: 0,
        appointmentsToday: 0,
        activeResources: 0,
        occupancyRate: '0%',
        chartData: [],
      ),
    );
  }

  @override
  Future<Result<BusinessPayments>> getBusinessPayments({
    required String businessId,
    required String accessToken,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    paymentsCalls++;
    return const Success(
      BusinessPayments(payments: [], stats: BusinessPaymentStats.empty()),
    );
  }

  @override
  Future<Result<List<BusinessResource>>> getBusinessResources({
    required String businessId,
    required String accessToken,
  }) async {
    return const Success(<BusinessResource>[]);
  }

  @override
  Future<Result<List<ResourceCategory>>> getResourceCategories({
    required String businessId,
    required String accessToken,
  }) async {
    return const Success(<ResourceCategory>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
