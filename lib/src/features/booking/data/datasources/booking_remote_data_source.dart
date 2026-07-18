import '../models/business_model.dart';

abstract interface class BookingRemoteDataSource {
  Future<List<BusinessModel>> searchBusinesses();
}
