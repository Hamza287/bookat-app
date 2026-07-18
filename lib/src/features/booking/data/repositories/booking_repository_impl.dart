import '../../domain/entities/business.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._remoteDataSource);

  final BookingRemoteDataSource _remoteDataSource;

  @override
  Future<List<Business>> searchBusinesses() {
    return _remoteDataSource.searchBusinesses();
  }
}
