import '../../../../core/utils/result.dart';
import '../entities/business.dart';
import '../repositories/booking_repository.dart';

class SearchBusinesses {
  const SearchBusinesses(this._repository);

  final BookingRepository _repository;

  Future<Result<List<Business>>> call({
    String query = '',
    String category = '',
  }) {
    return _repository.searchBusinesses(query: query, category: category);
  }
}
