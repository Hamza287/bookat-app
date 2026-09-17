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

/// A slot's `time` field from the API is only its start — the resource's own
/// `attributes.durationMinutes` is what turns that into a customer-facing
/// range ("09:00 AM - 10:00 AM"). This must never silently truncate the end
/// time, and must survive a populated grid at narrow widths.
void main() {
  Business business({Object? durationMinutes = 90, List<dynamic>? resources}) {
    return BusinessModel.fromJson({
      'id': 'business-1',
      'name': 'Bats and Balls',
      'slug': 'bats-and-balls',
      'city': 'Islamabad',
      'address': 'Sohni Road',
      'ownerId': 'owner-1',
      'settings': {'currency': 'PKR'},
      'resources': resources ??
          [
            {
              'id': 'resource-1',
              'name': 'Main Field',
              'basePrice': 3500,
              'isActive': true,
              'attributes': {
                'durationMinutes': ?durationMinutes,
              },
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
            SlotAvailability(time: '11:00 AM', available: true),
            SlotAvailability(time: '12:00 PM', available: true),
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

  /// The slot grid sits below the hero, venue selector and date strip in the
  /// page's `CustomScrollView` — like the reviews section, it isn't built
  /// until scrolled into view (a `SliverList` only mounts children near the
  /// viewport), so tests must scroll down before asserting on it.
  Future<void> scrollToSlots(WidgetTester tester) async {
    // Nothing is pre-selected: step 2 (dates + slots) only renders once the
    // customer has picked a venue.
    await tester.tap(find.text('Main Field').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Available Slots'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows each slot as a start -> end range, not just the start',
      (tester) async {
    final value = business(durationMinutes: 90);
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToSlots(tester);

    // 90-minute slots starting at 09:00 AM and 10:00 AM.
    expect(find.text('09:00 AM - 10:30 AM'), findsOneWidget);
    expect(find.text('10:00 AM - 11:30 AM'), findsOneWidget);
    // The bare start time must not appear on its own anywhere.
    expect(find.text('09:00 AM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('defaults to a 60-minute range when no duration is set',
      (tester) async {
    final value = business(durationMinutes: null);
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToSlots(tester);

    expect(find.text('09:00 AM - 10:00 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reads a string duration the same as a numeric one',
      (tester) async {
    final value = business(durationMinutes: '45');
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToSlots(tester);

    expect(find.text('09:00 AM - 09:45 AM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'selecting a slot still keys off its start time and updates the summary',
      (tester) async {
    final value = business(durationMinutes: 60);
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();
    await scrollToSlots(tester);

    await tester.tap(find.text('09:00 AM - 10:00 AM'));
    await tester.pumpAndSettle();

    // The booking summary (further down) should now show the same range —
    // scroll to bring it into view before asserting.
    await tester.dragUntilVisible(
      find.text('Booking Summary'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('09:00 AM - 10:00 AM'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(360, 740)]) {
    testWidgets('renders the populated slot grid without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final value = business(durationMinutes: 90);
      final container = buildContainer(value);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await tester.pumpWidget(harness(container, value));
      await tester.pumpAndSettle();
      await scrollToSlots(tester);

      expect(tester.takeException(), isNull);
    });
  }
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}
