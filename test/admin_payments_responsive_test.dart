import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/business_admin/data/models/business_payment_model.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_stats.dart';
import 'package:bookat/src/features/business_admin/presentation/pages/business_admin_home_page.dart';
import 'package:bookat/src/features/business_admin/presentation/providers/business_admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The revenue-by-method tiles used to sit in a `GridView` with a fixed
/// `childAspectRatio`, which pins each tile's height to its column width. On a
/// narrow phone that box came out shorter than its own label + amount and
/// Flutter reported "BOTTOM OVERFLOWED BY 12 PIXELS".
///
/// These render the real admin payments screen at the narrowest sizes the app
/// supports. `takeException` catches the overflow, because a Flutter layout
/// overflow throws in tests rather than only painting a stripe.
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

  BusinessPayments payments() {
    return BusinessPaymentsModel.fromJson({
      'data': [
        for (var i = 0; i < 3; i++)
          {
            'id': 'payment-$i',
            'bookingId': 'booking-$i',
            // Deliberately large: the widest amount the tiles have to hold.
            'amount': 1234567,
            'currency': 'PKR',
            'method': 'VENUE',
            'status': 'PENDING',
            'createdAt': '2026-08-04T21:55:12.654Z',
            'booking': {
              'startTime': '2026-08-07T16:00:00.000Z',
              'customer': {
                'firstName': 'Muhammad',
                'lastName': 'Pervaiz',
                'phone': '03489366944',
              },
              'resource': {'name': 'L Field'},
            },
          },
      ],
      'stats': {
        'totalRevenue': 1234567,
        'numberOfPayments': 3,
        'averagePayment': 411522,
        'pendingRevenue': 7654321,
        'methodBreakdown': {
          'CASH': 1234567,
          'ONLINE': 7654321,
          'CARD': 100,
          'BANK_TRANSFER': 2500,
        },
      },
      'meta': {'total': 3},
    });
  }

  BusinessStats stats() {
    return const BusinessStats(
      todayRevenue: 1234567,
      appointmentsToday: 12,
      activeResources: 4,
      occupancyRate: '86%',
      chartData: [],
    );
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

  ProviderContainer buildContainer(SharedPreferences preferences) {
    return ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        // The admin shell reads the persisted theme on build.
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        businessPaymentsForMonthProvider.overrideWith(
          () => _StubPaymentsNotifier(payments()),
        ),
        // The tabs live in an IndexedStack, so every sibling builds too.
        // Without these the test would fire real requests at the live API.
        businessStatsProvider.overrideWith((ref) async => stats()),
        businessBookingsProvider.overrideWith((ref, id) async => const []),
        businessResourcesProvider.overrideWith((ref, id) async => const []),
        resourceCategoriesProvider.overrideWith((ref, id) async => const []),
      ],
    );
  }

  Future<SharedPreferences> preferences() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const BusinessAdminHomePage(),
      ),
    );
  }

  Future<void> openPayments(WidgetTester tester) async {
    await tester.tap(find.text('Payments').first);
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(320, 640), // smallest phone the app targets
    Size(360, 740), // common Android
    Size(412, 915), // Pixel-class
  ]) {
    testWidgets('payments screen has no overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = buildContainer(await preferences());
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await tester.pumpWidget(harness(container));
      await tester.pumpAndSettle();
      await openPayments(tester);

      expect(find.text('Revenue by Method'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('method tiles still fit when the user scales text up',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = buildContainer(await preferences());
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.3,
            maxScaleFactor: 1.3,
            child: child!,
          ),
          home: const BusinessAdminHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openPayments(tester);

    // A fixed-ratio grid would blow out here even if it survived at 1.0 scale,
    // because the tile height would not grow with the text.
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

/// Serves the same fixed month whichever month is asked for.
class _StubPaymentsNotifier extends BusinessPaymentsNotifier {
  _StubPaymentsNotifier(this._payments);

  final BusinessPayments _payments;

  @override
  Future<BusinessPayments> build(DateTime month) async => _payments;
}
