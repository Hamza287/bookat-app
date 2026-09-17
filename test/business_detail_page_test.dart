import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/constants/constants.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/booking/presentation/pages/business_detail_page.dart';
import 'package:bookat/src/features/booking/presentation/providers/booking_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The customer-facing booking screen renders in the venue owner's chosen
/// colours, and must survive small screens and sparse API data.
void main() {
  Business business({Map<String, dynamic>? settings, List<dynamic>? resources}) {
    return BusinessModel.fromJson({
      'id': 'business-1',
      'name': 'Bats and Balls',
      'slug': 'bats-and-balls-ht0pppn',
      'description': 'Floodlit cricket and futsal grounds.',
      'city': 'Islamabad',
      'address': 'i10 markaz opposite h# 1101, sohni road, Islamabad, Pakistan',
      'type': 'TIME_SLOT',
      'businessModel': 'VENUE_BASED',
      'ownerId': 'owner-1',
      'averageRating': 4.5,
      'reviewCount': 12,
      'settings': settings ??
          {
            'currency': 'PKR',
            'themePrimaryColor': '#ef4444',
            'themeLightBgColor': '#fffbeb',
            'themeLightSurfaceColor': '#ffffff',
            'themeLightTextColor': '#1c1917',
            'themeDarkBgColor': '#0c0a09',
            'themeDarkSurfaceColor': '#1c1917',
            'themeDarkTextColor': '#fafaf9',
          },
      'resources': resources ??
          [
            {
              'id': 'resource-1',
              'name': 'Main Field',
              'basePrice': 3500,
              'isActive': true,
            },
            {
              'id': 'resource-2',
              'name': 'L Field',
              'basePrice': 2500,
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

  Widget harness(Business value, {ThemeMode mode = ThemeMode.light}) {
    return ProviderScope(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        authControllerProvider.overrideWith(() => _StubAuth(session)),
        businessDetailsProvider(value.slug).overrideWith((ref) async => value),
        availabilityProvider.overrideWith((ref, arg) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: BusinessDetailPage(business: value),
      ),
    );
  }

  for (final size in const [Size(320, 640), Size(411, 891), Size(800, 1280)]) {
    testWidgets('renders without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(business()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bats and Balls'), findsWidgets);
    });
  }

  testWidgets('paints in the venue palette, not app branding', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(business()));
    await tester.pumpAndSettle();

    final scope = tester.element(find.byType(BusinessDetailPage));
    final palette = Theme.of(scope).extension<AppPalette>()!;

    // The page sits above the scope, so read from inside the subtree instead.
    final inner = tester.element(find.byType(CustomScrollView));
    final venue = Theme.of(inner).extension<AppPalette>()!;

    expect(palette.primary, AppPalette.light.primary);
    expect(venue.primary, const Color(0xFFEF4444));
    expect(venue.background, const Color(0xFFFFFBEB));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the dark colour set in dark mode', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(business(), mode: ThemeMode.dark));
    await tester.pumpAndSettle();

    final inner = tester.element(find.byType(CustomScrollView));
    final venue = Theme.of(inner).extension<AppPalette>()!;

    expect(venue.background, const Color(0xFF0C0A09));
    expect(venue.surface, const Color(0xFF1C1917));
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles a venue with no resources', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(business(resources: const [])));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to app branding when settings are bare',
      (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(business(settings: const {})));
    await tester.pumpAndSettle();

    final inner = tester.element(find.byType(CustomScrollView));
    final venue = Theme.of(inner).extension<AppPalette>()!;

    // BusinessTheme.defaults, which is the web dashboard's default palette.
    expect(venue.primary, const Color(0xFF2563EB));
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> build() async => _session;
}
