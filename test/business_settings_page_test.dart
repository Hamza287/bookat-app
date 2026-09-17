import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/features/booking/data/models/business_model.dart';
import 'package:bookat/src/features/booking/domain/entities/business.dart';
import 'package:bookat/src/features/business_admin/presentation/pages/business_settings_page.dart'
    show BusinessSettingsView, businessSettingsTabsKey;
import 'package:bookat/src/features/business_admin/presentation/providers/business_admin_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the settings screen against layout overflow and the dropdown
/// assertions that fire when stored values fall outside the offered options.
void main() {
  Business business({
    String currency = 'PKR',
    String windowUnit = 'HOURS',
    Map<String, dynamic>? extraSettings,
  }) {
    return BusinessModel.fromJson({
      'id': 'business-1',
      'name': 'Bats and Balls',
      'slug': 'bats-and-balls-ht0pppn',
      'city': 'Islamabad',
      'address': 'i10 markaz opposite h# 1101, sohni road, Islamabad, Pakistan',
      'type': 'TIME_SLOT',
      'businessModel': 'VENUE_BASED',
      'ownerId': 'owner-1',
      'settings': {
        'currency': currency,
        'operatingHours': [
          for (var day = 0; day < 7; day++)
            {
              'dayOfWeek': day,
              'startTime': '09:00',
              'endTime': '00:00',
              'isOffDay': day == 0,
            },
        ],
        'cancellationPolicy': {
          'isAllowed': true,
          'windowValue': 24,
          'windowUnit': windowUnit,
        },
        'themePrimaryColor': '#2563eb',
        ...?extraSettings,
      },
    });
  }

  Widget harness(Business value) {
    return ProviderScope(
      overrides: [
        activeBusinessProvider.overrideWith(() => _StubActiveBusiness(value)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: BusinessSettingsView()),
      ),
    );
  }

  /// Matches only the tab pill, never a panel heading with the same wording.
  Finder tabNamed(String label) {
    return find.descendant(
      of: find.byKey(businessSettingsTabsKey),
      matching: find.text(label),
    );
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      tabNamed(label),
      120,
      scrollable: find.descendant(
        of: find.byKey(businessSettingsTabsKey),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(tabNamed(label));
    await tester.pumpAndSettle();
  }

  Future<void> visitEveryTab(WidgetTester tester) async {
    const tabs = [
      'General Info',
      'Operating Hours',
      'Holidays & Closures',
      'Booking Page',
    ];

    for (final tab in tabs) {
      await openTab(tester, tab);
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab tab threw while rendering',
      );
    }
  }

  for (final size in const [Size(320, 640), Size(411, 891), Size(800, 1280)]) {
    testWidgets('renders every tab without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(business()));
      await tester.pumpAndSettle();

      await visitEveryTab(tester);
    });
  }

  testWidgets('survives a currency the picker does not offer', (tester) async {
    await tester.pumpWidget(harness(business(currency: 'pkr')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PKR'), findsWidgets);
  });

  testWidgets('survives an unknown cancellation window unit', (tester) async {
    await tester.pumpWidget(harness(business(windowUnit: 'MINUTES')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows all seven days with Sunday marked closed', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(business()));
    await tester.pumpAndSettle();
    await openTab(tester, 'Operating Hours');

    for (final day in const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ]) {
      expect(find.text(day), findsOneWidget, reason: '$day row missing');
    }
    expect(find.text('Closed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StubActiveBusiness extends ActiveBusinessController {
  _StubActiveBusiness(this._business);

  final Business _business;

  @override
  Business? build() => _business;
}
