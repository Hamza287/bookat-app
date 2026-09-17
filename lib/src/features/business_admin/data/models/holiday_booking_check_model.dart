import '../../domain/entities/holiday_booking_check.dart';

class HolidayBookingCheckModel extends HolidayBookingCheck {
  const HolidayBookingCheckModel({
    required super.conflictCount,
    required super.message,
  });

  /// The check-bookings response body is not documented in the API collection,
  /// so a few plausible key spellings are accepted. Narrow this to the real one
  /// once the payload is confirmed against the running API.
  factory HolidayBookingCheckModel.fromJson(Map<String, dynamic> json) {
    return HolidayBookingCheckModel(
      conflictCount: _count(json),
      message: json['message']?.toString() ?? '',
    );
  }
}

int _count(Map<String, dynamic> json) {
  for (final key in ['count', 'conflictCount', 'affectedBookings', 'total']) {
    final value = json[key];
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }

  for (final key in ['bookings', 'conflictingBookings', 'data']) {
    final value = json[key];
    if (value is List) {
      return value.length;
    }
  }

  for (final key in ['hasConflicts', 'hasBookings']) {
    final value = json[key];
    if (value is bool) {
      return value ? 1 : 0;
    }
  }

  return 0;
}
