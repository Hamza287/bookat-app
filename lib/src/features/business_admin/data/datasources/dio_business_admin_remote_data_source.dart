import 'package:dio/dio.dart';

import '../../../../core/network/network.dart';
import '../../../booking/data/models/business_model.dart';
import '../../../booking/data/models/my_booking_model.dart';
import '../models/business_payment_model.dart';
import '../models/holiday_booking_check_model.dart';
import '../models/resource_category_model.dart';
import '../models/business_stats_model.dart';
import '../models/schedule_exception_model.dart';
import 'business_admin_remote_data_source.dart';

class DioBusinessAdminRemoteDataSource
    implements BusinessAdminRemoteDataSource {
  const DioBusinessAdminRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<BusinessModel> updateBusiness({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    String? logoPath,
    String? coverPath,
  }) async {
    final formData = FormData();
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value != null && value.toString().isNotEmpty) {
        formData.fields.add(MapEntry(entry.key, value.toString()));
      }
    }
    if (logoPath != null && logoPath.isNotEmpty) {
      formData.files.add(
        MapEntry('logo', await MultipartFile.fromFile(logoPath)),
      );
    }
    if (coverPath != null && coverPath.isNotEmpty) {
      formData.files.add(
        MapEntry('cover', await MultipartFile.fromFile(coverPath)),
      );
    }

    final response = await _apiClient.patchMultipart(
      ApiEndpoints.businessById(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: formData,
    );

    return _business(response.data, 'Invalid update business response.');
  }

  @override
  Future<BusinessModel> updateOperatingHours({
    required String businessId,
    required String accessToken,
    required List<Map<String, dynamic>> operatingHours,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.businessOperatingHours(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {'operatingHours': operatingHours},
    );

    return _business(response.data, 'Invalid operating hours response.');
  }

  @override
  Future<HolidayBookingCheckModel> checkHolidayBookings({
    required String businessId,
    required String accessToken,
    required String date,
    required String endDate,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.businessHolidayCheckBookings(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {'date': date, 'endDate': endDate},
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid holiday check response.');
    }

    return HolidayBookingCheckModel.fromJson(payload);
  }

  @override
  Future<void> createHoliday({
    required String businessId,
    required String accessToken,
    required String date,
    required String endDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    await _apiClient.post(
      ApiEndpoints.businessHolidays(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {
        'date': date,
        'endDate': endDate,
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        'reason': reason,
      },
    );
  }

  @override
  Future<BusinessStatsModel> getBusinessStats({
    required String businessId,
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.businessStats(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final payload = response.data;

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid business stats response.');
    }

    return BusinessStatsModel.fromJson(payload);
  }

  @override
  Future<List<MyBookingModel>> getBusinessBookings({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.businessBookings(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {
        'limit': limit,
        // The API serves ETags and answers repeat GETs with 304, so an
        // unchanged URL can hand back the list from before the booking was
        // made. Every other read here already varies its query for the same
        // reason; this one was missed, which is why a new reservation only
        // showed up after an app restart.
        '_': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final bookings = _listPayload(response.data);

    if (bookings == null) {
      throw const FormatException('Invalid business bookings response.');
    }

    return bookings
        .whereType<Map<String, dynamic>>()
        .map(MyBookingModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<BusinessResourceModel>> getBusinessResources({
    required String businessId,
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.businessResources(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final resources = _listPayload(response.data);

    if (resources == null) {
      throw const FormatException('Invalid business resources response.');
    }

    return resources
        .whereType<Map<String, dynamic>>()
        .map(BusinessResourceModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ResourceCategoryModel>> getResourceCategories({
    required String businessId,
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.resourceCategoriesByBusiness(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final categories = _listPayload(response.data);

    if (categories == null) {
      throw const FormatException('Invalid resource categories response.');
    }

    return categories
        .whereType<Map<String, dynamic>>()
        .map(ResourceCategoryModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ResourceCategoryModel> createResourceCategory({
    required String businessId,
    required String accessToken,
    required String name,
    required String description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.resourceCategories,
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {
        'name': name,
        'description': description,
        'businessId': businessId,
      },
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final category = payload['data'];
      return ResourceCategoryModel.fromJson(
        category is Map<String, dynamic> ? category : payload,
      );
    }

    throw const FormatException('Invalid create category response.');
  }

  @override
  Future<BusinessResourceModel> createBusinessResource({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) async {
    final formData = FormData();
    for (final entry in fields.entries) {
      if (entry.value != null && entry.value.toString().isNotEmpty) {
        formData.fields.add(MapEntry(entry.key, entry.value.toString()));
      }
    }
    for (final path in imagePaths) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(path),
        ),
      );
    }

    final response = await _apiClient.postMultipart(
      ApiEndpoints.businessResources(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: formData,
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final resource = payload['data'];
      return BusinessResourceModel.fromJson(
        resource is Map<String, dynamic> ? resource : payload,
      );
    }

    throw const FormatException('Invalid create venue response.');
  }

  @override
  Future<BusinessResourceModel> updateBusinessResource({
    required String resourceId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  }) async {
    final formData = FormData();
    for (final entry in fields.entries) {
      if (entry.value != null && entry.value.toString().isNotEmpty) {
        formData.fields.add(MapEntry(entry.key, entry.value.toString()));
      }
    }
    for (final path in imagePaths) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(path),
        ),
      );
    }

    final response = await _apiClient.patchMultipart(
      ApiEndpoints.resourceById(resourceId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: formData,
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final resource = payload['data'];
      return BusinessResourceModel.fromJson(
        resource is Map<String, dynamic> ? resource : payload,
      );
    }

    throw const FormatException('Invalid update venue response.');
  }

  @override
  Future<void> deleteBusinessResource({
    required String resourceId,
    required String accessToken,
  }) async {
    await _apiClient.delete(
      ApiEndpoints.resourceById(resourceId),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  @override
  Future<List<ScheduleExceptionModel>> getScheduleExceptions({
    required String businessId,
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.scheduleExceptionsByBusiness(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
    );
    final exceptions = _listPayload(response.data);

    if (exceptions == null) {
      return const [];
    }

    return exceptions
        .whereType<Map<String, dynamic>>()
        .map(ScheduleExceptionModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ScheduleExceptionModel> createScheduleException({
    required String accessToken,
    required String resourceId,
    required DateTime date,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required bool isBlockout,
    required String reason,
  }) async {
    final body = {
      'resourceId': resourceId,
      'date': date.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'isBlockout': isBlockout,
      'reason': reason,
    };

    final response = await _apiClient.post(
      ApiEndpoints.scheduleExceptions,
      headers: {'Authorization': 'Bearer $accessToken'},
      data: body,
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      return ScheduleExceptionModel.fromJson(
        data is Map<String, dynamic> ? data : payload,
      );
    }

    // Default fallback constructed model if 201 Created returns minimal body
    return ScheduleExceptionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      resourceId: resourceId,
      date: date,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      isBlockout: isBlockout,
      reason: reason,
    );
  }

  @override
  Future<void> deleteScheduleException({
    required String exceptionId,
    required String accessToken,
  }) async {
    await _apiClient.delete(
      ApiEndpoints.scheduleExceptionById(exceptionId),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  @override
  Future<void> createManualBooking({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    await _apiClient.post(
      ApiEndpoints.bookings,
      headers: {'Authorization': 'Bearer $accessToken'},
      data: body,
    );
  }

  @override
  Future<BusinessPaymentsModel> getBusinessPayments({
    required String businessId,
    required String accessToken,
    required String startDate,
    required String endDate,
    int limit = 100,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.businessPayments(businessId),
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {
        'limit': limit,
        'startDate': startDate,
        'endDate': endDate,
      },
    );

    return BusinessPaymentsModel.fromJson(response.data);
  }

  @override
  Future<void> updatePaymentStatus({
    required String paymentId,
    required String accessToken,
    required String status,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.paymentStatus(paymentId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {'status': status},
    );
  }

  @override
  Future<void> updatePaymentMethod({
    required String paymentId,
    required String accessToken,
    required String method,
  }) async {
    await _apiClient.patch(
      ApiEndpoints.paymentMethod(paymentId),
      headers: {'Authorization': 'Bearer $accessToken'},
      data: {'method': method},
    );
  }
}

/// Business write endpoints return the updated business, either bare or nested
/// under `data`.
BusinessModel _business(Object? payload, String errorMessage) {
  if (payload is! Map<String, dynamic>) {
    throw FormatException(errorMessage);
  }

  final business = payload['data'];
  return BusinessModel.fromJson(
    business is Map<String, dynamic> ? business : payload,
  );
}

List<dynamic>? _listPayload(Object? payload) {
  if (payload is List) {
    return payload;
  }

  if (payload is Map<String, dynamic>) {
    for (final key in ['data', 'bookings', 'items', 'results']) {
      final value = payload[key];
      if (value is List) {
        return value;
      }
    }
  }

  return null;
}
