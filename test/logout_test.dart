import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:bookat/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bookat/src/features/auth/data/datasources/google_identity_service.dart';
import 'package:bookat/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// `POST /auth/logout` ends the session server-side and detaches this device's
/// push token, so a signed-out user stops receiving notifications:
///
/// ```
/// Authorization: Bearer <accessToken>
/// {"fcmToken": "<device token>"}
/// ```
void main() {
  late _SpyDataSource dataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    dataSource = _SpyDataSource();
    repository = AuthRepositoryImpl(
      remoteDataSource: dataSource,
      localDataSource: _NoopLocalDataSource(),
      googleIdentityService: _UnusedGoogleIdentityService(),
    );
  });

  test('sends the access token and the device token', () async {
    final result = await repository.logout(
      accessToken: 'access-1',
      fcmToken: 'dQw4w9WgXcQ:APA91bH',
    );

    expect(result, isA<Success<void>>());
    expect(dataSource.lastAccessToken, 'access-1');
    expect(dataSource.lastFcmToken, 'dQw4w9WgXcQ:APA91bH');
  });

  test('still calls the endpoint when there is no device token', () async {
    // Firebase can fail to issue one; the session should still be ended rather
    // than skipping the call entirely.
    await repository.logout(accessToken: 'access-1', fcmToken: '');

    expect(dataSource.calls, 1);
    expect(dataSource.lastFcmToken, isEmpty);
  });

  test('a server failure is reported, not thrown', () async {
    // Logout runs in the background after the user is already signed out
    // locally, so this must never escape as an exception.
    dataSource.error = DioException(
      requestOptions: RequestOptions(path: '/auth/logout'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/logout'),
        statusCode: 401,
        data: {'message': 'Token already revoked'},
      ),
    );

    final result = await repository.logout(
      accessToken: 'stale',
      fcmToken: 'token',
    );

    expect(
      result,
      isA<Fail<void>>().having(
        (fail) => fail.failure.message,
        'message',
        'Token already revoked',
      ),
    );
  });

  test('being offline is reported, not thrown', () async {
    dataSource.error = DioException(
      requestOptions: RequestOptions(path: '/auth/logout'),
      type: DioExceptionType.connectionError,
    );

    final result = await repository.logout(
      accessToken: 'access-1',
      fcmToken: 'token',
    );

    expect(result, isA<Fail<void>>());
  });
}

class _SpyDataSource implements AuthRemoteDataSource {
  int calls = 0;
  String? lastAccessToken;
  String? lastFcmToken;
  Object? error;

  @override
  Future<void> logout({
    required String accessToken,
    required String fcmToken,
  }) async {
    calls++;
    lastAccessToken = accessToken;
    lastFcmToken = fcmToken;
    if (error != null) {
      throw error!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}

/// Logout reaches the server only; clearing storage is the controller's job.
/// Logging out does touch Google, but through the controller rather than the
/// repository method under test here.
class _UnusedGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String?> obtainIdToken() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

class _NoopLocalDataSource implements AuthLocalDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Local storage is not touched by logout()');
  }
}
