import '../../../../core/utils/result.dart';
import '../../../booking/domain/entities/business.dart';
import '../../../booking/domain/entities/my_booking.dart';
import '../entities/business_payment.dart';
import '../entities/business_stats.dart';
import '../entities/holiday_booking_check.dart';
import '../entities/resource_category.dart';

import '../entities/schedule_exception.dart';

abstract interface class BusinessAdminRepository {
  /// [settings] is always sent in full â€” the API replaces the stored settings
  /// object wholesale, so callers must pass a merged value, not a delta.
  Future<Result<Business>> updateBusiness({
    required String businessId,
    required String accessToken,
    required String name,
    required String slug,
    required String city,
    required String address,
    required BusinessSettings settings,
    String? logoPath,
    String? coverPath,
  });

  Future<Result<Business>> updateOperatingHours({
    required String businessId,
    required String accessToken,
    required List<BusinessOperatingHour> operatingHours,
  });

  Future<Result<HolidayBookingCheck>> checkHolidayBookings({
    required String businessId,
    required String accessToken,
    required DateTime date,
    required DateTime endDate,
  });

  Future<Result<void>> createHoliday({
    required String businessId,
    required String accessToken,
    required DateTime date,
    required DateTime endDate,
    String? startTime,
    String? endTime,
    required String reason,
  });

  Future<Result<BusinessStats>> getBusinessStats({
    required String businessId,
    required String accessToken,
  });

  Future<Result<List<MyBooking>>> getBusinessBookings({
    required String businessId,
    required String accessToken,
    int limit = 1000,
  });

  Future<Result<List<BusinessResource>>> getBusinessResources({
    required String businessId,
    required String accessToken,
  });

  Future<Result<List<ResourceCategory>>> getResourceCategories({
    required String businessId,
    required String accessToken,
  });

  Future<Result<ResourceCategory>> createResourceCategory({
    required String businessId,
    required String accessToken,
    required String name,
    required String description,
  });

  Future<Result<BusinessResource>> createBusinessResource({
    required String businessId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  });

  Future<Result<BusinessResource>> updateBusinessResource({
    required String resourceId,
    required String accessToken,
    required Map<String, dynamic> fields,
    required List<String> imagePaths,
  });

  Future<Result<void>> deleteBusinessResource({
    required String resourceId,
    required String accessToken,
  });

  Future<Result<List<ScheduleException>>> getScheduleExceptions({
    required String businessId,
    required String accessToken,
  });

  Future<Result<ScheduleException>> createScheduleException({
    required String accessToken,
    required String resourceId,
    required DateTime date,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required bool isBlockout,
    required String reason,
  });

  Future<Result<void>> deleteScheduleException({
    required String exceptionId,
    required String accessToken,
  });

  /// Moves a booking to a new state — confirming it, marking it complete, or
  /// recording a no-show.
  ///
  /// [status] is a [BookingStatus] value such as `CONFIRMED`. Owner/admin only;
  /// the server answers 403 for anyone else.
  Future<Result<void>> updateBookingStatus({
    required String bookingId,
    required String accessToken,
    required String status,
  });

  /// Books a slot on behalf of a walk-in or phone customer, who has no account
  /// of their own — hence [customerDetails] rather than a customer id. The
  /// server auto-confirms these.
  ///
  /// [overridePrice] replaces the price the server would otherwise calculate.
  /// Pass null to let the server price it.
  Future<Result<void>> createManualBooking({
    required String accessToken,
    required String resourceId,
    required DateTime startTime,
    required DateTime endTime,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    num? overridePrice,
  });

  /// [startDate] and [endDate] are inclusive `yyyy-MM-dd` days; the returned
  /// stats are computed server-side across that whole range.
  Future<Result<BusinessPayments>> getBusinessPayments({
    required String businessId,
    required String accessToken,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  });

  /// [status] must be one of `PAID`, `PENDING`, `FAILED`, `REFUNDED`.
  Future<Result<void>> updatePaymentStatus({
    required String paymentId,
    required String accessToken,
    required String status,
  });

  /// Settles several payments in one request. [status] takes the same values
  /// as [updatePaymentStatus].
  Future<Result<void>> bulkUpdatePaymentStatus({
    required List<String> paymentIds,
    required String accessToken,
    required String status,
  });

  Future<Result<void>> updatePaymentMethod({
    required String paymentId,
    required String accessToken,
    required String method,
  });
}
