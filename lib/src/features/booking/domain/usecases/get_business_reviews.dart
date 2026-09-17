import '../../../../core/utils/result.dart';
import '../entities/review.dart';
import '../repositories/booking_repository.dart';

class GetBusinessReviews {
  const GetBusinessReviews(this._repository);

  final BookingRepository _repository;

  Future<Result<List<Review>>> call(String businessId) {
    return _repository.getBusinessReviews(businessId);
  }
}
