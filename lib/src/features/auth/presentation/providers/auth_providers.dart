import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependency_providers.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../../domain/entities/auth_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final authSubmissionLoadingProvider = StateProvider.autoDispose<bool>((_) => false);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() {
    return ref.watch(authRepositoryProvider).readSession();
  }

  Future<String?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required Role role,
  }) async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    final result = await ref.read(registerUserProvider)(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: role,
    );

    ref.read(authSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success() => null,
      Fail(:final failure) => failure.message,
    };
  }

  Future<String?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    final result = await ref.read(verifyOtpProvider)(email: email, otp: otp);
    ref.read(authSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success() => null,
      Fail(:final failure) => failure.message,
    };
  }

  Future<String?> verifyOtpAndLogin({
    required String email,
    required String password,
    required String otp,
  }) async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    final verification = await ref.read(verifyOtpProvider)(
      email: email,
      otp: otp,
    );

    switch (verification) {
      case Fail(:final failure):
        ref.read(authSubmissionLoadingProvider.notifier).state = false;
        return failure.message;
      case Success():
        final loginResult = await ref.read(loginUserProvider)(
          email: email,
          password: password,
        );

        return switch (loginResult) {
          Success(:final data) => _setSession(data),
          Fail(:final failure) => _setFailure(failure),
        };
    }
  }

  /// Asks for a reset code. Returns the address it was sent to on success, so
  /// the next screen can name the inbox to check; the failure message is
  /// carried in [PasswordResetOutcome.error] instead.
  Future<PasswordResetOutcome> requestPasswordReset(
    String emailOrUsername,
  ) async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    final result = await ref.read(requestPasswordResetProvider)(
      emailOrUsername: emailOrUsername,
    );
    ref.read(authSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success(:final data) => PasswordResetOutcome.sent(
          email: data.email.isEmpty ? emailOrUsername : data.email,
          message: data.message,
        ),
      Fail(:final failure) => PasswordResetOutcome.failed(failure.message),
    };
  }

  /// Completes the reset. Returns null on success, or a message to show.
  ///
  /// No session is issued by this endpoint, so the user is left signed out and
  /// signs in with the new password.
  Future<String?> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    final result = await ref.read(resetPasswordProvider)(
      emailOrUsername: emailOrUsername,
      otp: otp,
      newPassword: newPassword,
    );
    ref.read(authSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success() => null,
      Fail(:final failure) => failure.message,
    };
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    final result = await ref.read(loginUserProvider)(
      email: email,
      password: password,
    );

    return switch (result) {
      Success(:final data) => _setSession(data),
      Fail(:final failure) => _setFailure(failure),
    };
  }

  /// Writes an edited business back into the signed-in user's owned list and
  /// persists the session.
  ///
  /// `ownedBusinesses` is captured at login and cached in shared preferences,
  /// so without this a saved settings change would be lost on the next app
  /// start — the stale login snapshot would win.
  Future<void> updateOwnedBusiness(Business business) async {
    final session = state.valueOrNull;
    if (session == null) {
      return;
    }

    final existing = session.user.ownedBusinesses;
    final hasBusiness = existing.any((item) => item.id == business.id);
    final businesses = hasBusiness
        ? existing
            .map((item) => item.id == business.id ? business : item)
            .toList(growable: false)
        : [business, ...existing];

    final updated = session.copyWith(
      user: session.user.copyWith(ownedBusinesses: businesses),
    );

    state = AsyncData(updated);
    await ref.read(authRepositoryProvider).saveSession(updated);
  }

  /// Called by the network layer when a refresh-token exchange fails (the
  /// refresh token itself is invalid or expired). The interceptor has already
  /// cleared the stored session; this drops it from state too so the app
  /// navigates to the login screen immediately instead of showing 401s.
  void forceSignOut() {
    ref.read(authSubmissionLoadingProvider.notifier).state = false;
    state = const AsyncData(null);
  }

  Future<void> logout() async {
    final session = state.valueOrNull;

    // Drop the local session first so the app switches to signed-out
    // immediately. Revoking the push token needs the network and must never
    // sit between the user's tap and the login screen.
    await ref.read(authRepositoryProvider).clearSession();
    state = const AsyncData(null);

    unawaited(_revokeDeviceToken(session));
  }

  /// Best-effort push-token teardown: unregister this device server-side, drop
  /// the token at Firebase, then clear the cached value so the next sign-in
  /// registers a freshly issued token instead of the revoked one.
  Future<void> _revokeDeviceToken(AuthSession? session) async {
    final token = await _deviceToken();

    if (session != null && token != null) {
      await ref
          .read(notificationTokenRegistrationServiceProvider)
          .unregisterToken(
            accessToken: session.accessToken,
            token: token,
          );
    }

    await ref.read(fcmTokenServiceProvider).deleteDeviceToken();
    ref.invalidate(fcmDeviceTokenProvider);
  }

  Future<String?> _deviceToken() async {
    final cached = ref.read(fcmDeviceTokenProvider).valueOrNull;
    if (cached != null) {
      return cached;
    }

    // The token future can still be in flight. Waiting briefly beats skipping
    // the unregister, which would leave the device receiving pushes.
    try {
      return await ref
          .read(fcmDeviceTokenProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('FCM token unavailable during logout: $error');
      return null;
    }
  }

  String? _setSession(AuthSession session) {
    ref.read(authSubmissionLoadingProvider.notifier).state = false;
    state = AsyncData(session);
    return null;
  }

  String _setFailure(Failure failure) {
    ref.read(authSubmissionLoadingProvider.notifier).state = false;
    state = const AsyncData(null);
    return failure.message;
  }
}

/// Result of asking for a reset code.
///
/// The screen needs two things back — the address the code went to, or a reason
/// it did not — and a bare `String?` error cannot carry both.
class PasswordResetOutcome {
  const PasswordResetOutcome._({this.email, this.message, this.error});

  const PasswordResetOutcome.sent({
    required String email,
    required String message,
  }) : this._(email: email, message: message);

  const PasswordResetOutcome.failed(String error) : this._(error: error);

  /// Address the code was sent to, present only on success.
  final String? email;

  /// The server's confirmation message, present only on success.
  final String? message;

  /// Why the request failed, present only on failure.
  final String? error;

  bool get isSent => error == null;
}
