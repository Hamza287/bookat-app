import 'package:equatable/equatable.dart';

class MyBooking extends Equatable {
  const MyBooking({required this.data});

  final Map<String, dynamic> data;

  String get id => _string(['id', 'bookingId']);

  String get status => _string(['status'], fallback: 'PENDING');

  String get businessName {
    return _nestedString([
      ['resource', 'business', 'name'],
      ['business', 'name'],
      ['service', 'business', 'name'],
    ], fallback: _string(['businessName'], fallback: 'Booking'));
  }

  String get resourceName {
    return _nestedString([
      ['resource', 'name'],
      ['service', 'name'],
      ['venue', 'name'],
    ], fallback: _string(['resourceName'], fallback: 'Venue'));
  }

  String get resourceId {
    return _nestedString([
      ['resource', 'id'],
      ['venue', 'id'],
      ['service', 'id'],
    ], fallback: _string(['resourceId', 'venueId', 'serviceId']));
  }

  String get totalPaid {
    final amount = _value([
      'totalPrice',
      'totalAmount',
      'amount',
      'totalPaid',
      'price',
    ]);
    final currency = _nestedString([
      ['resource', 'business', 'settings', 'currency'],
      ['business', 'settings', 'currency'],
      ['service', 'business', 'settings', 'currency'],
    ], fallback: _string(['currency'], fallback: 'PKR'));

    if (amount == null || amount.toString().isEmpty) {
      return '$currency --';
    }

    return '$currency $amount';
  }

  /// A booking that was called off — by the customer, the venue, or the system
  /// rejecting it.
  ///
  /// It holds no slot and earns nothing, so it must be left out of availability
  /// and out of revenue totals alike.
  bool get isCancelled {
    final value = status.toUpperCase();
    return value == 'CANCELLED' || value == 'REJECTED_BY_SYSTEM';
  }

  String get paymentStatus => _string(['paymentStatus']);

  String get paymentMethod => _string(['paymentMethod']);

  /// `/bookings/business/{id}` nests the booker as
  /// `customer: {firstName, lastName, email, phone}`. Only the business-scoped
  /// endpoints include it — a customer's own bookings never do, so every
  /// accessor below degrades to an empty string rather than throwing.
  String get customerName {
    final first = _nestedString([
      ['customer', 'firstName'],
      ['user', 'firstName'],
    ], fallback: '');
    final last = _nestedString([
      ['customer', 'lastName'],
      ['user', 'lastName'],
    ], fallback: '');

    final full = '$first $last'.trim();
    if (full.isNotEmpty) {
      return full;
    }

    return _nestedString([
      ['customer', 'name'],
      ['user', 'name'],
    ], fallback: _string(['customerName']));
  }

  String get customerPhone {
    return _nestedString([
      ['customer', 'phone'],
      ['user', 'phone'],
    ], fallback: _string(['customerPhone', 'phone']));
  }

  String get customerEmail {
    return _nestedString([
      ['customer', 'email'],
      ['user', 'email'],
    ], fallback: _string(['customerEmail', 'email']));
  }

  DateTime? get startDate => DateTime.tryParse(_string(['startTime']));

  DateTime? get endDate => DateTime.tryParse(_string(['endTime']));

  num get basePrice {
    return _num([
      'basePrice',
      'price',
    ], nestedPaths: [
      ['resource', 'basePrice'],
      ['service', 'basePrice'],
    ]);
  }

  num get totalPrice {
    return _num([
      'totalPrice',
      'totalAmount',
      'amount',
      'totalPaid',
      'price',
    ]);
  }

  int get durationMinutes {
    final value = _nestedString([
      ['resource', 'attributes', 'durationMinutes'],
      ['service', 'attributes', 'durationMinutes'],
    ], fallback: _string(['durationMinutes']));

    return int.tryParse(value) ?? 60;
  }

  int get slotCount {
    final rawSlots = data['slots'];
    if (rawSlots is List && rawSlots.isNotEmpty) {
      return rawSlots.length;
    }
    if (basePrice > 0 && totalPrice > 0) {
      final count = (totalPrice / basePrice).round();
      return count < 1 ? 1 : count;
    }
    return 1;
  }

  List<String> get slots {
    final rawSlots = data['slots'];
    if (rawSlots is List) {
      return rawSlots
          .map((slot) {
            if (slot is Map<String, dynamic>) {
              return _stringFromMap(slot, ['startTime', 'time', 'slot']);
            }
            return slot?.toString() ?? '';
          })
          .where((slot) => slot.isNotEmpty)
          .toList(growable: false);
    }

    final slot = _string(['startTime', 'slot', 'time']);
    return slot.isEmpty ? const [] : [slot];
  }

  List<DateTime> get bookedSlotStarts {
    final parsedSlots = slots.map(DateTime.tryParse).whereType<DateTime>().toList();
    if (parsedSlots.isNotEmpty) {
      if (parsedSlots.length > 1 || slotCount <= 1 || endDate == null) {
        return parsedSlots;
      }
    }

    final start = startDate;
    if (start == null) {
      return const [];
    }

    if (slotCount <= 1 || endDate == null) {
      return [start];
    }

    final lastStart = endDate!.subtract(Duration(minutes: durationMinutes));
    if (lastStart.isAtSameMomentAs(start)) {
      return [start];
    }

    return [start, lastStart];
  }

  DateTime? get firstSlotDate {
    return startDate ?? (slots.isEmpty ? null : DateTime.tryParse(slots.first));
  }

  bool get isPast {
    final date = firstSlotDate;
    if (date == null) {
      return false;
    }
    return date.toLocal().isBefore(DateTime.now());
  }

  String _string(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  Object? _value(List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  num _num(
    List<String> keys, {
    List<List<String>> nestedPaths = const [],
  }) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _parseNum(value);
      if (parsed != null) {
        return parsed;
      }
    }

    for (final path in nestedPaths) {
      Object? current = data;
      for (final key in path) {
        if (current is! Map<String, dynamic>) {
          current = null;
          break;
        }
        current = current[key];
      }
      final parsed = _parseNum(current);
      if (parsed != null) {
        return parsed;
      }
    }

    return 0;
  }

  String _nestedString(
    List<List<String>> paths, {
    required String fallback,
  }) {
    for (final path in paths) {
      Object? current = data;
      for (final key in path) {
        if (current is! Map<String, dynamic>) {
          current = null;
          break;
        }
        current = current[key];
      }
      if (current != null && current.toString().isNotEmpty) {
        return current.toString();
      }
    }
    return fallback;
  }

  @override
  List<Object?> get props => [data];
}

String _stringFromMap(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }
  return '';
}

num? _parseNum(Object? value) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '');
}
