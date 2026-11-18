import '../../../../core/enums/app_enums.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Signs in through Google, creating the account on first use.
///
/// A `Success` carrying null means the account picker was dismissed.
class SignInWithGoogle {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession?>> call({Role role = Role.customer}) {
    return _repository.signInWithGoogle(role: role);
  }
}
