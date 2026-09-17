import '../../domain/entities/my_booking.dart';

class MyBookingModel extends MyBooking {
  const MyBookingModel({required super.data});

  factory MyBookingModel.fromJson(Map<String, dynamic> json) {
    return MyBookingModel(data: _safeMap(json));
  }
}

Map<String, dynamic> _safeMap(Map<String, dynamic> json) {
  return json.map((key, value) {
    if (value is Map<String, dynamic>) {
      return MapEntry(key, _safeMap(value));
    }
    if (value is List) {
      return MapEntry(key, value.where((item) => item != null).toList());
    }
    return MapEntry(key, value ?? '');
  });
}
