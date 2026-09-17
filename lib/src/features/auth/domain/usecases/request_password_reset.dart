import '../../../../core/utils/result.dart';
import '../entities/password_reset.dart';
import '../repositories/auth_repository.dart';

/// Sends a reset code to the account's email address.
class RequestPasswordReset {
  const RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<Result<PasswordResetRequest>> call({
    required String emailOrUsername,
  }) {
    return _repository.requestPasswordReset(emailOrUsername: emailOrUsername);
  }
}
