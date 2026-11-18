import '../../../../core/utils/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Exchanges a refresh token for a fresh session, ahead of any request that
/// would otherwise fail with an expired access token.
class RefreshSession {
  const RefreshSession(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession>> call({required String refreshToken}) {
    return _repository.refreshSession(refreshToken: refreshToken);
  }
}
