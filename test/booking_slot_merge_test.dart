import 'package:bookat/src/features/booking/data/models/my_booking_model.dart';
import 'package:bookat/src/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// A booking card shows back-to-back slots as one stretch of time: booking
/// 3–4 and 4–5 reads "3:00 PM - 5:00 PM" rather than listing both halves.
/// Slots with a gap between them stay listed separately.
///
/// Times are built in local time so the expectations hold wherever the suite
/// runs.
void main() {
  group('contiguous slots merge', () {
    test('two back-to-back slots read as one range', () {
      final label = bookingSlotLabel(
        _booking(hours: [15, 16], durationMinutes: 60),
      );

      expect(label, contains('3:00 PM - 5:00 PM'));
      expect(label, isNot(contains('4:00 PM')));
    });

    test('a longer run collapses just the same', () {
      final label = bookingSlotLabel(
        _booking(hours: [9, 10, 11, 12], durationMinutes: 60),
      );

      expect(label, contains('9:00 AM - 1:00 PM'));
    });

    test('half-hour slots merge too', () {
      final booking = _booking(
        starts: [
          DateTime(2026, 7, 21, 15),
          DateTime(2026, 7, 21, 15, 30),
        ],
        durationMinutes: 30,
      );

      expect(bookingSlotLabel(booking), contains('3:00 PM - 4:00 PM'));
    });
  });

  group('separate periods stay separate', () {
    test('a gap keeps both ranges listed', () {
      // 3–5 and 6–7: the 5–6 gap means these are genuinely two periods.
      final label = bookingSlotLabel(
        _booking(hours: [15, 16, 18], durationMinutes: 60),
      );

      expect(label, contains('3:00 PM - 5:00 PM, 6:00 PM - 7:00 PM'));
    });

    test('merges within each run, not across the gap', () {
      final label = bookingSlotLabel(
        _booking(hours: [9, 10, 14, 15], durationMinutes: 60),
      );

      expect(label, contains('9:00 AM - 11:00 AM, 2:00 PM - 4:00 PM'));
    });
  });

  group('shapes the API actually sends', () {
    test('a plain start/end pair is one range, using the booking own end', () {
      // No `slots` list at all — the live `/bookings` payload shape. The end
      // time has to win over the venue's default slot length.
      final booking = MyBookingModel.fromJson({
        'id': 'b1',
        'startTime': DateTime(2026, 7, 21, 15).toUtc().toIso8601String(),
        'endTime': DateTime(2026, 7, 21, 17).toUtc().toIso8601String(),
        'resource': {
          'name': 'R field',
          'attributes': {'durationMinutes': '60'},
        },
      });

      expect(bookingSlotLabel(booking), contains('3:00 PM - 5:00 PM'));
    });

    test('out-of-order slots still merge', () {
      final label = bookingSlotLabel(
        _booking(hours: [16, 15], durationMinutes: 60),
      );

      expect(label, contains('3:00 PM - 5:00 PM'));
    });

    test('a duplicated slot does not split the run', () {
      final label = bookingSlotLabel(
        _booking(hours: [15, 15, 16], durationMinutes: 60),
      );

      expect(label, contains('3:00 PM - 5:00 PM'));
    });

    test('a single slot is unchanged', () {
      final label = bookingSlotLabel(
        _booking(hours: [15], durationMinutes: 60),
      );

      expect(label, contains('Jul 21, 2026'));
      expect(label, contains('3:00 PM - 4:00 PM'));
    });
  });
}

MyBookingModel _booking({
  List<int> hours = const [],
  List<DateTime> starts = const [],
  required int durationMinutes,
}) {
  final slotStarts = starts.isNotEmpty
      ? starts
      : hours.map((hour) => DateTime(2026, 7, 21, hour)).toList();

  final ordered = [...slotStarts]..sort();

  return MyBookingModel.fromJson({
    'id': 'b1',
    'startTime': ordered.first.toUtc().toIso8601String(),
    'endTime': ordered.last
        .add(Duration(minutes: durationMinutes))
        .toUtc()
        .toIso8601String(),
    'slots': [
      for (final start in slotStarts)
        {'startTime': start.toUtc().toIso8601String()},
    ],
    'resource': {
      'name': 'R field',
      'attributes': {'durationMinutes': '$durationMinutes'},
    },
  });
}
