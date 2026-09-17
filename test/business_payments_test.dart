import 'package:bookat/src/features/business_admin/data/models/business_payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GET /payments/business/{businessId}` wraps its rows alongside a
/// server-computed `stats` block, and nests the whole booking — customer and
/// resource included — inside each payment:
///
/// ```json
/// {"data": [...], "stats": {...}, "meta": {...}}
/// ```
///
/// Captured from the live API on 2026-08-06. The Postman collection predates the
/// payments module, so this test is the only record of the contract.
void main() {
  Map<String, dynamic> payload() {
    return {
      'data': [
        {
          'id': 'c0c522b1-44da-4c86-9fb6-b8a2399a8e99',
          'bookingId': 'bc1a3e18-ba15-4067-a790-0658c8683bc3',
          'amount': 2500,
          'currency': 'PKR',
          'method': 'VENUE',
          'status': 'PENDING',
          'transactionId': null,
          'createdAt': '2026-08-04T21:55:12.654Z',
          'booking': {
            'id': 'bc1a3e18-ba15-4067-a790-0658c8683bc3',
            'startTime': '2026-08-07T16:00:00.000Z',
            'endTime': '2026-08-07T17:00:00.000Z',
            'totalPrice': 2500,
            'paymentMethod': 'VENUE',
            'paymentStatus': 'UNPAID',
            'customer': {
              'firstName': 'Muhammad',
              'lastName': 'Pervaiz',
              'phone': '03489366944',
            },
            'resource': {'id': 'bf72c5f9', 'name': 'L Field'},
            'service': null,
          },
        },
      ],
      'stats': {
        'totalRevenue': 0,
        'numberOfPayments': 0,
        'averagePayment': 0,
        'pendingRevenue': 10000,
        'methodBreakdown': {
          'CASH': 0,
          'ONLINE': 0,
          'CARD': 0,
          'BANK_TRANSFER': 0,
        },
      },
      'meta': {'total': 4, 'page': 1, 'limit': 100, 'totalPages': 1},
    };
  }

  test('flattens the nested booking, customer and resource', () {
    final payments = BusinessPaymentsModel.fromJson(payload());

    expect(payments.payments, hasLength(1));

    final payment = payments.payments.single;
    expect(payment.id, 'c0c522b1-44da-4c86-9fb6-b8a2399a8e99');
    expect(payment.amount, 2500);
    expect(payment.currency, 'PKR');
    expect(payment.status, 'PENDING');
    expect(payment.isPending, isTrue);
    expect(payment.isPaid, isFalse);
    // Name and phone live two levels down, under booking.customer.
    expect(payment.customerName, 'Muhammad Pervaiz');
    expect(payment.customerPhone, '03489366944');
    expect(payment.resourceName, 'L Field');
    expect(payment.slotStart, DateTime.parse('2026-08-07T16:00:00.000Z'));
  });

  test('reads the server-computed stats rather than summing the rows', () {
    final payments = BusinessPaymentsModel.fromJson(payload());

    // The single row on this page is worth 2500, but the range holds 10000 of
    // pending revenue — the stats block covers the whole filtered range, so
    // re-deriving it from the visible rows would under-report.
    expect(payments.stats.pendingRevenue, 10000);
    expect(payments.stats.totalRevenue, 0);
    expect(payments.stats.numberOfPayments, 0);
    expect(payments.stats.methodBreakdown['BANK_TRANSFER'], 0);
    expect(payments.stats.methodBreakdown, hasLength(4));
  });

  test('a month with no payments parses as empty rather than throwing', () {
    final payments = BusinessPaymentsModel.fromJson({
      'data': <dynamic>[],
      'stats': {
        'totalRevenue': 0,
        'numberOfPayments': 0,
        'averagePayment': 0,
        'pendingRevenue': 0,
        'methodBreakdown': <String, dynamic>{},
      },
      'meta': {'total': 0},
    });

    expect(payments.payments, isEmpty);
    expect(payments.stats.totalRevenue, 0);
  });

  test('a bare array is still accepted, with empty stats', () {
    final payments = BusinessPaymentsModel.fromJson([
      {
        'id': 'p1',
        'amount': '1500',
        'status': 'paid',
        'booking': {
          'customer': {'firstName': 'Ali'},
        },
      },
    ]);

    final payment = payments.payments.single;
    // A string amount and a lowercase status both normalise.
    expect(payment.amount, 1500);
    expect(payment.status, 'PAID');
    expect(payment.isPaid, isTrue);
    expect(payment.customerName, 'Ali');
    expect(payment.resourceName, 'Venue');
    expect(payments.stats.totalRevenue, 0);
  });

  test('an unusable payload is rejected', () {
    expect(
      () => BusinessPaymentsModel.fromJson({'error': 'boom'}),
      throwsA(isA<FormatException>()),
    );
  });
}
