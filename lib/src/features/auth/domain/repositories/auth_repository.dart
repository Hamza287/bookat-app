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

  Future<AuthSession?> readSession();

  Future<void> saveSession(AuthSession session);

  Future<void> clearSession();
}
