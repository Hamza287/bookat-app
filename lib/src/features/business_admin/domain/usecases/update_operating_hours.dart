import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../repositories/business_admin_repository.dart';

class UpdateOperatingHours {
  const UpdateOperatingHours(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<Business>> call({
    required String businessId,
    required String accessToken,
    required List<BusinessOperatingHour> operatingHours,
  }) {
    return _repository.updateOperatingHours(
      businessId: businessId,
      accessToken: accessToken,
      operatingHours: operatingHours,
    );
  }
}
