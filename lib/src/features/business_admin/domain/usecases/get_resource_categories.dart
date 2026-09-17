import '../../../../core/utils/result.dart';
import '../entities/resource_category.dart';
import '../repositories/business_admin_repository.dart';

class GetResourceCategories {
  const GetResourceCategories(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<List<ResourceCategory>>> call({
    required String businessId,
    required String accessToken,
  }) {
    return _repository.getResourceCategories(
      businessId: businessId,
      accessToken: accessToken,
    );
  }
}
