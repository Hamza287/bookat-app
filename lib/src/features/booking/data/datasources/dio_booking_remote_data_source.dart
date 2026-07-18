import '../../../../core/constants/constants.dart';
import '../../../../core/network/network.dart';
import '../models/business_model.dart';
import 'booking_remote_data_source.dart';

class DioBookingRemoteDataSource implements BookingRemoteDataSource {
  const DioBookingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<BusinessModel>> searchBusinesses() async {
    final response = await _apiClient.get(ApiEndpoints.businessesSearch);
    final payload = response.data;

    if (payload is! List) {
      throw const FormatException(AppStrings.invalidBusinessesResponse);
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(BusinessModel.fromJson)
        .toList(growable: false);
  }
}
