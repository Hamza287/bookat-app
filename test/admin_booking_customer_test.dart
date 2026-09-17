import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GET /bookings/business/{id}` nests the booker so the owner can see who
/// reserved a slot. A customer's own bookings (`/bookings/my-bookings`) carry no
/// such block, so every accessor has to degrade quietly instead of throwing.
void main() {
  test('reads the customer nested in a business booking', () {
    final booking = MyBookingModel.fromJson({
      'id': 'bc1a3e18-ba15-4067-a790-0658c8683bc3',
      'status': 'PENDING',
      'startTime': '2026-08-07T16:00:00.000Z',
      'paymentMethod': 'VENUE',
      'customer': {
        'id': '17de26f3',
        'firstName': 'John',
        'lastName': 'Doe',
        'email': 'iamhamxa47@gmail.com',
        'phone': '03044540987',
      },
      'resource': {'name': 'L Field'},
    });

    expect(booking.customerName, 'John Doe');
    expect(booking.customerEmail, 'iamhamxa47@gmail.com');
    expect(booking.customerPhone, '03044540987');
  });

  test('a booking with no customer block yields empty strings, not an error',
      () {
    final booking = MyBookingModel.fromJson({
      'id': 'b1',
      'status': 'CONFIRMED',
      'resource': {'name': 'Main Field'},
    });

    expect(booking.customerName, isEmpty);
    expect(booking.customerPhone, isEmpty);
    expect(booking.customerEmail, isEmpty);
    // The rest of the booking still reads normally.
    expect(booking.resourceName, 'Main Field');
  });

  test('a half-filled customer still produces a usable name', () {
    final booking = MyBookingModel.fromJson({
      'id': 'b2',
      'customer': {'firstName': 'Muhammad', 'phone': '03489366944'},
    });

    expect(booking.customerName, 'Muhammad');
    expect(booking.customerPhone, '03489366944');
    expect(booking.customerEmail, isEmpty);
  });
}
