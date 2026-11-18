import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/business_admin/data/models/business_payment_model.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_stats.dart';
import 'package:bookat/src/features/business_admin/domain/repositories/business_admin_repository.dart';
import 'package:bookat/src/features/business_admin/presentation/pages/business_admin_home_page.dart';
import 'package:bookat/src/features/business_admin/presentation/providers/business_admin_providers.dart';
import 'package:bookat/src/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settling a payment used to invalidate the whole month, which sent the tab
/// back through its loading state — the entire screen flashed to change one
/// row. These drive the real screen and check that the rows update in place,
/// and that ticking several sends one bulk request rather than one per row.
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
            'amount': 2500,
            'currency': 'PKR',
            'method': 'VENUE',
            'status': 'PENDING',
            'createdAt': '2026-08-04T21:55:12.654Z',
            'booking': {
              'startTime': '2026-08-07T16:00:00.000Z',
              'customer': {
                'firstName': 'Customer',
                'lastName': '$i',
                'phone': '03489366944',
              },
              'resource': {'name': 'L Field'},
            },
          },
      ],
      'stats': {
        'totalRevenue': 0,
        'numberOfPayments': 0,
        'averagePayment': 0,
        'pendingRevenue': 7500,
        'methodBreakdown': {
          'CASH': 0,
          'ONLINE': 0,
          'CARD': 0,
          'BANK_TRANSFER': 0,
        },
      },
      'meta': {'total': 3},
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

  late _SpyRepository repository;

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    repository = _SpyRepository(payments());

    return ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        // The real payments notifier runs on top of this, so settling goes
        // through the code the screen actually uses.
        businessAdminRepositoryProvider.overrideWithValue(repository),
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
      ],
    );
  }

  Future<void> openPayments(WidgetTester tester) async {
    await tester.tap(find.text('Payments').first);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpPayments(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    await openPayments(tester);
    return container;
  }

  /// Payment cards are tall, so a row further down the list starts off screen
  /// and has to be scrolled to before it can be tapped.
  Future<void> tick(WidgetTester tester, int index) async {
    final checkbox = find.byType(Checkbox).at(index);
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  }

  testWidgets('every pending payment can be ticked', (tester) async {
    await pumpPayments(tester);

    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('3 payments pending'), findsOneWidget);
  });

  testWidgets('ticking rows reveals the bulk bar', (tester) async {
    await pumpPayments(tester);

    await tick(tester, 0);
    await tick(tester, 1);

    expect(find.text('2 of 3 selected'), findsOneWidget);
    expect(find.text('Mark 2 payments as paid'), findsOneWidget);
  });

  testWidgets('select all ticks every pending row', (tester) async {
    await pumpPayments(tester);

    await tester.tap(find.text('Select all'));
    await tester.pump();

    expect(find.text('3 of 3 selected'), findsOneWidget);
    expect(find.text('Mark 3 payments as paid'), findsOneWidget);
  });

  testWidgets('settling the selection sends one bulk request', (tester) async {
    await pumpPayments(tester);

    await tester.tap(find.text('Select all'));
    await tester.pump();

    await tester.tap(find.widgetWithText(InkWell, 'Mark as Paid').last);
    await tester.pumpAndSettle();

    // One call carrying every id, not one call per payment.
    expect(repository.bulkCalls, 1);
    expect(
      repository.bulkPaymentIds,
      containsAll(<String>['payment-0', 'payment-1', 'payment-2']),
    );
    expect(repository.bulkStatus, PaymentStatus.paid.value);

    // The bulk endpoint carries no method, so each one is written first.
    expect(repository.methodCalls, 3);
    expect(repository.lastMethod, PaymentMethod.cash.value);
  });

  testWidgets('the rows update without the screen reloading', (tester) async {
    await pumpPayments(tester);

    await tick(tester, 0);
    await tester.tap(find.widgetWithText(InkWell, 'Mark as Paid').last);

    // Frame by frame, because the flash this guards against lasted exactly
    // one rebuild. Asserting on a provider's state is not enough — the bug
    // this replaces lived in a *different* provider from the one the screen
    // watched, so the check has to be what the screen actually renders.
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byType(AppShimmerBox),
        findsNothing,
        reason: 'the skeleton appeared on frame $frame',
      );
      // The payment list stays mounted throughout.
      expect(find.text('Revenue by Method'), findsOneWidget);
    }

    await tester.pumpAndSettle();

    // The settled row lost its checkbox; the other two kept theirs.
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('2 payments pending'), findsOneWidget);
  });

  testWidgets('a bulk settle does not reload the screen either',
      (tester) async {
    await pumpPayments(tester);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Mark as Paid').last);

    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byType(AppShimmerBox),
        findsNothing,
        reason: 'the skeleton appeared on frame $frame',
      );
    }

    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}

/// Serves one month of payments and records how they were settled.
class _SpyRepository implements BusinessAdminRepository {
  _SpyRepository(this._payments);

  BusinessPayments _payments;

  int bulkCalls = 0;
  int methodCalls = 0;
  List<String>? bulkPaymentIds;
  String? bulkStatus;
  String? lastMethod;

  @override
  Future<Result<BusinessPayments>> getBusinessPayments({
    required String businessId,
    required String accessToken,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    return Success(_payments);
  }

  @override
  Future<Result<void>> bulkUpdatePaymentStatus({
    required List<String> paymentIds,
    required String accessToken,
    required String status,
  }) async {
    bulkCalls++;
    bulkPaymentIds = paymentIds;
    bulkStatus = status;

    // Mirror the server, so the background reconcile agrees with the rows
    // already on screen rather than reverting them.
    _payments = _payments.withSettled(
      paymentIds: paymentIds.toSet(),
      status: status,
      method: lastMethod,
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> updatePaymentStatus({
    required String paymentId,
    required String accessToken,
    required String status,
  }) async {
    _payments = _payments.withSettled(
      paymentIds: {paymentId},
      status: status,
      method: lastMethod,
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> updatePaymentMethod({
    required String paymentId,
    required String accessToken,
    required String method,
  }) async {
    methodCalls++;
    lastMethod = method;
    return const Success<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
