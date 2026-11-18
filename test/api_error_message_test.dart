import 'package:bookat/src/core/network/api_error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every non-2xx response from this API carries a `message`, and it is usually
/// more useful than anything the client can infer from a status code. It is
/// shown to the user verbatim — except when it is just the HTTP status phrase
/// restated, which tells them nothing.
void main() {
  DioException failure({dynamic body, int status = 400}) {
    final options = RequestOptions(path: '/bookings/x/cancel');
    return DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    );
  }

  test('surfaces the reason the server gave', () {
    final error = failure(
      body: {
        'message': 'Cancellation not allowed within 1 hours of the booking time',
        'error': 'Bad Request',
        'statusCode': 400,
      },
    );

    expect(
      apiErrorMessage(error),
      'Cancellation not allowed within 1 hours of the booking time',
    );
  });

  test('joins field validation errors onto separate lines', () {
    final error = failure(
      body: {
        'message': [
          'newPassword must be longer than or equal to 8 characters',
          'newPassword must contain a number',
        ],
      },
    );

    expect(
      apiErrorMessage(error),
      'newPassword must be longer than or equal to 8 characters\n'
      'newPassword must contain a number',
    );
  });

  test('shows whatever the API says, with no client-side substitution', () {
    // Nothing is filtered or second-guessed: if the API sends it, the user
    // sees it, including terse responses like a bare "Unauthorized".
    for (final phrase in [
      'Unauthorized',
      'Forbidden',
      'Bad Request',
      'This slot was just booked. Please choose another time.',
    ]) {
      expect(apiErrorMessage(failure(body: {'message': phrase})), phrase);
    }
  });

  test('ignores an empty or missing message', () {
    expect(apiErrorMessage(failure(body: {'message': '   '})), isNull);
    expect(apiErrorMessage(failure(body: {'message': []})), isNull);
    expect(apiErrorMessage(failure(body: {'statusCode': 400})), isNull);
    expect(apiErrorMessage(failure(body: 'plain text')), isNull);
  });

  test('a transport failure has no server message', () {
    // No response body at all; a server message here would be invented.
    final offline = DioException(
      requestOptions: RequestOptions(path: '/bookings'),
      type: DioExceptionType.connectionError,
    );

    expect(apiErrorMessage(offline), isNull);
  });

  test('a non-Dio error is ignored', () {
    expect(apiErrorMessage(Exception('boom')), isNull);
    expect(apiErrorMessage('not an error'), isNull);
  });
}
