import '../entities/business.dart';

abstract interface class BookingRepository {
  Future<List<Business>> searchBusinesses();
}
