import '../../domain/entities/business_payment.dart';

/// Parses `GET /payments/business/{businessId}`, whose shape is:
///
/// ```json
/// {"data": [{"id": "...", "amount": 2500, "currency": "PKR",
///            "method": "VENUE", "status": "PENDING",
///            "booking": {"startTime": "...",
///                        "customer": {"firstName": "...", "phone": "..."},
///                        "resource": {"name": "L Field"}}}],
///  "stats": {"totalRevenue": 0, "pendingRevenue": 10000, ...},
///  "meta": {"total": 4, "page": 1, ...}}
/// ```
///
/// Verified against the live API on 2026-08-06; the Postman collection predates
/// the payments module and documents none of it.
class BusinessPaymentModel extends BusinessPayment {
  const BusinessPaymentModel({
    required super.id,
    required super.bookingId,
    required super.amount,
    required super.currency,
    required super.method,
    required super.status,
    required super.customerName,
    required super.customerPhone,
    required super.resourceName,
    super.slotStart,
    super.createdAt,
  });

  factory BusinessPaymentModel.fromJson(Map<String, dynamic> json) {
    final booking = _map(json['booking']);
    final customer = _map(booking?['customer']);
    final resource = _map(booking?['resource']);

    final first = _string(customer?['firstName']);
    final last = _string(customer?['lastName']);

    return BusinessPaymentModel(
      id: _string(json['id']),
      bookingId: _string(json['bookingId']) ,
      amount: _num(json['amount'] ?? booking?['totalPrice']),
      currency: _string(json['currency'], fallback: 'PKR'),
      method: _string(json['method'] ?? booking?['paymentMethod']),
      status: _string(json['status'], fallback: 'PENDING').toUpperCase(),
      customerName: '$first $last'.trim(),
      customerPhone: _string(customer?['phone']),
      resourceName: _string(resource?['name'], fallback: 'Venue'),
      slotStart: DateTime.tryParse(_string(booking?['startTime'])),
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
    );
  }
}

class BusinessPaymentStatsModel extends BusinessPaymentStats {
  const BusinessPaymentStatsModel({
    required super.totalRevenue,
    required super.numberOfPayments,
    required super.averagePayment,
    required super.pendingRevenue,
    required super.methodBreakdown,
  });

  factory BusinessPaymentStatsModel.fromJson(Map<String, dynamic> json) {
    final breakdown = _map(json['methodBreakdown']) ?? const {};

    return BusinessPaymentStatsModel(
      totalRevenue: _num(json['totalRevenue']),
      numberOfPayments: _num(json['numberOfPayments']).toInt(),
      averagePayment: _num(json['averagePayment']),
      pendingRevenue: _num(json['pendingRevenue']),
      methodBreakdown: {
        for (final entry in breakdown.entries)
          entry.key.toString(): _num(entry.value),
      },
    );
  }
}

class BusinessPaymentsModel extends BusinessPayments {
  const BusinessPaymentsModel({required super.payments, required super.stats});

  factory BusinessPaymentsModel.fromJson(Object? payload) {
    // A bare array is accepted too, in case the endpoint is ever simplified to
    // match the rest of this API.
    if (payload is List) {
      return BusinessPaymentsModel(
        payments: _payments(payload),
        stats: const BusinessPaymentStats.empty(),
      );
    }

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid payments response.');
    }

    final rows = payload['data'] ?? payload['payments'] ?? payload['items'];
    final stats = _map(payload['stats']);

    return BusinessPaymentsModel(
      payments: _payments(rows),
      stats: stats == null
          ? const BusinessPaymentStats.empty()
          : BusinessPaymentStatsModel.fromJson(stats),
    );
  }
}

List<BusinessPaymentModel> _payments(Object? rows) {
  if (rows is! List) {
    throw const FormatException('Invalid payments response.');
  }

  return rows
      .whereType<Map<String, dynamic>>()
      .map(BusinessPaymentModel.fromJson)
      .toList(growable: false);
}

Map<String, dynamic>? _map(Object? value) {
  return value is Map<String, dynamic> ? value : null;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

num _num(Object? value) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
