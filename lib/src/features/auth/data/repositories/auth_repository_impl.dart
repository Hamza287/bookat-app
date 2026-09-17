import 'package:dio/dio.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_verification_result.dart';
import '../../domain/entities/password_reset.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<Result<AppUser>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  }) async {
    try {
      final user = await _remoteDataSource.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
      );
      return Success(user);
    } catch (error) {
      return Fail(_mapFailure(error, fallback: 'We could not create your account.'));
    }
  }

  @override
  Future<Result<OtpVerificationResult>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final result = await _remoteDataSource.verifyOtp(email: email, otp: otp);
      if (!result.success) {
        return const Fail(ServerFailure(message: 'The verification code is not valid.'));
      }

      return Success(result);
    } catch (error) {
      return Fail(_mapFailure(error, fallback: 'We could not verify your email.'));
    }
  }

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      await _localDataSource.saveSession(session);
      return Success(session);
    } catch (error) {
      return Fail(_mapFailure(error, fallback: 'We could not sign you in.'));
    }
  }

  @override
  Future<AuthSession?> readSession() {
    return _localDataSource.readSession();
  }

  @override
  Future<void> saveSession(AuthSession session) {
    return _localDataSource.saveSession(AuthSessionModel.fromEntity(session));
  }

  @override
  Future<void> clearSession() {
    return _localDataSource.clearSession();
  }

  Failure _mapFailure(Object error, {required String fallback}) {
    if (error is FormatException) {
      return const ServerFailure(
        message: 'Something changed on our servers. Please try again later.',
      );
    }

    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const NetworkFailure(
          message: 'Please check your internet connection and try again.',
        );
      }

      return ServerFailure(message: _messageForStatus(error.response?.statusCode));
    }

    return UnexpectedFailure(message: fallback);
  }

  String _messageForStatus(int? statusCode) {
    return switch (statusCode) {
      400 => 'Please check the information and try again.',
      401 => 'The email or password is incorrect.',
      403 => 'You do not have access to this account.',
      404 => 'We could not find an account with this email.',
      409 => 'An account with this email already exists.',
      422 => 'Please check the highlighted information and try again.',
      429 => 'Too many attempts. Please wait a moment and try again.',
      final code when code != null && code >= 500 =>
        'The server is busy right now. Please try again shortly.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  @override
  Future<Result<PasswordResetRequest>> requestPasswordReset({
    required String emailOrUsername,
  }) async {
    try {
      final request = await _remoteDataSource.requestPasswordReset(
        emailOrUsername: emailOrUsername,
      );
      return Success(request);
    } catch (error) {
      return Fail(
        _mapResetFailure(
          error,
          fallback: 'We could not send a reset code. Please try again.',
        ),
      );
    }
  }

  @override
  Future<Result<PasswordResetConfirmation>> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final confirmation = await _remoteDataSource.resetPassword(
        emailOrUsername: emailOrUsername,
        otp: otp,
        newPassword: newPassword,
      );
      return Success(confirmation);
    } catch (error) {
      return Fail(
        _mapResetFailure(
          error,
          fallback: 'We could not reset your password. Please try again.',
        ),
      );
    }
  }

  /// The reset endpoints explain precisely what went wrong — an expired code, a
  /// password the server rejects, an unknown account — so the server's own
  /// sentence is shown when there is one. Falls back to [_mapFailure] for
  /// transport problems, which have no useful body.
  Failure _mapResetFailure(Object error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return ServerFailure(message: message);
        }
        // Nest validation errors arrive as a list of strings.
        if (message is List && message.isNotEmpty) {
          return ServerFailure(
            message: message.map((entry) => entry.toString()).join('\n'),
          );
        }
      }
    }

    return _mapFailure(error, fallback: fallback);
  }
}
