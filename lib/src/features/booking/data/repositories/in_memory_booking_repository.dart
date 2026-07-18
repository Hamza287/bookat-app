import '../datasources/mock_booking_remote_data_source.dart';
import 'booking_repository_impl.dart';

class InMemoryBookingRepository extends BookingRepositoryImpl {
  const InMemoryBookingRepository() : super(const MockBookingRemoteDataSource());
}
