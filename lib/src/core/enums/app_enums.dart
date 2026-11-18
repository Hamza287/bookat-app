enum Role {
  superAdmin('SUPER_ADMIN'),
  businessAdmin('BUSINESS_ADMIN'),
  staff('STAFF'),
  customer('CUSTOMER');

  const Role(this.value);

  final String value;

  static Role fromValue(String value) {
    return Role.values.firstWhere(
      (role) => role.value == value,
      orElse: () => Role.customer,
    );
  }
}

enum BusinessType {
  timeSlot('TIME_SLOT'),
  duration('DURATION'),
  capacity('CAPACITY');

  const BusinessType(this.value);

  final String value;
}

enum BookatBusinessModel {
  serviceBased('SERVICE_BASED'),
  venueBased('VENUE_BASED');

  const BookatBusinessModel(this.value);

  final String value;
}

enum DepositType {
  none('NONE'),
  fixed('FIXED'),
  percentage('PERCENTAGE');

  const DepositType(this.value);

  final String value;
}

/// How a payment was settled.
///
/// The server also stores `VENUE` on pay-at-venue bookings, which is a booking
/// choice rather than a way of paying — it is deliberately not offered here,
/// since settling a payment means recording how the money actually arrived.
enum PaymentMethod {
  cash('CASH'),
  online('ONLINE'),
  card('CARD'),
  bankTransfer('BANK_TRANSFER');

  const PaymentMethod(this.value);

  final String value;

  static PaymentMethod? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final needle = raw.trim().toUpperCase();
    for (final method in values) {
      if (method.value == needle) {
        return method;
      }
    }
    return null;
  }
}

enum PaymentStatus {
  pending('PENDING'),
  paid('PAID'),
  failed('FAILED'),
  refunded('REFUNDED');

  const PaymentStatus(this.value);

  final String value;
}

enum BookingStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  cancelled('CANCELLED'),
  completed('COMPLETED'),
  noShow('NO_SHOW'),
  rejectedBySystem('REJECTED_BY_SYSTEM');

  const BookingStatus(this.value);

  final String value;
}
