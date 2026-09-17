import '../../../../core/utils/result.dart';
import '../repositories/business_admin_repository.dart';

class DeleteBusinessResource {
  const DeleteBusinessResource(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<void>> call({
    required String resourceId,
    required String accessToken,
  }) {
    return _repository.deleteBusinessResource(
      resourceId: resourceId,
      accessToken: accessToken,
    );
  }
}
