import '../../../../core/utils/result.dart';
import '../entities/booking_confirmation.dart';
import '../repositories/booking_repository.dart';

class CreateBooking {
  const CreateBooking(this._repository);

  final BookingRepository _repository;

  Future<Result<BookingConfirmation>> call({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  }) {
    return _repository.createBooking(
      accessToken: accessToken,
      resourceId: resourceId,
      slots: slots,
      paymentMethod: paymentMethod,
      customerDetails: customerDetails,
    );
  }
}
