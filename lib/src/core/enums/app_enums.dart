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
