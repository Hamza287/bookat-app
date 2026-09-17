import 'package:equatable/equatable.dart';

/// Result of asking the API whether closing a date range would strand any
/// existing bookings.
class HolidayBookingCheck extends Equatable {
  const HolidayBookingCheck({
    required this.conflictCount,
    required this.message,
  });

  final int conflictCount;
  final String message;

  bool get hasConflicts => conflictCount > 0;

  @override
  List<Object?> get props => [conflictCount, message];
}
