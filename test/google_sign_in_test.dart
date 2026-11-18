import 'package:bookat/src/app/app_theme.dart';
import 'package:bookat/src/app/dependency_providers.dart';
import 'package:bookat/src/core/constants/constants.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/errors/failure.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:bookat/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bookat/src/features/auth/data/datasources/google_identity_service.dart';
import 'package:bookat/src/features/auth/data/models/app_user_model.dart';
import 'package:bookat/src/features/auth/data/models/auth_session_model.dart';
import 'package:bookat/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bookat/src/features/auth/domain/entities/app_user.dart';
import 'package:bookat/src/features/auth/domain/entities/auth_session.dart';
import 'package:bookat/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookat/src/features/auth/presentation/pages/login_page.dart';
import 'package:bookat/src/features/auth/presentation/pages/register_page.dart';
import 'package:bookat/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookat/src/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Google sign-in posts a *Firebase* ID token to `POST /api/auth/google`:
///
/// ```
/// {"idToken": "<firebase id token>", "role": "CUSTOMER"}
/// ```
///
/// The server verifies it with the Firebase Admin SDK and answers with the same
/// session shape as `/auth/login`.
void main() {
  group('repository', () {
    test('posts the Firebase ID token and the customer role', () async {
      final dataSource = _SpyDataSource();
      final local = _RecordingLocalDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: dataSource,
        localDataSource: local,
        googleIdentityService: _StubIdentityService(idToken: 'firebase-id-token'),
      );

      final result = await repository.signInWithGoogle();

      expect(dataSource.idToken, 'firebase-id-token');
      expect(dataSource.role, Role.customer);
      expect(result, isA<Success<AuthSession?>>());

      // The session has to be persisted, or a restart would land the user back
      // on the login screen.
      expect(local.saved?.accessToken, 'access-1');
    });

    test('a dismissed picker is not a failure', () async {
      final dataSource = _SpyDataSource();
      final local = _RecordingLocalDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: dataSource,
        localDataSource: local,
        googleIdentityService: const _StubIdentityService(idToken: null),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Success<AuthSession?>>());
      expect((result as Success<AuthSession?>).data, isNull);

      // Nothing was attempted, so nothing was sent or stored.
      expect(dataSource.idToken, isNull);
      expect(local.saved, isNull);
    });

    test("surfaces the service's own wording for a Google failure", () async {
      final repository = AuthRepositoryImpl(
        remoteDataSource: _SpyDataSource(),
        localDataSource: _RecordingLocalDataSource(),
        googleIdentityService: const _StubIdentityService(
          error: GoogleIdentityException('Google sign-in is not configured.'),
        ),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Fail<AuthSession?>>());
      expect(
        (result as Fail<AuthSession?>).failure.message,
        'Google sign-in is not configured.',
      );
    });
  });

  group('controller', () {
    test('signs the user in', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeRepository(session: _session()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final error =
          await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(error, isNull);
      expect(container.read(authControllerProvider).valueOrNull, isNotNull);
      expect(container.read(googleSubmissionLoadingProvider), isFalse);
    });

    test('a dismissed picker leaves the user signed out, with no message',
        () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
      );
      addTearDown(container.dispose);

      final error =
          await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(error, isNull);
      expect(container.read(authControllerProvider).valueOrNull, isNull);
      // The spinner must stop even though nothing happened.
      expect(container.read(authSubmissionLoadingProvider), isFalse);
      expect(container.read(googleSubmissionLoadingProvider), isFalse);
    });

    test('returns the failure message for the alert', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeRepository(
              failure: const ServerFailure(message: 'Google account blocked.'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final error =
          await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(error, 'Google account blocked.');
      expect(container.read(googleSubmissionLoadingProvider), isFalse);
    });
  });

  group('screens', () {
    Future<void> pump(
      WidgetTester tester,
      Widget page, {
      Size size = const Size(412, 915),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          useMockDataProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(_FakeRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light(), home: page),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sign in offers Google', (tester) async {
      await pump(tester, const LoginPage());

      expect(
        find.widgetWithText(GoogleSignInButton, AppStrings.continueWithGoogle),
        findsOneWidget,
      );
      expect(find.byType(AuthDivider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign up offers Google', (tester) async {
      await pump(tester, const RegisterPage());

      expect(
        find.widgetWithText(GoogleSignInButton, AppStrings.signUpWithGoogle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign in fits a small phone', (tester) async {
      await pump(tester, const LoginPage(), size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign up fits a small phone', (tester) async {
      await pump(tester, const RegisterPage(), size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });
  });
}

AuthSession _session() {
  return AuthSessionModel(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    user: AppUserModel.fromJson(const {
      'id': 'user-1',
      'email': 'hamza@example.com',
      'role': 'CUSTOMER',
    }),
  );
}

class _StubIdentityService implements GoogleIdentityService {
  const _StubIdentityService({this.idToken, this.error});

  final String? idToken;
  final GoogleIdentityException? error;

  @override
  Future<String?> obtainIdToken() async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return idToken;
  }

  @override
  Future<void> signOut() async {}
}

class _SpyDataSource implements AuthRemoteDataSource {
  String? idToken;
  Role? role;

  @override
  Future<AuthSessionModel> signInWithGoogle({
    required String idToken,
    Role role = Role.customer,
  }) async {
    this.idToken = idToken;
    this.role = role;
    return AuthSessionModel.fromJson(const {
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'user': {'id': 'user-1', 'email': 'hamza@example.com', 'role': 'CUSTOMER'},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}

class _RecordingLocalDataSource implements AuthLocalDataSource {
  AuthSessionModel? saved;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    saved = session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}

/// Stands in for the whole repository so the controller can be driven without
/// the platform SDKs. No arguments at all means a dismissed picker.
class _FakeRepository implements AuthRepository {
  _FakeRepository({this.session, this.failure});

  final AuthSession? session;
  final Failure? failure;

  @override
  Future<Result<AuthSession?>> signInWithGoogle({
    Role role = Role.customer,
  }) async {
    final error = failure;
    if (error != null) {
      return Fail(error);
    }
    return Success(session);
  }

  @override
  Future<void> signOutOfGoogle() async {}

  @override
  Future<AuthSession?> readSession() async => null;

  @override
  Future<Result<AppUser>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  }) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
