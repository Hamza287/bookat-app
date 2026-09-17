import '../../../../core/constants/constants.dart';
import '../../../../core/network/network.dart';
import '../models/booking_confirmation_model.dart';
import '../models/business_category_model.dart';
import '../models/business_model.dart';
import '../models/my_booking_model.dart';
import '../models/review_model.dart';
import '../models/slot_availability_model.dart';
import 'booking_remote_data_source.dart';

class DioBookingRemoteDataSource implements BookingRemoteDataSource {
  const DioBookingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<BusinessModel>> searchBusinesses({
    String query = '',
    String category = '',
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.businessesSearch,
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (category.isNotEmpty) 'type': category,
      },
    );
    final payload = response.data;

    if (payload is! List) {
      throw const FormatException(AppStrings.invalidBusinessesResponse);
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(BusinessModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<BusinessCategoryModel>> getCategories() async {
    final response = await _apiClient.get(ApiEndpoints.configCategories);
    final categories = _listPayload(response.data);

    if (categories == null) {
      throw const FormatException('Invalid categories response.');
    }

    return categories.map(BusinessCategoryModel.fromJson).toList(growable: false);
  }

  @override
  Future<BusinessModel> getBusinessBySlug(String slug) async {
    final response = await _apiClient.get(ApiEndpoints.businessBySlug(slug));
    final payload = response.data;

    if (payload is! Map<String, dynamic>) {
      throw const FormatException(AppStrings.invalidBusinessesResponse);
    }

    return BusinessModel.fromJson(payload);
  }

  @override
  Future<List<SlotAvailabilityModel>> getAvailability({
    required String resourceId,
    required String date,
    required int tzOffset,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.publicBookingAvailability,
      queryParameters: {
        'resourceId': resourceId,
        'date': date,
        'tzOffset': tzOffset,
      },
    );
    final payload = response.data;

    if (payload is! List) {
      throw const FormatException(AppStrings.invalidBusinessesResponse);
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(SlotAvailabilityModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<BookingConfirmationModel> createBooking({
    required String accessToken,
    required String resourceId,
    required List<String> slots,
    required String paymentMethod,
    required Map<String, dynamic> customerDetails,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.bookings,
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {
        'resourceId': resourceId,
        'slots': slots,
        'paymentMethod': paymentMethod,
        'customerDetails': customerDetails,
      },
    );
    final payload = response.data;

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid booking response.');
    }

    return BookingConfirmationModel.fromJson(payload);
  }

  @override
  Future<List<MyBookingModel>> getMyBookings(String accessToken) async {
    final response = await _apiClient.get(
      ApiEndpoints.myBookings,
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final payload = response.data;
    final bookings = _listPayload(payload);

    if (bookings == null) {
      throw const FormatException('Invalid bookings response.');
    }

    return bookings
        .whereType<Map<String, dynamic>>()
        .map(MyBookingModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> cancelBooking({
    required String accessToken,
    required String bookingId,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.bookingCancel(bookingId),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  @override
  Future<List<ReviewModel>> getBusinessReviews(String businessId) async {
    final response = await _apiClient.get(
      ApiEndpoints.businessReviews(businessId),
    );
    final reviews = _listPayload(response.data);

    if (reviews == null) {
      throw const FormatException('Invalid reviews response.');
    }

    return reviews
        .whereType<Map<String, dynamic>>()
        .map(ReviewModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<MyBookingModel>> getEligibleReviewBookings({
    required String accessToken,
    required String businessId,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.eligibleReviewBookings(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final bookings = _listPayload(response.data);

    if (bookings == null) {
      throw const FormatException('Invalid eligible bookings response.');
    }

    return bookings
        .whereType<Map<String, dynamic>>()
        .map(MyBookingModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ReviewModel> createReview({
    required String accessToken,
    required String businessId,
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    // POST /reviews body is not documented in the API collection; this shape
    // is inferred from the eligible-bookings/business-scoped review pattern.
    // Confirm against the live API and adjust if the server expects different
    // field names.
    final response = await _apiClient.post(
      ApiEndpoints.reviews,
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {
        'businessId': businessId,
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
      },
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final review = payload['data'];
      return ReviewModel.fromJson(
        review is Map<String, dynamic> ? review : payload,
      );
    }

    throw const FormatException('Invalid create review response.');
  }
}

/// Most endpoints return a bare array, but some wrap it alongside summary
/// fields — `GET /reviews/business/{id}` answers
/// `{"averageRating":4,"reviewCount":1,"reviews":[...]}`, so `reviews` has to
/// be one of the keys we unwrap.
List<dynamic>? _listPayload(Object? payload) {
  if (payload is List) {
    return payload;
  }

  if (payload is Map<String, dynamic>) {
    for (final key in ['data', 'reviews', 'bookings', 'items', 'results']) {
      final value = payload[key];
      if (value is List) {
        return value;
      }
    }
  }

  return null;
}
