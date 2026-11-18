import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookat/src/features/auth/presentation/pages/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signup creates customer accounts only. Business accounts still exist, but
/// they are not something a visitor can create for themselves.
void main() {
  late _FakeRepository repository;

  Future<void> pumpSignup(WidgetTester tester) async {
    repository = _FakeRepository();

    final container = ProviderContainer(
      overrides: [
        useMockDataProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RegisterPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows both options, with Customer selected", (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSignup(tester);

    // Business is no longer a form mode, so the button label never changes.
    expect(find.text("Create business account"), findsNothing);
    expect(find.text("Create customer account"), findsOneWidget);
  });

  testWidgets("offers Business as a link out, not a form mode", (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSignup(tester);

    // Both options stay visible at the top, where they always were. Business
    // is an exit to the website rather than a second form, so it carries an
    // open-in-new icon and never becomes the selected state.
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the signup screen fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSignup(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registers as a customer', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSignup(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Hamza',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      'Ibrahim',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'hamza@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '03001234567',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Hamza@287',
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Create customer account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.lastRole, Role.customer);
  });
}

class _FakeRepository implements AuthRepository {
  Role? lastRole;

  @override
  Future<Result<AppUser>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  }) async {
    lastRole = role;
    return Success(
      AppUser(
        id: 'user-1',
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
        isActive: true,
        isVerified: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        ownedBusinesses: const [],
      ),
    );
  }

  @override
  Future<AuthSession?> readSession() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
