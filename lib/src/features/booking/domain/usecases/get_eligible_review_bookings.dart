import '../../../../core/utils/result.dart';
import '../entities/my_booking.dart';
import '../repositories/booking_repository.dart';

class GetEligibleReviewBookings {
  const GetEligibleReviewBookings(this._repository);

  final BookingRepository _repository;

  Future<Result<List<MyBooking>>> call({
    required String accessToken,
    required String businessId,
  }) {
    return _repository.getEligibleReviewBookings(
      accessToken: accessToken,
      businessId: businessId,
    );
  }
}
