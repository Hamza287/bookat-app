import '../../../../core/utils/result.dart';
import '../repositories/business_admin_repository.dart';

class CreateBusinessHoliday {
  const CreateBusinessHoliday(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<void>> call({
    required String businessId,
    required String accessToken,
    required DateTime date,
    required DateTime endDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) {
    return _repository.createHoliday(
      businessId: businessId,
      accessToken: accessToken,
      date: date,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      reason: reason,
    );
  }
}
