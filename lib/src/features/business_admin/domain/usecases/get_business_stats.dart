import '../../../../core/utils/result.dart';
import '../entities/business_stats.dart';
import '../repositories/business_admin_repository.dart';

class GetBusinessStats {
  const GetBusinessStats(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<BusinessStats>> call({
    required String businessId,
    required String accessToken,
  }) {
    return _repository.getBusinessStats(
      businessId: businessId,
      accessToken: accessToken,
    );
  }
}
