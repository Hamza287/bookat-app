import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../repositories/business_admin_repository.dart';

class UpdateBusinessResource {
  const UpdateBusinessResource(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<BusinessResource>> call({
    required String resourceId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) {
    return _repository.updateBusinessResource(
      resourceId: resourceId,
      accessToken: accessToken,
      fields: fields,
      imagePaths: imagePaths,
    );
  }
}
