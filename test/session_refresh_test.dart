import 'dart:convert';

import 'package:bookat/src/core/utils/jwt.dart';
import 'package:bookat/src/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// An expired access token must renew itself without the user noticing. Two
/// things used to get in the way:
///
///  * the refreshed token reached storage but not the in-memory session, so
///    every later call still sent the expired one;
///  * any failure during refresh — including a dropped connection — signed the
///    user out.
void main() {
  /// Builds a JWT with the given expiry. Only the payload matters here; nothing
  /// in the app verifies the signature.
  String tokenExpiring(DateTime expiry) {
    String segment(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

    final header = segment({'alg': 'HS256', 'typ': 'JWT'});
    final payload = segment({
      'sub': 'user-1',
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
    });
    return '$header.$payload.signature';
  }

  group('jwt expiry', () {
    test('reads the expiry out of a real token', () {
      final expiry = DateTime.utc(2026, 9, 22, 12);
      final token = tokenExpiring(expiry);

      expect(jwtExpiry(token), expiry);
    });

    test('a token that has passed its expiry is expired', () {
      final token = tokenExpiring(
        DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );

      expect(isJwtExpired(token), isTrue);
    });

    test('a token with hours left is not expired', () {
      final token = tokenExpiring(
        DateTime.now().toUtc().add(const Duration(hours: 5)),
      );

      expect(isJwtExpired(token), isFalse);
    });

    test('a token about to expire counts as expired', () {
      // Thirty seconds is not enough to finish a request, so it is renewed now
      // rather than failing mid-flight.
      final token = tokenExpiring(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );

      expect(isJwtExpired(token), isTrue);
    });

    test('an unreadable token reports as not expired, never as expired', () {
      // Guessing "expired" would sign people out over a token we simply could
      // not parse; the interceptor handles the real answer instead.
      expect(isJwtExpired('not-a-jwt'), isFalse);
      expect(isJwtExpired(''), isFalse);
      expect(jwtExpiry('a.b.c'), isNull);
    });
  });

  group('interceptor', () {
    late Dio dio;
    late DioAdapterStub adapter;
    var refreshCalls = 0;
    var sessionExpiredCalls = 0;
    String? tokenWrittenBack;
    String? refreshTokenWrittenBack;

    setUp(() {
      refreshCalls = 0;
      sessionExpiredCalls = 0;
      tokenWrittenBack = null;
      refreshTokenWrittenBack = null;

      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      adapter = DioAdapterStub();
      dio.httpClientAdapter = adapter;

      final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;

      dio.interceptors.add(
        AuthInterceptor(
          readTokens: () async => const StoredTokens(
            accessToken: 'expired',
            refreshToken: 'refresh-1',
          ),
          onTokensRefreshed: (tokens) async {
            refreshCalls++;
            tokenWrittenBack = tokens.accessToken;
            refreshTokenWrittenBack = tokens.refreshToken;
          },
          onSessionExpired: () async => sessionExpiredCalls++,
          refreshDio: refreshDio,
          retryDio: dio,
        ),
      );
    });

    test('a 401 refreshes and replays the request, invisibly', () async {
      adapter
        ..onPath('/bookings', statuses: [401, 200])
        ..onPath('/auth/refresh', statuses: [200], body: {
          'access_token': 'fresh',
          'refresh_token': 'refresh-2',
        });

      final response = await dio.get<dynamic>('/bookings');

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(tokenWrittenBack, 'fresh');
      // The replay carries the new token, not the one that just failed.
      expect(adapter.lastAuthorizationFor('/bookings'), 'Bearer fresh');
      expect(sessionExpiredCalls, 0);
    });

    test('the real refresh contract: send refreshToken, get access_token only',
        () async {
      // Confirmed against the live API on 2026-09-22:
      //   POST /api/auth/refresh  {"refreshToken": "<jwt>"}
      //   201  {"access_token": "<jwt>"}
      // No refresh_token comes back, so the stored one has to survive.
      adapter
        ..onPath('/bookings', statuses: [401, 200])
        ..onPath('/auth/refresh', statuses: [200], body: {
          'access_token': 'fresh-access-only',
        });

      final response = await dio.get<dynamic>('/bookings');

      expect(response.statusCode, 200);
      expect(adapter.lastBodyFor('/auth/refresh'), {
        'refreshToken': 'refresh-1',
      });
      expect(tokenWrittenBack, 'fresh-access-only');
      // Blanking the refresh token here would end the session on the next
      // expiry, seven days early.
      expect(refreshTokenWrittenBack, isEmpty);
      expect(sessionExpiredCalls, 0);
    });

    test('a 401 with no stored refresh token ends the session cleanly',
        () async {
      // Devices upgraded from a build that blanked the refresh token are in
      // exactly this state: still "signed in", but nothing to refresh with.
      // Leaving the session in place strands them on "Please sign in again
      // before booking" forever; ending it costs one login and repairs them.
      final strandedDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;
      var strandedExpiries = 0;

      strandedDio.interceptors.add(
        AuthInterceptor(
          readTokens: () async => const StoredTokens(
            accessToken: 'expired',
            refreshToken: '',
          ),
          onTokensRefreshed: (_) async {},
          onSessionExpired: () async => strandedExpiries++,
          refreshDio: strandedDio,
          retryDio: strandedDio,
        ),
      );

      adapter.onPath('/bookings', statuses: [401]);

      await expectLater(
        strandedDio.get<dynamic>('/bookings'),
        throwsA(isA<DioException>()),
      );

      expect(strandedExpiries, 1);
    });

    test('a rejected refresh token ends the session', () async {
      adapter
        ..onPath('/bookings', statuses: [401])
        ..onPath('/auth/refresh', statuses: [401]);

      await expectLater(dio.get<dynamic>('/bookings'), throwsA(isA<DioException>()));

      expect(sessionExpiredCalls, 1);
    });

    test('a network failure during refresh does not sign the user out',
        () async {
      adapter
        ..onPath('/bookings', statuses: [401])
        ..failPath('/auth/refresh', DioExceptionType.connectionError);

      await expectLater(dio.get<dynamic>('/bookings'), throwsA(isA<DioException>()));

      // The session says nothing about a dropped connection; losing it here
      // would throw the user back to the login screen over a flaky network.
      expect(sessionExpiredCalls, 0);
    });
  });
}

/// Minimal adapter that replays a scripted sequence of statuses per path.
class DioAdapterStub implements HttpClientAdapter {
  final _statuses = <String, List<int>>{};
  final _bodies = <String, Map<String, dynamic>>{};
  final _failures = <String, DioExceptionType>{};
  final _authorizations = <String, String?>{};
  final _sentBodies = <String, Object?>{};

  void onPath(
    String path, {
    required List<int> statuses,
    Map<String, dynamic>? body,
  }) {
    _statuses[path] = [...statuses];
    if (body != null) {
      _bodies[path] = body;
    }
  }

  void failPath(String path, DioExceptionType type) {
    _failures[path] = type;
  }

  String? lastAuthorizationFor(String path) => _authorizations[path];

  Object? lastBodyFor(String path) => _sentBodies[path];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    _authorizations[path] = options.headers['Authorization']?.toString();
    _sentBodies[path] = options.data;

    final failure = _failures[path];
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure);
    }

    final queued = _statuses[path];
    final status = (queued == null || queued.isEmpty)
        ? 200
        : (queued.length == 1 ? queued.first : queued.removeAt(0));

    return ResponseBody.fromString(
      jsonEncode(_bodies[path] ?? <String, dynamic>{}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
