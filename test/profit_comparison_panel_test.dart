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

/// The overview dashboard compares this month against last, driven by two calls
/// to the payments endpoint.
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

  BusinessPayments payments({num revenue = 0, num pending = 0, int count = 0}) {
    return BusinessPayments(
      payments: const [],
      stats: BusinessPaymentStats(
        totalRevenue: revenue,
        numberOfPayments: count,
        averagePayment: 0,
        pendingRevenue: pending,
        methodBreakdown: const {},
      ),
    );
  }

  Future<void> pumpOverview(
    WidgetTester tester, {
    required BusinessPayments thisMonth,
    required BusinessPayments lastMonth,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final currentKey = DateTime(now.year, now.month);

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        businessStatsProvider.overrideWith(
          (ref) async => const BusinessStats(
            todayRevenue: 0,
            appointmentsToday: 0,
            activeResources: 0,
            occupancyRate: '0%',
            chartData: [],
          ),
        ),
        businessBookingsProvider.overrideWith((ref, id) async => const []),
        businessResourcesProvider.overrideWith((ref, id) async => const []),
        resourceCategoriesProvider.overrideWith((ref, id) async => const []),
        // Keyed by month, so the two calls are told apart by their argument.
        businessPaymentsForMonthProvider.overrideWith(
          (ref, month) async => month == currentKey ? thisMonth : lastMonth,
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
  }

  Future<void> scrollToPanel(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('This Month vs Last Month'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the month-on-month rise', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpOverview(
      tester,
      thisMonth: payments(revenue: 15000, count: 6),
      lastMonth: payments(revenue: 12000, count: 5),
    );
    await scrollToPanel(tester);

    expect(find.text('This Month vs Last Month'), findsOneWidget);
    expect(find.text('PKR 15000'), findsWidgets);
    expect(find.text('25.0% more than last month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains a zero-revenue month instead of just showing 0',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The live situation: four bookings worth 10,000, none marked paid.
    await pumpOverview(
      tester,
      thisMonth: payments(revenue: 0, pending: 10000),
      lastMonth: payments(revenue: 0),
    );
    await scrollToPanel(tester);

    // The chart still has something to draw, and the reason is stated.
    expect(find.text('PKR 10000'), findsWidgets);
    expect(
      find.textContaining('Revenue counts only payments marked paid.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpOverview(
      tester,
      thisMonth: payments(revenue: 1234567, pending: 7654321, count: 40),
      lastMonth: payments(revenue: 987654, count: 22),
    );
    await scrollToPanel(tester);

    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}
