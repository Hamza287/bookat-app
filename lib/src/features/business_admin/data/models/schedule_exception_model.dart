import '../../domain/entities/schedule_exception.dart';

class ScheduleExceptionModel extends ScheduleException {
  const ScheduleExceptionModel({
    required super.id,
    required super.resourceId,
    super.resourceName,
    required super.date,
    super.endDate,
    super.startTime,
    super.endTime,
    required super.isBlockout,
    super.reason,
    super.createdAt,
  });

  factory ScheduleExceptionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateStr) {
      if (dateStr == null) return DateTime.now();
      if (dateStr is String) return DateTime.parse(dateStr);
      return DateTime.now();
    }

    final resourceObj = json['resource'] is Map<String, dynamic>
        ? json['resource'] as Map<String, dynamic>
        : null;

    return ScheduleExceptionModel(
      id: json['id']?.toString() ?? '',
      resourceId: json['resourceId']?.toString() ??
          (resourceObj != null ? resourceObj['id']?.toString() ?? '' : ''),
      resourceName: json['resourceName']?.toString() ??
          (resourceObj != null
              ? (resourceObj['name'] ?? resourceObj['title'])?.toString()
              : null),
      date: parseDate(json['date']),
      endDate: json['endDate'] != null ? parseDate(json['endDate']) : null,
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      isBlockout: json['isBlockout'] == true,
      reason: json['reason']?.toString(),
      createdAt:
          json['createdAt'] != null ? parseDate(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resourceId': resourceId,
      'date': date.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'isBlockout': isBlockout,
      if (reason != null) 'reason': reason,
    };
  }
}
