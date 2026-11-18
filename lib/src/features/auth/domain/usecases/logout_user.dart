import '../../../../core/utils/result.dart';
import '../repositories/auth_repository.dart';

/// Ends the session on the server and unhooks this device from push.
class LogoutUser {
  const LogoutUser(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({
    required String accessToken,
    required String fcmToken,
  }) {
    return _repository.logout(
      accessToken: accessToken,
      fcmToken: fcmToken,
    );
  }
}
