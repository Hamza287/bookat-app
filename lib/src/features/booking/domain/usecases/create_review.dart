import '../../../../core/utils/result.dart';
import '../entities/review.dart';
import '../repositories/booking_repository.dart';

class CreateReview {
  const CreateReview(this._repository);

  final BookingRepository _repository;

  Future<Result<Review>> call({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) {
    return _repository.createReview(
      accessToken: accessToken,
      businessId: businessId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );
  }
}
