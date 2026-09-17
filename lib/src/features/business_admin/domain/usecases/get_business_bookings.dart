import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/my_booking.dart';
import '../repositories/business_admin_repository.dart';

class GetBusinessBookings {
  const GetBusinessBookings(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<List<MyBooking>>> call({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  }) {
    return _repository.getBusinessBookings(
      businessId: businessId,
      accessToken: accessToken,
      limit: limit,
    );
  }
}
