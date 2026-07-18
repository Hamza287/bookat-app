import '../entities/business.dart';
import '../repositories/booking_repository.dart';

class GetFeaturedServices {
  const GetFeaturedServices(this._repository);

  final BookingRepository _repository;

  Future<List<Business>> call() {
    return _repository.searchBusinesses();
  }
}
