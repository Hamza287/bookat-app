import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/domain/entities/slot_availability.dart';
import 'package:bookat/src/features/booking/presentation/pages/business_detail_page.dart';
import 'package:bookat/src/features/booking/presentation/providers/booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real venue's price failed to total at all — traced to `num.tryParse`
/// silently returning null (and therefore a price of 0) whenever the API
/// sends the number formatted rather than bare. These pin every shape that's
/// now handled, so a regression here fails loudly instead of showing "--"
/// forever with no error.
void main() {
  Business businessWithResource(Map<String, dynamic> resourceExtra) {
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
          'id': 'main-1',
          'name': 'Main Field',
          'isActive': true,
          ...resourceExtra,
        },
      ],
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

  ProviderContainer buildContainer(Business value) {
    return ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        businessDetailsProvider(value.slug).overrideWith((ref) async => value),
        availabilityProvider.overrideWith(
          (ref, arg) async => const [
            SlotAvailability(time: '09:00 AM', available: true),
          ],
        ),
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

  Future<void> selectFirstSlotAndScrollToTotal(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Nothing is pre-selected: step 2 (dates + slots) only renders once the
    // customer has picked a venue.
    await tester.tap(find.text('Main Field').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('09:00 AM - 10:00 AM'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00 AM - 10:00 AM'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Total Amount'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a plain numeric basePrice still totals correctly', (tester) async {
    final value = businessWithResource({'basePrice': 3500});
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await selectFirstSlotAndScrollToTotal(tester);

    expect(find.text('PKR 3500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a comma-formatted price string still totals correctly',
      (tester) async {
    final value = businessWithResource({'basePrice': '3,500'});
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await selectFirstSlotAndScrollToTotal(tester);

    expect(find.text('PKR 3500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a currency-prefixed price string still totals correctly',
      (tester) async {
    final value = businessWithResource({'basePrice': 'PKR 3500'});
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await selectFirstSlotAndScrollToTotal(tester);

    expect(find.text('PKR 3500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a price nested under attributes still totals correctly',
      (tester) async {
    final value = businessWithResource({
      'attributes': {'basePrice': 3500},
    });
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await selectFirstSlotAndScrollToTotal(tester);

    expect(find.text('PKR 3500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a genuinely missing price falls back to -- rather than a wrong number',
      (tester) async {
    final value = businessWithResource(const {});
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await selectFirstSlotAndScrollToTotal(tester);

    expect(find.text('PKR'), findsOneWidget);
    expect(find.text('PKR 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}
