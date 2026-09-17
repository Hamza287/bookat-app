import '../../../../core/utils/result.dart';
import '../entities/business_payment.dart';
import '../repositories/business_admin_repository.dart';

class GetBusinessPayments {
  const GetBusinessPayments(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<BusinessPayments>> call({
    required String businessId,
    required String accessToken,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) {
    return _repository.getBusinessPayments(
      businessId: businessId,
      accessToken: accessToken,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }
}
