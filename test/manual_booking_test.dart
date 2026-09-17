import 'package:bookat/src/core/utils/result.dart';
import 'package:bookat/src/features/business_admin/data/datasources/business_admin_remote_data_source.dart';
import 'package:bookat/src/features/business_admin/data/repositories/business_admin_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// `POST /bookings` doubles as the owner's manual-booking endpoint. Unlike a
/// customer booking (which posts `slots`), this one posts an explicit
/// start/end window plus the walk-in customer's details, and optionally an
/// `overridePrice`:
///
/// ```json
/// {"resourceId": "...", "startTime": "2026-08-12T06:11:00.000Z",
///  "endTime": "2026-08-12T08:13:00.000Z", "overridePrice": 3000,
///  "customerDetails": {"firstName": "...", "lastName": "...",
///                      "email": "...", "phone": "..."}}
/// ```
///
/// Captured from the working web client on 2026-08-12.
void main() {
  late _SpyDataSource dataSource;
  late BusinessAdminRepositoryImpl repository;

  setUp(() {
    dataSource = _SpyDataSource();
    repository = BusinessAdminRepositoryImpl(dataSource);
  });

  Future<Result<void>> create({num? overridePrice, String email = 'a@b.com'}) {
    return repository.createManualBooking(
      accessToken: 'token',
      resourceId: '8c8fbdf5-1454-401d-a833-67b035d83402',
      // Deliberately local: the API works in UTC, and converting is the
      // repository's job, not the caller's.
      startTime: DateTime.utc(2026, 8, 12, 6, 11).toLocal(),
      endTime: DateTime.utc(2026, 8, 12, 8, 13).toLocal(),
      firstName: 'hamza',
      lastName: 'ibrahim',
      email: email,
      phone: '03044540987',
      overridePrice: overridePrice,
    );
  }

  test('sends the exact shape the API expects', () async {
    final result = await create(overridePrice: 3000);

    expect(result, isA<Success<void>>());

    final body = dataSource.lastBody!;
    expect(body['resourceId'], '8c8fbdf5-1454-401d-a833-67b035d83402');
    expect(body['startTime'], '2026-08-12T06:11:00.000Z');
    expect(body['endTime'], '2026-08-12T08:13:00.000Z');
    expect(body['overridePrice'], 3000);

    final customer = body['customerDetails'] as Map<String, dynamic>;
    expect(customer['firstName'], 'hamza');
    expect(customer['lastName'], 'ibrahim');
    expect(customer['email'], 'a@b.com');
    expect(customer['phone'], '03044540987');
  });

  test('omits overridePrice entirely when the owner types no custom price',
      () async {
    await create();

    // Present-but-null would ask the server to charge nothing; the key has to
    // be absent for the server to price the slot itself.
    expect(dataSource.lastBody!.containsKey('overridePrice'), isFalse);
  });

  test('omits an empty optional email rather than sending a blank string',
      () async {
    await create(email: '');

    final customer =
        dataSource.lastBody!['customerDetails'] as Map<String, dynamic>;
    expect(customer.containsKey('email'), isFalse);
    expect(customer['phone'], '03044540987');
  });

  test('converts local wall-clock times to UTC', () async {
    await repository.createManualBooking(
      accessToken: 'token',
      resourceId: 'r1',
      startTime: DateTime.utc(2026, 8, 12, 9).toLocal(),
      endTime: DateTime.utc(2026, 8, 12, 10).toLocal(),
      firstName: 'a',
      lastName: 'b',
      email: '',
      phone: '1',
    );

    // Sending the raw local clock would shift every manual booking by the
    // owner's UTC offset.
    expect(dataSource.lastBody!['startTime'], '2026-08-12T09:00:00.000Z');
    expect(dataSource.lastBody!['endTime'], '2026-08-12T10:00:00.000Z');
  });
}

/// Records the body the repository builds. Every other endpoint falls through
/// to [noSuchMethod] and throws, so a stray call fails loudly instead of
/// silently returning null.
class _SpyDataSource implements BusinessAdminRemoteDataSource {
  Map<String, dynamic>? lastBody;

  @override
  Future<void> createManualBooking({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    lastBody = body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not exercised by this test',
    );
  }
}
