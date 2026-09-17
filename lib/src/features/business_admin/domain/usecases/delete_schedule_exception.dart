import '../../../../core/utils/result.dart';
import '../repositories/business_admin_repository.dart';

class DeleteScheduleException {
  const DeleteScheduleException(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<void>> call({
    required String exceptionId,
    required String accessToken,
  }) {
    return _repository.deleteScheduleException(
      exceptionId: exceptionId,
      accessToken: accessToken,
    );
  }
}
