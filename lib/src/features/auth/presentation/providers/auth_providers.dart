import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/dependency_providers.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/jwt.dart';
import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../../domain/entities/auth_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final authSubmissionLoadingProvider = StateProvider.autoDispose<bool>((_) => false);

/// True only while the Google flow is running.
///
/// [authSubmissionLoadingProvider] disables every control on the screen, but
/// the spinner belongs to the button that was actually tapped — without this,
/// signing in by email would spin the Google button too.
final googleSubmissionLoadingProvider =
    StateProvider.autoDispose<bool>((_) => false);

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

  /// Signs in through Google.
  ///
  /// Returns null both when it worked and when the user dismissed the account
  /// picker — backing out is not an error, and the screens only show a message
  /// when one comes back.
  Future<String?> signInWithGoogle() async {
    ref.read(authSubmissionLoadingProvider.notifier).state = true;
    ref.read(googleSubmissionLoadingProvider.notifier).state = true;

    final result = await ref.read(signInWithGoogleProvider)(
      role: Role.customer,
    );

    ref.read(googleSubmissionLoadingProvider.notifier).state = false;

    return switch (result) {
      Success(:final data?) => _setSession(data),
      Success() => _clearSubmission(),
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

  /// Adopts tokens the network layer just refreshed.
  ///
  /// Every data source reads its bearer token off this in-memory session, so a
  /// refresh that only reached storage would leave the app sending the expired
  /// token on every call until it was restarted.
  void applyRefreshedSession(AuthSession session) {
    if (state.valueOrNull == null) {
      return;
    }
    state = AsyncData(session);
  }

  /// Renews the access token before it is used, rather than after a call has
  /// already failed with a 401.
  ///
  /// Called when the app starts and each time it returns to the foreground —
  /// the moments when a token is most likely to have expired while the app was
  /// closed or backgrounded. Silent by design: the user is never told, and a
  /// failure here changes nothing, because the interceptor still refreshes
  /// reactively if a request does come back 401.
  Future<void> ensureFreshSession() async {
    // Awaited, not read: at app start the stored session is still being loaded
    // from disk, so reading the current value here would see null and skip the
    // refresh entirely — exactly the case this exists for.
    final session = await future;
    if (session == null || session.refreshToken.isEmpty) {
      return;
    }

    // A token that cannot be parsed reports as not expired, so an unreadable
    // token is left for the interceptor to deal with rather than triggering a
    // refresh on every launch.
    if (!isJwtExpired(session.accessToken)) {
      return;
    }

    final result = await ref.read(refreshSessionProvider)(
      refreshToken: session.refreshToken,
    );

    switch (result) {
      case Success(:final data):
        state = AsyncData(data);
      case Fail():
        // Deliberately silent. If the refresh token is genuinely dead, the
        // next request will 401 and the interceptor signs the user out; if it
        // was only a network blip, nothing has been lost.
        break;
    }
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

  /// Best-effort push teardown, in three steps.
  ///
  /// `POST /auth/logout` ends the session and detaches this device's token
  /// server-side, which is what actually stops notifications arriving for a
  /// signed-out user. The Firebase token is then deleted so the next sign-in
  /// registers a freshly issued one rather than the revoked value, and the
  /// cached copy is dropped to match.
  ///
  /// None of it blocks the user: the local session is already gone by the time
  /// this runs, and a failure here cannot put them back on a signed-in screen.
  Future<void> _revokeDeviceToken(AuthSession? session) async {
    final token = await _deviceToken();

    if (session != null) {
      await ref.read(logoutUserProvider)(
        accessToken: session.accessToken,
        // The endpoint expects the field; an empty string is still honest
        // about there being no token, and lets the server end the session.
        fcmToken: token ?? '',
      );
    }

    await ref.read(fcmTokenServiceProvider).deleteDeviceToken();
    ref.invalidate(fcmDeviceTokenProvider);

    // Release the Google account too, so the next Google sign-in offers the
    // picker rather than dropping straight back into the account just left.
    await ref.read(authRepositoryProvider).signOutOfGoogle();
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

  /// Stops the spinner without touching the session or raising a message.
  ///
  /// Used when an attempt ends in no outcome at all, such as a dismissed
  /// Google account picker.
  String? _clearSubmission() {
    ref.read(authSubmissionLoadingProvider.notifier).state = false;
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
