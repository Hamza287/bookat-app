import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_stats.dart';
import 'package:bookat/src/features/business_admin/presentation/pages/business_admin_home_page.dart';
import 'package:bookat/src/features/business_admin/presentation/providers/business_admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The manual-booking sheet prices the slot for the owner rather than making
/// them work it out: the venue's own `basePrice` pro-rated over the window they
/// picked. A custom price then overrides that figure — which is what actually
/// gets sent as `overridePrice`.
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

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    return ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        // Every tab builds inside the IndexedStack, so stub them all or the
        // test fires real requests at the live API.
        businessStatsProvider.overrideWith(
          (ref) async => const BusinessStats(
            todayRevenue: 0,
            appointmentsToday: 0,
            activeResources: 1,
            occupancyRate: '0%',
            chartData: [],
          ),
        ),
        businessBookingsProvider.overrideWith((ref, id) async => const []),
        businessResourcesProvider.overrideWith(
          (ref, id) async => business().resources,
        ),
        resourceCategoriesProvider.overrideWith((ref, id) async => const []),
        businessPaymentsForMonthProvider.overrideWith(
          _EmptyPaymentsNotifier.new,
        ),
      ],
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    final container = await buildContainer();
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

    // Bookings is the second destination.
    await tester.tap(find.text('Bookings').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Booking'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Add Booking is enabled from fetched venues, not the login snapshot',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    // A business whose cached copy carries no resources at all — exactly what a
    // session looks like when the venue was created after the owner signed in.
    final staleBusiness = BusinessModel.fromJson({
      'id': 'business-1',
      'name': 'Bats and Balls',
      'slug': 'bats-and-balls',
      'city': 'Islamabad',
      'address': 'Sohni Road',
      'ownerId': 'owner-1',
      'settings': {'currency': 'PKR'},
      'resources': const <dynamic>[],
    });

    final staleSession = AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: session.user.copyWith(ownedBusinesses: [staleBusiness]),
    );

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(staleSession)),
        businessStatsProvider.overrideWith(
          (ref) async => const BusinessStats(
            todayRevenue: 0,
            appointmentsToday: 0,
            activeResources: 1,
            occupancyRate: '0%',
            chartData: [],
          ),
        ),
        businessBookingsProvider.overrideWith((ref, id) async => const []),
        // The server knows about the venue even though the session does not.
        businessResourcesProvider.overrideWith(
          (ref, id) async => business().resources,
        ),
        resourceCategoriesProvider.overrideWith((ref, id) async => const []),
        businessPaymentsForMonthProvider.overrideWith(
          _EmptyPaymentsNotifier.new,
        ),
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

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add Booking'),
    );
    expect(button.onPressed, isNotNull);

    // And the sheet it opens actually offers that venue.
    await tester.tap(find.widgetWithText(FilledButton, 'Add Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Left Field'), findsWidgets);
  });

  testWidgets('prices one slot from the venue base price by default',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openSheet(tester);

    expect(find.text('Add Manual Booking'), findsOneWidget);
    expect(find.text('Calculated Price'), findsOneWidget);
    // End defaults to one 60-minute slot after start, so one slot at 2500.
    expect(find.text('PKR 2500'), findsOneWidget);
  });

  testWidgets('a custom price takes over as the amount charged',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Custom Price / Discount (Optional)'),
      '3000',
    );
    await tester.pumpAndSettle();

    // The calculated figure stays visible but is superseded.
    expect(find.text('PKR 2500'), findsOneWidget);
    expect(find.text('Charging PKR 3000'), findsOneWidget);
  });

  testWidgets('the sheet renders without overflow on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openSheet(tester);

    expect(find.text('Customer Information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

/// The payments tab is not what this test exercises, so every month is empty.
class _EmptyPaymentsNotifier extends BusinessPaymentsNotifier {
  @override
  Future<BusinessPayments> build(DateTime month) async {
    return const BusinessPayments(
      payments: [],
      stats: BusinessPaymentStats.empty(),
    );
  }
}
