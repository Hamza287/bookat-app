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

/// Step 1 of the booking flow is the venue tile list, and nothing else — the
/// interactive facility map that used to sit above it has been removed. Every
/// resource is offered as a tile, including sub-areas ("L Field" / "R Field")
/// that record a `parentId`, and nothing is selected until the customer taps
/// one.
void main() {
  Business businessWithSplitField() {
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
        {
          'id': 'left-1',
          'name': 'L Field',
          'basePrice': 2500,
          'isActive': true,
          'parentId': 'main-1',
        },
        {
          'id': 'right-1',
          'name': 'R field',
          'basePrice': 2500,
          'isActive': true,
          'parentId': 'main-1',
        },
      ],
    });
  }

  Business businessWithFlatResources() {
    return BusinessModel.fromJson({
      'id': 'business-2',
      'name': 'City Salon',
      'slug': 'city-salon',
      'city': 'Lahore',
      'address': 'Mall Road',
      'ownerId': 'owner-2',
      'settings': {'currency': 'PKR'},
      'resources': [
        {'id': 'chair-1', 'name': 'Chair 1', 'basePrice': 1000, 'isActive': true},
        {'id': 'chair-2', 'name': 'Chair 2', 'basePrice': 1000, 'isActive': true},
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

  testWidgets('offers every resource as a tile, with no facility map',
      (tester) async {
    final value = businessWithSplitField();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();

    expect(find.text('Interactive Facility Map'), findsNothing);
    // Parent and sub-areas alike are bookable, each shown exactly once now
    // that the map no longer renders a second copy of them.
    expect(find.text('Main Field'), findsOneWidget);
    expect(find.text('Left Field'), findsOneWidget);
    expect(find.text('Right Field'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flat resources are listed the same way', (tester) async {
    final value = businessWithFlatResources();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();

    expect(find.text('Interactive Facility Map'), findsNothing);
    expect(find.text('Chair 1'), findsOneWidget);
    expect(find.text('Chair 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'opens with no venue selected and reveals date + slots only after one is '
      'picked', (tester) async {
    final value = businessWithSplitField();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();

    // Step 2 is replaced by a prompt until the customer chooses a venue.
    await tester.dragUntilVisible(
      find.text('Select a venue to continue'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select a venue to continue'), findsOneWidget);
    expect(find.text('Choose Date & Time'), findsNothing);
    expect(find.text('Available Slots'), findsNothing);
    expect(find.text('Booking Summary'), findsNothing);

    // Scroll back to the top so the tiles are on screen, then pick a sub-area.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Left Field'));
    await tester.pumpAndSettle();

    expect(find.text('Select a venue to continue'), findsNothing);

    await tester.dragUntilVisible(
      find.text('Choose Date & Time'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Date & Time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a sub-area tile carries it into the booking summary',
      (tester) async {
    final value = businessWithSplitField();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Left Field'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Booking Summary'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(find.text('Left Field'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the calendar tile opens a date picker with today as the earliest date',
      (tester) async {
    final value = businessWithSplitField();
    final container = buildContainer(value);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await tester.pumpWidget(harness(container, value));
    await tester.pumpAndSettle();

    // The date strip only exists after a venue is picked.
    await tester.tap(find.text('Left Field'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('More'),
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    final datePicker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final today = DateTime.now();
    expect(
      datePicker.firstDate,
      DateTime(today.year, today.month, today.day),
    );

    // Dismiss without picking.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(360, 740)]) {
    testWidgets('renders the venue tiles without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final value = businessWithSplitField();
      final container = buildContainer(value);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await tester.pumpWidget(harness(container, value));
      await tester.pumpAndSettle();

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
