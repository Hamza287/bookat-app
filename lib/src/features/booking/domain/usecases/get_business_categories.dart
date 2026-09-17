import '../../../../core/utils/result.dart';
import '../entities/business_category.dart';
import '../repositories/booking_repository.dart';

class GetBusinessCategories {
  const GetBusinessCategories(this._repository);

  final BookingRepository _repository;

  Future<Result<List<BusinessCategory>>> call() {
    return _repository.getCategories();
  }
}
