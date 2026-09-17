import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pinned against a real `GET /api/bookings/business/:id` response captured
/// from the live API, so the getters the UI renders are checked against the
/// payload the server actually sends rather than the tidy mock fixture.
void main() {
  final payload = <String, dynamic>{
    'id': 'd9ba006c-85fb-4a8c-a713-354d2b394a55',
    'customerId': '587627fd-791a-47b3-a311-eebad4f4c166',
    'resourceId': '8c8fbdf5-1454-401d-a833-67b035d83402',
    'serviceId': null,
    'facilityId': null,
    'startTime': '2026-07-21T15:00:00.000Z',
    'endTime': '2026-07-21T16:00:00.000Z',
    'parentBookingId': null,
    'quantity': 1,
    'totalPrice': 2500,
    'originalPrice': null,
    'discount': null,
    'status': 'PENDING',
    'paymentMethod': 'VENUE',
    'paymentStatus': 'UNPAID',
    'transactionId': null,
    'createdAt': '2026-07-21T12:35:59.705Z',
    'updatedAt': '2026-07-21T12:35:59.705Z',
    'customer': {
      'id': '587627fd-791a-47b3-a311-eebad4f4c166',
      'firstName': 'hamza',
      'lastName': 'ibrahim',
      'email': 'hamzaibrahimflutter@gmail.com',
      'phone': '03044540987',
    },
    'resource': {
      'id': '8c8fbdf5-1454-401d-a833-67b035d83402',
      'businessId': '08ac5318-7fb7-4575-860e-fb3c99173fb5',
      'staffUserId': null,
      'name': 'R field',
      'basePrice': 2500,
      'attributes': {
        'mapLayout': {'h': 100, 'w': 50, 'x': 50, 'y': 0},
        'pricingRules': <dynamic>[],
        // Note: a string here, while other resources return an int.
        'durationMinutes': '60',
      },
      'isActive': true,
      'categoryId': '94268956-0c46-46ca-9e86-815b762c5122',
    },
  };

  group('MyBooking against the live payload', () {
    late MyBookingModel booking;

    setUp(() => booking = MyBookingModel.fromJson(payload));

    test('reads the fields that are present', () {
      expect(booking.id, 'd9ba006c-85fb-4a8c-a713-354d2b394a55');
      expect(booking.status, 'PENDING');
      expect(booking.resourceName, 'R field');
      expect(booking.resourceId, '8c8fbdf5-1454-401d-a833-67b035d83402');
      expect(booking.paymentMethod, 'VENUE');
      expect(booking.paymentStatus, 'UNPAID');
      expect(booking.totalPrice, 2500);
      expect(booking.basePrice, 2500);
      expect(booking.durationMinutes, 60);
    });

    test('derives a single slot from startTime when slots are absent', () {
      expect(booking.slots, ['2026-07-21T15:00:00.000Z']);
      expect(booking.slotCount, 1);
      expect(booking.bookedSlotStarts, [DateTime.parse(payload['startTime'] as String)]);
    });

    // Documents a real gap: this response carries no nested business object,
    // so every business-derived getter silently falls back.
    test('businessName falls back because no business is nested', () {
      expect(booking.businessName, 'Booking');
    });

    test('totalPaid only looks right because PKR is the fallback currency', () {
      expect(booking.totalPaid, 'PKR 2500');
    });
  });
}
