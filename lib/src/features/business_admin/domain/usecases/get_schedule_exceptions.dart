import '../../../../core/utils/result.dart';
import '../entities/schedule_exception.dart';
import '../repositories/business_admin_repository.dart';

class GetScheduleExceptions {
  const GetScheduleExceptions(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<List<ScheduleException>>> call({
    required String businessId,
    required String accessToken,
  }) {
    return _repository.getScheduleExceptions(
      businessId: businessId,
      accessToken: accessToken,
    );
  }
}
