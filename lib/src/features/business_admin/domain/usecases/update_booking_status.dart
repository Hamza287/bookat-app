import '../../../../core/utils/result.dart';
import '../repositories/business_admin_repository.dart';

/// Moves a booking to a new state from the owner's dashboard.
class UpdateBookingStatus {
  const UpdateBookingStatus(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<void>> call({
    required String bookingId,
    required String accessToken,
    required String status,
  }) {
    return _repository.updateBookingStatus(
      bookingId: bookingId,
      accessToken: accessToken,
      status: status,
    );
  }
}
