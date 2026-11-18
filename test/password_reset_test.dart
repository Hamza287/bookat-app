import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:bookat/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bookat/src/features/auth/data/datasources/google_identity_service.dart';
import 'package:bookat/src/features/auth/data/models/password_reset_model.dart';
import 'package:bookat/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bookat/src/features/auth/domain/entities/password_reset.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Password reset is two calls:
///
/// 1. `POST /auth/forgot-password` with `{emailOrUsername}` answers `201` with
///    `{message, email}` — the address the code was sent to.
/// 2. `POST /auth/reset-password` with `{emailOrUsername, otp, newPassword}`
///    answers `201` with `{message}` and **no session**.
///
/// Captured from the live API on 2026-09-16.
void main() {
  group('models', () {
    test('forgot-password response keeps the address the code went to', () {
      final request = PasswordResetRequestModel.fromJson({
        'message': 'Password reset OTP has been sent to your email address '
            '(hamzaibrahimflutter@gmail.com).',
        'email': 'hamzaibrahimflutter@gmail.com',
      });

      expect(request.email, 'hamzaibrahimflutter@gmail.com');
      expect(request.message, contains('Password reset OTP has been sent'));
    });

    test('reset-password response carries the confirmation message', () {
      final confirmation = PasswordResetConfirmationModel.fromJson({
        'message':
            'Password reset successful. You can now log in with your new password.',
      });

      expect(confirmation.message, contains('Password reset successful'));
    });

    test('missing fields degrade to empty rather than throwing', () {
      expect(PasswordResetRequestModel.fromJson({}).email, isEmpty);
      expect(PasswordResetConfirmationModel.fromJson({}).message, isEmpty);
    });
  });

  group('repository', () {
    late _SpyDataSource dataSource;
    late AuthRepositoryImpl repository;

    setUp(() {
      dataSource = _SpyDataSource();
      repository = AuthRepositoryImpl(
        remoteDataSource: dataSource,
        localDataSource: _UnusedLocalDataSource(),
        googleIdentityService: _UnusedGoogleIdentityService(),
      );
    });

    test('sends the identifier verbatim so a username still works', () async {
      final result = await repository.requestPasswordReset(
        emailOrUsername: 'hamza287',
      );

      expect(result, isA<Success<PasswordResetRequest>>());
      expect(dataSource.lastIdentifier, 'hamza287');
    });

    test('sends code and new password on reset', () async {
      final result = await repository.resetPassword(
        emailOrUsername: 'hamzaibrahimflutter@gmail.com',
        otp: '223027',
        newPassword: 'Hamza@287',
      );

      expect(result, isA<Success<PasswordResetConfirmation>>());
      expect(dataSource.lastOtp, '223027');
      expect(dataSource.lastNewPassword, 'Hamza@287');
    });

    test('surfaces the server message for an expired or wrong code', () async {
      dataSource.error = DioException(
        requestOptions: RequestOptions(path: '/auth/reset-password'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/reset-password'),
          statusCode: 400,
          data: {'message': 'Invalid or expired OTP'},
        ),
      );

      final result = await repository.resetPassword(
        emailOrUsername: 'a@b.com',
        otp: '000000',
        newPassword: 'Whatever1!',
      );

      // The server explains exactly what is wrong; a generic message would be
      // strictly less useful to the user.
      expect(
        result,
        isA<Fail<PasswordResetConfirmation>>().having(
          (fail) => fail.failure.message,
          'message',
          'Invalid or expired OTP',
        ),
      );
    });

    test('joins a list of validation messages', () async {
      dataSource.error = DioException(
        requestOptions: RequestOptions(path: '/auth/reset-password'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/auth/reset-password'),
          statusCode: 400,
          data: {
            'message': [
              'newPassword must be longer than or equal to 8 characters',
              'newPassword must contain a number',
            ],
          },
        ),
      );

      final result = await repository.resetPassword(
        emailOrUsername: 'a@b.com',
        otp: '223027',
        newPassword: 'short',
      );

      expect(
        result,
        isA<Fail<PasswordResetConfirmation>>().having(
          (fail) => fail.failure.message,
          'message',
          contains('must contain a number'),
        ),
      );
    });

    test('falls back to a readable message when the body has none', () async {
      dataSource.error = DioException(
        requestOptions: RequestOptions(path: '/auth/forgot-password'),
        type: DioExceptionType.connectionError,
      );

      final result = await repository.requestPasswordReset(
        emailOrUsername: 'a@b.com',
      );

      expect(
        result,
        isA<Fail<PasswordResetRequest>>().having(
          (fail) => fail.failure.message,
          'message',
          contains('internet connection'),
        ),
      );
    });
  });
}

class _SpyDataSource implements AuthRemoteDataSource {
  String? lastIdentifier;
  String? lastOtp;
  String? lastNewPassword;
  Object? error;

  @override
  Future<PasswordResetRequestModel> requestPasswordReset({
    required String emailOrUsername,
  }) async {
    lastIdentifier = emailOrUsername;
    if (error != null) {
      throw error!;
    }
    return const PasswordResetRequestModel(
      email: 'hamzaibrahimflutter@gmail.com',
      message: 'sent',
    );
  }

  @override
  Future<PasswordResetConfirmationModel> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) async {
    lastIdentifier = emailOrUsername;
    lastOtp = otp;
    lastNewPassword = newPassword;
    if (error != null) {
      throw error!;
    }
    return const PasswordResetConfirmationModel(message: 'ok');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}

/// Reset touches no local storage, so any call here is a mistake.
/// Password reset never touches Google.
class _UnusedGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<String?> obtainIdToken() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

class _UnusedLocalDataSource implements AuthLocalDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Password reset must not touch the stored session',
    );
  }
}
