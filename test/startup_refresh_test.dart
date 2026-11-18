import 'dart:convert';

import 'package:bookat/src/app/bookat_app.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reproduces the reported situation exactly: the app is opened with an access
/// token that has already expired, and a refresh token that is still good.
///
/// The user must be able to carry on working — the app should exchange the
/// refresh token for a new access token before anything is used, without being
/// asked to sign in again.
void main() {
  String jwt({required Duration expiresIn}) {
    String segment(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

    final exp = DateTime.now().toUtc().add(expiresIn);
    return '${segment({'alg': 'HS256'})}'
        '.${segment({'sub': 'user-1', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}'
        '.sig';
  }

  AuthSession sessionWith({required String accessToken}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: jwt(expiresIn: const Duration(days: 6)),
      user: AppUser(
        id: 'user-1',
        email: 'hamzaibrahimflutter@gmail.com',
        firstName: 'hamza',
        lastName: 'ibrahim',
        phone: '03044540987',
        role: Role.customer,
        isActive: true,
        isVerified: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        ownedBusinesses: const [],
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester, _FakeRepository repository) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useMockDataProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: const BookatApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an expired access token is renewed on app start',
      (tester) async {
    final expired = jwt(expiresIn: const Duration(hours: -2));
    final repository = _FakeRepository(stored: sessionWith(accessToken: expired));

    await pumpApp(tester, repository);

    // The refresh endpoint was called once, with the stored refresh token.
    expect(repository.refreshCalls, 1);
    expect(
      repository.lastRefreshTokenSent,
      repository.stored!.refreshToken,
    );
    // And the live session now carries the new token, not the expired one.
    expect(repository.stored!.accessToken, 'renewed-access-token');
    // The user is still signed in — no bounce to the login screen.
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('a token with hours left is left alone', (tester) async {
    final fresh = jwt(expiresIn: const Duration(hours: 10));
    final repository = _FakeRepository(stored: sessionWith(accessToken: fresh));

    await pumpApp(tester, repository);

    // No point spending a network call on a token that is still good.
    expect(repository.refreshCalls, 0);
  });

  testWidgets('a signed-out user triggers no refresh', (tester) async {
    final repository = _FakeRepository(stored: null);

    await pumpApp(tester, repository);

    expect(repository.refreshCalls, 0);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}

class _FakeRepository implements AuthRepository {
  _FakeRepository({required this.stored});

  AuthSession? stored;
  int refreshCalls = 0;
  String? lastRefreshTokenSent;

  @override
  Future<AuthSession?> readSession() async => stored;

  @override
  Future<Result<AuthSession>> refreshSession({
    required String refreshToken,
  }) async {
    refreshCalls++;
    lastRefreshTokenSent = refreshToken;

    final renewed = stored!.copyWith(accessToken: 'renewed-access-token');
    stored = renewed;
    return Success(renewed);
  }

  @override
  Future<void> saveSession(AuthSession session) async {
    stored = session;
  }

  @override
  Future<void> clearSession() async {
    stored = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
