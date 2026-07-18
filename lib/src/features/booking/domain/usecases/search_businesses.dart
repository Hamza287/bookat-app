import '../entities/business.dart';
import '../repositories/booking_repository.dart';

class SearchBusinesses {
  const SearchBusinesses(this._repository);

  final BookingRepository _repository;

  Future<List<Business>> call() {
    return _repository.searchBusinesses();
  }
}
