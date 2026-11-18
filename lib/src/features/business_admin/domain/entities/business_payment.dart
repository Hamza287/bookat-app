import 'package:equatable/equatable.dart';

/// One payment row from `GET /payments/business/{businessId}`, with the booking
/// it settles flattened in — the API nests the whole booking (and its customer
/// and resource) inside each payment.
class BusinessPayment extends Equatable {
  const BusinessPayment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.resourceName,
    this.slotStart,
    this.createdAt,
  });

  final String id;
  final String bookingId;
  final num amount;
  final String currency;

  /// Free-form on the server — `VENUE`, `CASH`, `ONLINE`, `CARD`,
  /// `BANK_TRANSFER` have all been observed. Never assume a closed set.
  final String method;

  /// One of `PENDING`, `PAID`, `FAILED`, `REFUNDED`.
  final String status;

  final String customerName;
  final String customerPhone;
  final String resourceName;

  /// Start of the booked slot, not when the payment was recorded.
  final DateTime? slotStart;
  final DateTime? createdAt;

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isPending => status.toUpperCase() == 'PENDING';

  BusinessPayment copyWith({String? method, String? status}) {
    return BusinessPayment(
      id: id,
      bookingId: bookingId,
      amount: amount,
      currency: currency,
      method: method ?? this.method,
      status: status ?? this.status,
      customerName: customerName,
      customerPhone: customerPhone,
      resourceName: resourceName,
      slotStart: slotStart,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookingId,
        amount,
        currency,
        method,
        status,
        customerName,
        customerPhone,
        resourceName,
        slotStart,
        createdAt,
      ];
}

/// The `stats` block the payments endpoint returns alongside the rows. Computed
/// server-side over the whole filtered range, so it must not be re-derived from
/// the page of rows on screen.
class BusinessPaymentStats extends Equatable {
  const BusinessPaymentStats({
    required this.totalRevenue,
    required this.numberOfPayments,
    required this.averagePayment,
    required this.pendingRevenue,
    required this.methodBreakdown,
  });

  const BusinessPaymentStats.empty()
      : totalRevenue = 0,
        numberOfPayments = 0,
        averagePayment = 0,
        pendingRevenue = 0,
        methodBreakdown = const {};

  final num totalRevenue;
  final int numberOfPayments;
  final num averagePayment;
  final num pendingRevenue;

  /// Keyed by method (`CASH`, `ONLINE`, `CARD`, `BANK_TRANSFER`).
  final Map<String, num> methodBreakdown;

  @override
  List<Object?> get props => [
        totalRevenue,
        numberOfPayments,
        averagePayment,
        pendingRevenue,
        methodBreakdown,
      ];
}

class BusinessPayments extends Equatable {
  const BusinessPayments({required this.payments, required this.stats});

  final List<BusinessPayment> payments;
  final BusinessPaymentStats stats;

  /// The same month with [paymentIds] settled.
  ///
  /// [stats] is deliberately carried over untouched: it is computed server-side
  /// over the whole range, so re-deriving it here would invent a number. The
  /// caller refreshes it from the server afterwards.
  BusinessPayments withSettled({
    required Set<String> paymentIds,
    required String status,
    String? method,
  }) {
    if (paymentIds.isEmpty) {
      return this;
    }

    return BusinessPayments(
      payments: [
        for (final payment in payments)
          if (paymentIds.contains(payment.id))
            payment.copyWith(status: status, method: method)
          else
            payment,
      ],
      stats: stats,
    );
  }

  @override
  List<Object?> get props => [payments, stats];
}

/// One month's takings measured against the month before it.
///
/// "Revenue" here is money actually collected — the API only counts a payment
/// once its status is `PAID`. Bookings that are made but unsettled sit in
/// [currentPending] instead, which is why a busy month can still report zero
/// revenue and why both figures are carried together.
class MonthlyProfitComparison extends Equatable {
  const MonthlyProfitComparison({
    required this.currentMonth,
    required this.previousMonth,
    required this.current,
    required this.previous,
  });

  /// First day of each month being compared.
  final DateTime currentMonth;
  final DateTime previousMonth;

  final BusinessPaymentStats current;
  final BusinessPaymentStats previous;

  num get currentRevenue => current.totalRevenue;
  num get previousRevenue => previous.totalRevenue;
  num get revenueChange => currentRevenue - previousRevenue;

  num get currentPending => current.pendingRevenue;
  num get previousPending => previous.pendingRevenue;

  /// Everything the month is worth, settled or not. An owner comparing "profit"
  /// usually means this, not just what has cleared.
  num get currentBooked => currentRevenue + currentPending;
  num get previousBooked => previousRevenue + previousPending;

  int get currentPayments => current.numberOfPayments;
  int get previousPayments => previous.numberOfPayments;

  /// Null when last month collected nothing: a rise from zero has no meaningful
  /// percentage, and both "∞%" and "100%" would misrepresent it.
  double? get revenueChangePercent {
    if (previousRevenue == 0) {
      return null;
    }
    return (revenueChange / previousRevenue) * 100;
  }

  bool get isUp => revenueChange > 0;
  bool get isDown => revenueChange < 0;
  bool get isFlat => revenueChange == 0;

  /// True when nothing at all has been recorded either month — the difference
  /// between "no trade" and "a quiet month" is worth showing differently.
  bool get isEmpty =>
      currentBooked == 0 &&
      previousBooked == 0 &&
      currentPayments == 0 &&
      previousPayments == 0;

  @override
  List<Object?> get props => [currentMonth, previousMonth, current, previous];
}
