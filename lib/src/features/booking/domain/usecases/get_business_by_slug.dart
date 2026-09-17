import '../../../../core/utils/result.dart';
import '../entities/business.dart';
import '../repositories/booking_repository.dart';

class GetBusinessBySlug {
  const GetBusinessBySlug(this._repository);

  final BookingRepository _repository;

  Future<Result<Business>> call(String slug) {
    return _repository.getBusinessBySlug(slug);
  }
}
