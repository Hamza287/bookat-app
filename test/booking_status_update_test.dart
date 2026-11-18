import 'package:bookat/src/core/constants/app_strings.dart';
import 'package:bookat/src/core/enums/app_enums.dart';
import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/business_admin/data/datasources/business_admin_remote_data_source.dart';
import 'package:bookat/src/features/business_admin/data/repositories/business_admin_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// `PATCH /bookings/:id/status` with `{"status": "<BookingStatus.value>"}`
/// moves a booking between states from the owner's dashboard. The endpoint is
/// owner/admin only — a customer token is answered with 403.
void main() {
  late _SpyDataSource dataSource;
  late BusinessAdminRepositoryImpl repository;

  setUp(() {
    dataSource = _SpyDataSource();
    repository = BusinessAdminRepositoryImpl(dataSource);
  });

  test('sends the booking id and the enum value', () async {
    final result = await repository.updateBookingStatus(
      bookingId: 'bc1a3e18-ba15-4067-a790-0658c8683bc3',
      accessToken: 'token',
      status: BookingStatus.completed.value,
    );

    expect(result, isA<Success<void>>());
    expect(dataSource.lastBookingId, 'bc1a3e18-ba15-4067-a790-0658c8683bc3');
    expect(dataSource.lastStatus, 'COMPLETED');
  });

  test('every status the menu offers is a valid enum value', () {
    // The menu is built from BookingStatus, so these are exactly the strings
    // the server will receive.
    expect(BookingStatus.pending.value, 'PENDING');
    expect(BookingStatus.confirmed.value, 'CONFIRMED');
    expect(BookingStatus.completed.value, 'COMPLETED');
    expect(BookingStatus.noShow.value, 'NO_SHOW');
    expect(BookingStatus.cancelled.value, 'CANCELLED');
  });

  test('the confirmation names the status it was set to', () {
    // This read "Booking marked as ." once, because the interpolation was lost
    // when the string was generated — the message has to name the new state.
    expect(
      AppStrings.bookingStatusUpdated('Completed'),
      'Booking marked as Completed.',
    );
    expect(AppStrings.bookingStatusUpdated('No Show'), contains('No Show'));
  });

  test('a permission failure surfaces the server message', () async {
    // Exactly what the live API returns for a non-owner account.
    dataSource.error = DioException(
      requestOptions: RequestOptions(path: '/bookings/x/status'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/bookings/x/status'),
        statusCode: 403,
        data: {
          'message': 'You do not have permission to access this resource.',
          'error': 'Forbidden',
          'statusCode': 403,
        },
      ),
    );

    final result = await repository.updateBookingStatus(
      bookingId: 'x',
      accessToken: 'token',
      status: 'CONFIRMED',
    );

    expect(
      result,
      isA<Fail<void>>().having(
        (fail) => fail.failure.message,
        'message',
        'You do not have permission to access this resource.',
      ),
    );
  });

  test('a rejected change falls back when the server explains nothing',
      () async {
    dataSource.error = DioException(
      requestOptions: RequestOptions(path: '/bookings/x/status'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/bookings/x/status'),
        statusCode: 404,
      ),
    );

    final result = await repository.updateBookingStatus(
      bookingId: 'x',
      accessToken: 'token',
      status: 'CONFIRMED',
    );

    expect(
      result,
      isA<Fail<void>>().having(
        (fail) => fail.failure.message,
        'message',
        'That booking no longer exists.',
      ),
    );
  });
}

class _SpyDataSource implements BusinessAdminRemoteDataSource {
  String? lastBookingId;
  String? lastStatus;
  Object? error;

  @override
  Future<void> updateBookingStatus({
    required String bookingId,
    required String accessToken,
    required String status,
  }) async {
    lastBookingId = bookingId;
    lastStatus = status;
    if (error != null) {
      throw error!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
