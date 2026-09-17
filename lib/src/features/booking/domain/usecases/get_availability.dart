import '../../../../core/utils/result.dart';
import '../entities/slot_availability.dart';
import '../repositories/booking_repository.dart';

class GetAvailability {
  const GetAvailability(this._repository);

  final BookingRepository _repository;

  Future<Result<List<SlotAvailability>>> call({
    required String resourceId,
    required String date,
    required int tzOffset,
  }) {
    return _repository.getAvailability(
      resourceId: resourceId,
      date: date,
      tzOffset: tzOffset,
    );
  }
}
