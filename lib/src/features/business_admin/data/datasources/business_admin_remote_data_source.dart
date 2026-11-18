import '../../../booking/data/models/my_booking_model.dart';
import '../../../booking/data/models/business_model.dart';
import '../models/business_payment_model.dart';
import '../models/holiday_booking_check_model.dart';
import '../models/resource_category_model.dart';
import '../models/business_stats_model.dart';

import '../models/schedule_exception_model.dart';

abstract interface class BusinessAdminRemoteDataSource {
  Future<BusinessModel> updateBusiness({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    String? logoPath,
    String? coverPath,
  });

  Future<BusinessModel> updateOperatingHours({
    required String businessId,
    required String accessToken,
    required List<Map<String, dynamic>> operatingHours,
  });

  Future<HolidayBookingCheckModel> checkHolidayBookings({
    required String businessId,
    required String accessToken,
    required String date,
    required String endDate,
  });

  Future<void> createHoliday({
    required String businessId,
    required String accessToken,
    required String date,
    required String endDate,
    String? startTime,
    String? endTime,
    required String reason,
  });

  Future<BusinessStatsModel> getBusinessStats({
    required String businessId,
    required String accessToken,
  });

  Future<List<MyBookingModel>> getBusinessBookings({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  });

  Future<List<BusinessResourceModel>> getBusinessResources({
    required String businessId,
    required String accessToken,
  });

  Future<List<ResourceCategoryModel>> getResourceCategories({
    required String businessId,
    required String accessToken,
  });

  Future<ResourceCategoryModel> createResourceCategory({
    required String businessId,
    required String accessToken,
    required String name,
    required String description,
  });

  Future<BusinessResourceModel> createBusinessResource({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  });

  Future<BusinessResourceModel> updateBusinessResource({
    required String resourceId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  });

  Future<void> deleteBusinessResource({
    required String resourceId,
    required String accessToken,
  });

  Future<List<ScheduleExceptionModel>> getScheduleExceptions({
    required String businessId,
    required String accessToken,
  });

  Future<ScheduleExceptionModel> createScheduleException({
    required String accessToken,
    required String resourceId,
    required DateTime date,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required bool isBlockout,
    required String reason,
  });

  Future<void> deleteScheduleException({
    required String exceptionId,
    required String accessToken,
  });

  Future<void> updateBookingStatus({
    required String bookingId,
    required String accessToken,
    required String status,
  });

  Future<void> createManualBooking({
    required String accessToken,
    required Map<String, dynamic> body,
  });

  Future<BusinessPaymentsModel> getBusinessPayments({
    required String businessId,
    required String accessToken,
    required String startDate,
    required String endDate,
    int limit = 100,
  });

  Future<void> updatePaymentStatus({
    required String paymentId,
    required String accessToken,
    required String status,
  });

  /// Settles several payments at once. One request rather than one per row,
  /// so a stack of cash takings can be cleared in a single call.
  Future<void> bulkUpdatePaymentStatus({
    required List<String> paymentIds,
    required String accessToken,
    required String status,
  });

  Future<void> updatePaymentMethod({
    required String paymentId,
    required String accessToken,
    required String method,
  });
}
