import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:bookat/src/features/booking/domain/entities/my_booking.dart';
import 'package:flutter_test/flutter_test.dart';

/// The day's takings on the owner's bookings screen must not include bookings
/// that were called off — a cancelled slot earns nothing, so counting it
/// overstates the day's revenue.
void main() {
  MyBooking booking({required String status, required num price}) {
    return MyBookingModel.fromJson({
      'id': 'booking-$status-$price',
      'status': status,
      'totalPrice': price,
      'startTime': '2026-10-22T10:00:00.000Z',
      'resource': {'id': 'r1', 'name': 'L Field'},
    });
  }

  /// Mirrors the sum the timeline header renders.
  num takings(List<MyBooking> bookings) {
    return bookings
        .where((item) => !item.isCancelled)
        .fold<num>(0, (sum, item) => sum + item.totalPrice);
  }

  test('a cancelled booking is excluded from the day total', () {
    final bookings = [
      booking(status: 'CONFIRMED', price: 2500),
      booking(status: 'CANCELLED', price: 2500),
      booking(status: 'PENDING', price: 1000),
    ];

    // 2500 + 1000, not 6000.
    expect(takings(bookings), 3500);
  });

  test('a system rejection is excluded too', () {
    // The customer-facing availability check already treats this the same as a
    // cancellation; revenue has to agree.
    final bookings = [
      booking(status: 'CONFIRMED', price: 2500),
      booking(status: 'REJECTED_BY_SYSTEM', price: 9000),
    ];

    expect(takings(bookings), 2500);
  });

  test('completed and no-show bookings still count', () {
    // A no-show was charged for; it is not a cancellation.
    final bookings = [
      booking(status: 'COMPLETED', price: 2500),
      booking(status: 'NO_SHOW', price: 1500),
    ];

    expect(takings(bookings), 4000);
  });

  test('status casing from the API does not matter', () {
    expect(booking(status: 'cancelled', price: 100).isCancelled, isTrue);
    expect(booking(status: 'Cancelled', price: 100).isCancelled, isTrue);
    expect(booking(status: 'CONFIRMED', price: 100).isCancelled, isFalse);
  });

  test('a day of nothing but cancellations totals zero', () {
    final bookings = [
      booking(status: 'CANCELLED', price: 2500),
      booking(status: 'CANCELLED', price: 2500),
    ];

    expect(takings(bookings), 0);
  });
}
