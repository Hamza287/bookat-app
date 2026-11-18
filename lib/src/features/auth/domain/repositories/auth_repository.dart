import '../../../../core/enums/app_enums.dart';
import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';
import '../entities/auth_session.dart';
import '../entities/otp_verification_result.dart';
import '../entities/password_reset.dart';

abstract interface class AuthRepository {
  Future<Result<AppUser>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    Role role = Role.customer,
  });

  Future<Result<OtpVerificationResult>> verifyOtp({
    required String email,
    required String otp,
  });

  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  });

  /// Signs in through Google, creating the account on first use.
  ///
  /// Runs the account picker, trades the chosen account for a Firebase ID
  /// token and posts that to the server, which answers with an ordinary app
  /// session.
  ///
  /// `Success(null)` means the user dismissed the picker: nothing failed, so
  /// there is nothing to report.
  Future<Result<AuthSession?>> signInWithGoogle({Role role = Role.customer});

  /// Forgets the Google account tied to this device, so a later sign-in offers
  /// the picker instead of silently reusing the last account.
  Future<void> signOutOfGoogle();

  /// Exchanges [refreshToken] for a new token pair and persists the result, so
  /// the app can renew a spent access token without involving the user.
  ///
  /// The refreshed session keeps the currently stored user, since this endpoint
  /// returns tokens rather than a profile.
  Future<Result<AuthSession>> refreshSession({required String refreshToken});

  /// Asks the server to email a reset code. [emailOrUsername] is whatever the
  /// user typed; the result carries the address the code was sent to.
  Future<Result<PasswordResetRequest>> requestPasswordReset({
    required String emailOrUsername,
  });

  /// Completes a reset with the emailed code. Returns the server's confirmation
  /// only — no session is issued, so the user signs in afterwards.
  Future<Result<PasswordResetConfirmation>> resetPassword({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  });

  /// Ends the session server-side and detaches this device's push token.
  ///
  /// Best effort: the local session is cleared regardless of the outcome, so a
  /// user who taps Log out is always signed out of the app even if the call
  /// never reaches the server.
  Future<Result<void>> logout({
    required String accessToken,
    required String fcmToken,
  });

  Future<AuthSession?> readSession();

  Future<void> saveSession(AuthSession session);

  Future<void> clearSession();
}
