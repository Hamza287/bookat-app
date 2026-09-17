import '../../../../core/utils/result.dart';
import '../entities/schedule_exception.dart';
import '../repositories/business_admin_repository.dart';

class CreateScheduleException {
  const CreateScheduleException(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<ScheduleException>> call({
    required String accessToken,
    required String resourceId,
    required DateTime date,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required bool isBlockout,
    required String reason,
  }) {
    return _repository.createScheduleException(
      accessToken: accessToken,
      resourceId: resourceId,
      date: date,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      isBlockout: isBlockout,
      reason: reason,
    );
  }
}
