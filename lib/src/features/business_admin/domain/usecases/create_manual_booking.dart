import '../../../../core/utils/result.dart';
import '../repositories/business_admin_repository.dart';

class CreateManualBooking {
  const CreateManualBooking(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<void>> call({
    required String accessToken,
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    num? overridePrice,
  }) {
    return _repository.createManualBooking(
      accessToken: accessToken,
      resourceId: resourceId,
      startTime: startTime,
      endTime: endTime,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      overridePrice: overridePrice,
    );
  }
}
