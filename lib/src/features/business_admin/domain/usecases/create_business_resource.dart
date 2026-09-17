import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../repositories/business_admin_repository.dart';

class CreateBusinessResource {
  const CreateBusinessResource(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<BusinessResource>> call({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) {
    return _repository.createBusinessResource(
      businessId: businessId,
      accessToken: accessToken,
      fields: fields,
      imagePaths: imagePaths,
    );
  }
}
