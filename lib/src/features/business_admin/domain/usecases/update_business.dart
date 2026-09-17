import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../repositories/business_admin_repository.dart';

class UpdateBusiness {
  const UpdateBusiness(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<Business>> call({
    required String businessId,
    required String accessToken,
    required String name,
    required String slug,
    required String city,
    required String address,
    required BusinessSettings settings,
    String? logoPath,
    String? coverPath,
  }) {
    return _repository.updateBusiness(
      businessId: businessId,
      accessToken: accessToken,
      name: name,
      slug: slug,
      city: city,
      address: address,
      settings: settings,
      logoPath: logoPath,
      coverPath: coverPath,
    );
  }
}
