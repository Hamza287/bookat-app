import '../../domain/entities/slot_availability.dart';

class SlotAvailabilityModel extends SlotAvailability {
  const SlotAvailabilityModel({
    required super.time,
    required super.available,
  });

  factory SlotAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return SlotAvailabilityModel(
      time: json['time']?.toString() ?? '',
      available: _bool(json['available']),
    );
  }
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}
