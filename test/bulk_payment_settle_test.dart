import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/errors/failure.dart';
import 'package:bookat/src/core/network/api_endpoints.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/business_admin/data/datasources/business_admin_remote_data_source.dart';
import 'package:bookat/src/features/business_admin/data/repositories/business_admin_repository_impl.dart';
import 'package:bookat/src/features/business_admin/domain/entities/business_payment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Several payments are settled in one request:
///
/// ```
/// PATCH /api/payments/bulk-status
/// {"paymentIds": ["...", "..."], "status": "PAID"}
/// ```
///
/// The method is not part of that body, so it is written per payment first —
/// see `BusinessAdminActionController.settlePayments`.
void main() {
  group('bulk status request', () {
    test('sends every id and the status', () async {
      final dataSource = _SpyDataSource();
      final repository = BusinessAdminRepositoryImpl(dataSource);

      final result = await repository.bulkUpdatePaymentStatus(
        paymentIds: const ['pay-1', 'pay-2', 'pay-3'],
        accessToken: 'token-1',
        status: PaymentStatus.paid.value,
      );

      expect(result, isA<Success<void>>());
      expect(dataSource.paymentIds, ['pay-1', 'pay-2', 'pay-3']);
      expect(dataSource.status, 'PAID');
      expect(dataSource.accessToken, 'token-1');
    });

    test('is one call, not one per payment', () async {
      final dataSource = _SpyDataSource();
      final repository = BusinessAdminRepositoryImpl(dataSource);

      await repository.bulkUpdatePaymentStatus(
        paymentIds: const ['pay-1', 'pay-2', 'pay-3'],
        accessToken: 'token-1',
        status: PaymentStatus.paid.value,
      );

      expect(dataSource.calls, 1);
    });

    test('surfaces the server message when it refuses', () async {
      final repository = BusinessAdminRepositoryImpl(_FailingDataSource());

      final result = await repository.bulkUpdatePaymentStatus(
        paymentIds: const ['pay-1'],
        accessToken: 'token-1',
        status: PaymentStatus.paid.value,
      );

      expect(result, isA<Fail<void>>());
      expect(
        (result as Fail<void>).failure,
        isA<Failure>().having(
          (failure) => failure.message,
          'message',
          isNotEmpty,
        ),
      );
    });

    test('the endpoint is the documented one', () {
      expect(ApiEndpoints.paymentsBulkStatus, '/payments/bulk-status');
    });
  });

  group('settling rows in place', () {
    BusinessPayment payment(String id, {String status = 'PENDING'}) {
      return BusinessPayment(
        id: id,
        bookingId: 'booking-$id',
        amount: 2500,
        currency: 'PKR',
        method: 'VENUE',
        status: status,
        customerName: 'Hamza',
        customerPhone: '03001234567',
        resourceName: 'R field',
      );
    }

    test('marks only the ids given', () {
      final before = BusinessPayments(
        payments: [payment('pay-1'), payment('pay-2'), payment('pay-3')],
        stats: const BusinessPaymentStats.empty(),
      );

      final after = before.withSettled(
        paymentIds: {'pay-1', 'pay-3'},
        status: PaymentStatus.paid.value,
        method: PaymentMethod.cash.value,
      );

      expect(after.payments[0].status, 'PAID');
      expect(after.payments[0].method, 'CASH');
      expect(after.payments[2].status, 'PAID');

      // Untouched rows keep everything, so the rest of the list does not
      // rebuild into something different.
      expect(after.payments[1].status, 'PENDING');
      expect(after.payments[1].method, 'VENUE');
    });

    test('keeps the row order', () {
      final before = BusinessPayments(
        payments: [payment('pay-1'), payment('pay-2'), payment('pay-3')],
        stats: const BusinessPaymentStats.empty(),
      );

      final after = before.withSettled(
        paymentIds: {'pay-2'},
        status: PaymentStatus.paid.value,
      );

      expect(
        after.payments.map((item) => item.id),
        ['pay-1', 'pay-2', 'pay-3'],
      );
    });

    test('leaves the server-computed stats alone', () {
      const stats = BusinessPaymentStats(
        totalRevenue: 0,
        numberOfPayments: 0,
        averagePayment: 0,
        pendingRevenue: 10000,
        methodBreakdown: {'CASH': 0},
      );
      final before = BusinessPayments(
        payments: [payment('pay-1')],
        stats: stats,
      );

      // Re-deriving totals here would invent a number; the caller refreshes
      // them from the server instead.
      expect(
        before
            .withSettled(
              paymentIds: {'pay-1'},
              status: PaymentStatus.paid.value,
            )
            .stats,
        stats,
      );
    });

    test('an empty selection changes nothing', () {
      final before = BusinessPayments(
        payments: [payment('pay-1')],
        stats: const BusinessPaymentStats.empty(),
      );

      expect(
        before.withSettled(paymentIds: const {}, status: 'PAID'),
        same(before),
      );
    });
  });

  group('payment enums', () {
    test('carry the values the API uses', () {
      expect(PaymentMethod.cash.value, 'CASH');
      expect(PaymentMethod.online.value, 'ONLINE');
      expect(PaymentMethod.card.value, 'CARD');
      expect(PaymentMethod.bankTransfer.value, 'BANK_TRANSFER');
      expect(PaymentStatus.paid.value, 'PAID');
      expect(PaymentStatus.pending.value, 'PENDING');
    });

    test('tryParse accepts what the API stores and rejects the rest', () {
      expect(PaymentMethod.tryParse('cash'), PaymentMethod.cash);
      expect(PaymentMethod.tryParse('BANK_TRANSFER'), PaymentMethod.bankTransfer);

      // `VENUE` is a booking choice, not a way of paying, so the settle
      // dropdown must not offer it.
      expect(PaymentMethod.tryParse('VENUE'), isNull);
      expect(PaymentMethod.tryParse(null), isNull);
      expect(PaymentMethod.tryParse(''), isNull);
    });
  });
}

class _SpyDataSource implements BusinessAdminRemoteDataSource {
  List<String>? paymentIds;
  String? status;
  String? accessToken;
  int calls = 0;

  @override
  Future<void> bulkUpdatePaymentStatus({
    required List<String> paymentIds,
    required String accessToken,
    required String status,
  }) async {
    calls++;
    this.paymentIds = paymentIds;
    this.accessToken = accessToken;
    this.status = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}

class _FailingDataSource implements BusinessAdminRemoteDataSource {
  @override
  Future<void> bulkUpdatePaymentStatus({
    required List<String> paymentIds,
    required String accessToken,
    required String status,
  }) async {
    throw StateError('the server said no');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
