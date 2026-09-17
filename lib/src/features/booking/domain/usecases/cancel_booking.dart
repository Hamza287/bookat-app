import '../../../../core/utils/result.dart';
import '../repositories/booking_repository.dart';

class CancelBooking {
  const CancelBooking(this._repository);

  final BookingRepository _repository;

  Future<Result<void>> call({
    required String accessToken,
    required String bookingId,
  }) {
    return _repository.cancelBooking(
      accessToken: accessToken,
      bookingId: bookingId,
    );
  }
}
