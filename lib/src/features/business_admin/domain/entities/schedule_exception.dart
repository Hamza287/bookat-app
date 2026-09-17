import 'package:equatable/equatable.dart';

class ScheduleException extends Equatable {
  const ScheduleException({
    required this.id,
    required this.resourceId,
    this.resourceName,
    required this.date,
    this.endDate,
    this.startTime,
    this.endTime,
    required this.isBlockout,
    this.reason,
    this.createdAt,
  });

  final String id;
  final String resourceId;
  final String? resourceName;
  final DateTime date;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final bool isBlockout;
  final String? reason;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        resourceId,
        resourceName,
        date,
        endDate,
        startTime,
        endTime,
        isBlockout,
        reason,
        createdAt,
      ];
}
