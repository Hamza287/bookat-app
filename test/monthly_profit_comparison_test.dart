import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:flutter_test/flutter_test.dart';

/// The payments endpoint counts a payment towards `totalRevenue` only once its
/// status is `PAID`; anything still `PENDING` lands in `pendingRevenue`. A month
/// of unsettled bookings therefore reports zero revenue, which is correct but
/// reads as a broken dashboard — hence the comparison carries both figures.
void main() {
  BusinessPaymentStats stats({
    num revenue = 0,
    num pending = 0,
    int count = 0,
  }) {
    return BusinessPaymentStats(
      totalRevenue: revenue,
      numberOfPayments: count,
      averagePayment: count == 0 ? 0 : revenue / count,
      pendingRevenue: pending,
      methodBreakdown: const {},
    );
  }

  MonthlyProfitComparison comparison({
    required BusinessPaymentStats current,
    required BusinessPaymentStats previous,
  }) {
    return MonthlyProfitComparison(
      currentMonth: DateTime(2026, 8),
      previousMonth: DateTime(2026, 7),
      current: current,
      previous: previous,
    );
  }

  test('reports a rise as a percentage of last month', () {
    final result = comparison(
      current: stats(revenue: 15000, count: 6),
      previous: stats(revenue: 12000, count: 5),
    );

    expect(result.revenueChange, 3000);
    expect(result.revenueChangePercent, closeTo(25, 0.001));
    expect(result.isUp, isTrue);
    expect(result.isDown, isFalse);
  });

  test('reports a fall', () {
    final result = comparison(
      current: stats(revenue: 9000),
      previous: stats(revenue: 12000),
    );

    expect(result.revenueChange, -3000);
    expect(result.revenueChangePercent, closeTo(-25, 0.001));
    expect(result.isDown, isTrue);
  });

  test('no percentage when last month collected nothing', () {
    final result = comparison(
      current: stats(revenue: 5000),
      previous: stats(revenue: 0),
    );

    // Dividing by zero would render as infinity; the UI states the money
    // difference instead.
    expect(result.revenueChangePercent, isNull);
    expect(result.revenueChange, 5000);
    expect(result.isUp, isTrue);
  });

  test('an unsettled month reads as zero revenue but non-zero booked', () {
    // Exactly the live data: four pending payments worth 10,000, none paid.
    final result = comparison(
      current: stats(revenue: 0, pending: 10000, count: 0),
      previous: stats(revenue: 0, pending: 0, count: 0),
    );

    expect(result.currentRevenue, 0);
    expect(result.currentPending, 10000);
    // Booked is what makes the month visible on the chart despite zero revenue.
    expect(result.currentBooked, 10000);
    expect(result.isFlat, isTrue);
    expect(result.revenueChangePercent, isNull);
    // Money is on the books, so this is not an empty month.
    expect(result.isEmpty, isFalse);
  });

  test('a genuinely empty month is distinguishable from an unsettled one', () {
    final result = comparison(current: stats(), previous: stats());

    expect(result.isEmpty, isTrue);
    expect(result.isFlat, isTrue);
  });

  test('flat months report no change', () {
    final result = comparison(
      current: stats(revenue: 7500),
      previous: stats(revenue: 7500),
    );

    expect(result.isFlat, isTrue);
    expect(result.revenueChange, 0);
    expect(result.revenueChangePercent, 0);
  });

  test('January compares against December of the previous year', () {
    // The provider builds the previous month as DateTime(year, month - 1);
    // month 0 rolls back a year on its own.
    final previous = DateTime(2027, 1 - 1);

    expect(previous.year, 2026);
    expect(previous.month, 12);
  });
}
