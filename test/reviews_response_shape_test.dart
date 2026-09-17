import 'dart:convert';

import 'package:bookat/src/core/network/api_client.dart';
import 'package:bookat/src/features/booking/data/datasources/dio_booking_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GET /reviews/business/{businessId}` does **not** answer with a bare array
/// like most of this API — it wraps the list next to summary fields:
///
/// ```json
/// {"averageRating":4,"reviewCount":1,"reviews":[ ... ]}
/// ```
///
/// (Verified against https://api-bookat.tsgtech.co on 2026-07-31.) The response
/// unwrapper used to look only for `data`/`bookings`/`items`/`results`, so every
/// business detail page ended in "Invalid reviews response." — including
/// businesses with no reviews at all, where `reviews` is simply `[]`.
void main() {
  DioBookingRemoteDataSource dataSourceReturning(Object? payload) {
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter(payload);
    return DioBookingRemoteDataSource(ApiClient(dio));
  }

  test('reads the reviews list out of the summary envelope', () async {
    final source = dataSourceReturning({
      'averageRating': 4,
      'reviewCount': 1,
      'reviews': [
        {
          'id': 'f5ff6d91-9124-4cdf-9ef1-23bf146a3571',
          'rating': 4,
          'comment': 'nice',
          'userId': '17de26f3-631a-4c22-8708-be7f571d5acc',
          'businessId': '08ac5318-7fb7-4575-860e-fb3c99173fb5',
          'bookingId': '969227d2-22e1-47a4-8697-ae9bd4e62ff4',
          'createdAt': '2026-07-30T11:49:48.357Z',
          'updatedAt': '2026-07-30T11:49:48.357Z',
          'user': {
            'firstName': 'John',
            'lastName': 'Doe',
            'id': '17de26f3-631a-4c22-8708-be7f571d5acc',
          },
        },
      ],
    });

    final reviews = await source.getBusinessReviews('business-1');

    expect(reviews, hasLength(1));
    expect(reviews.single.rating, 4);
    expect(reviews.single.comment, 'nice');
    // The author comes from the nested `user` object, not a flat field.
    expect(reviews.single.customerName, 'John Doe');
    expect(reviews.single.createdAt, DateTime.parse('2026-07-30T11:49:48.357Z'));
  });

  test('a business with no reviews yet returns an empty list, not an error',
      () async {
    final source = dataSourceReturning({
      'averageRating': 0,
      'reviewCount': 0,
      'reviews': <dynamic>[],
    });

    await expectLater(source.getBusinessReviews('business-1'), completion(isEmpty));
  });

  test('a bare array still works', () async {
    final source = dataSourceReturning([
      {'id': 'r1', 'rating': 5, 'comment': 'great'},
    ]);

    final reviews = await source.getBusinessReviews('business-1');

    expect(reviews.single.rating, 5);
  });

  test('a genuinely unusable payload is still rejected', () async {
    final source = dataSourceReturning({'error': 'boom'});

    await expectLater(
      source.getBusinessReviews('business-1'),
      throwsA(isA<FormatException>()),
    );
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.payload);

  final Object? payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      _encode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _encode(Object? payload) {
  return const JsonEncoder().convert(payload);
}
