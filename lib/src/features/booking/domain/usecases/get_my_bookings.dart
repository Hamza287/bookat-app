import '../../../../core/utils/result.dart';
import '../entities/my_booking.dart';
import '../repositories/booking_repository.dart';

class GetMyBookings {
  const GetMyBookings(this._repository);

  final BookingRepository _repository;

  Future<Result<List<MyBooking>>> call(String accessToken) {
    return _repository.getMyBookings(accessToken);
  }
}
