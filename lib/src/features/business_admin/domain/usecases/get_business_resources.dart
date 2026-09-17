import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../repositories/business_admin_repository.dart';

class GetBusinessResources {
  const GetBusinessResources(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<List<BusinessResource>>> call({
    required String businessId,
    required String accessToken,
  }) {
    return _repository.getBusinessResources(
      businessId: businessId,
      accessToken: accessToken,
    );
  }
}
