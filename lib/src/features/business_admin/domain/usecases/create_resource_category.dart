import '../../../../core/utils/result.dart';
import '../entities/resource_category.dart';
import '../repositories/business_admin_repository.dart';

class CreateResourceCategory {
  const CreateResourceCategory(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<ResourceCategory>> call({
    required String businessId,
    required String accessToken,
    required String name,
    required String description,
  }) {
    return _repository.createResourceCategory(
      businessId: businessId,
      accessToken: accessToken,
      name: name,
      description: description,
    );
  }
}
