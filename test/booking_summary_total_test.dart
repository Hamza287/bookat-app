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

/// Reproduces the reported symptom directly: pick a venue, a date, and a
/// time slot, then check whether "Total Amount" actually shows a computed
/// value — not just that the underlying `_totalLabel` function is correct in
/// isolation.
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
          'id': 'main-1',
          'name': 'Main Field',
          'basePrice': 3500,
          'isActive': true,
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
            SlotAvailability(time: '10:00 AM', available: true),
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

  /// Nothing is pre-selected: step 2 (dates + slots) and the booking summary
  /// only render once the customer has picked a venue.
  Future<void> selectVenue(WidgetTester tester) async {
    await tester.tap(find.text('Main Field').last);
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows -- for total amount before any slot is picked',
      (tester) async {
    final value = business();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await selectVenue(tester);
    await scrollTo(tester, find.text('Total Amount'));

    expect(find.text('--'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates the total amount after picking one slot', (tester) async {
    final value = business();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await selectVenue(tester);
    await scrollTo(tester, find.text('09:00 AM - 10:00 AM'));

    await tester.tap(find.text('09:00 AM - 10:00 AM'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Total Amount'));

    expect(find.text('PKR 3500'), findsOneWidget);
    expect(find.text('--'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiplies the total by the number of selected slots',
      (tester) async {
    final value = business();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await selectVenue(tester);
    await scrollTo(tester, find.text('09:00 AM - 10:00 AM'));

    await tester.tap(find.text('09:00 AM - 10:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00 AM - 11:00 AM'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Total Amount'));

    expect(find.text('PKR 7000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}
