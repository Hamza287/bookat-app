import '../../domain/entities/booking_confirmation.dart';

class BookingConfirmationModel extends BookingConfirmation {
  const BookingConfirmationModel({required super.data});

  factory BookingConfirmationModel.fromJson(Map<String, dynamic> json) {
    return BookingConfirmationModel(data: _safeMap(json));
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
