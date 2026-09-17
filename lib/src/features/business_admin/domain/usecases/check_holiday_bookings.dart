import '../../../../core/utils/result.dart';
import '../entities/holiday_booking_check.dart';
import '../repositories/business_admin_repository.dart';

class CheckHolidayBookings {
  const CheckHolidayBookings(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<HolidayBookingCheck>> call({
    required String businessId,
    required String accessToken,
    required DateTime date,
    required DateTime endDate,
  }) {
    return _repository.checkHolidayBookings(
      businessId: businessId,
      accessToken: accessToken,
      date: date,
      endDate: endDate,
    );
  }
}
