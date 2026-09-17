import '../../../../core/utils/result.dart';
import '../entities/password_reset.dart';
import '../repositories/auth_repository.dart';

/// Exchanges a reset code for a new password.
class ResetPassword {
  const ResetPassword(this._repository);

  final AuthRepository _repository;

  Future<Result<PasswordResetConfirmation>> call({
    required String emailOrUsername,
    required String otp,
    required String newPassword,
  }) {
    return _repository.resetPassword(
      emailOrUsername: emailOrUsername,
      otp: otp,
      newPassword: newPassword,
    );
  }
}
