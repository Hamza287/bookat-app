import 'package:dio/dio.dart';

import 'api_endpoints.dart';

/// The pair of tokens an [AuthInterceptor] reads from and writes back to
/// storage. Kept generic so this file has no dependency on the auth feature.
class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Refreshes the access token on a 401 and replays the failed request, so a
/// session doesn't die mid-use just because the access token expired.
///
/// Call sites still attach their own `Authorization: Bearer <token>` header
/// per request (see the many data sources under `features/*/data`) — this
/// interceptor does not inject headers on the way out. It only steps in when
/// a request comes back 401, using the stale header on that failed request as
/// its signal, then overwrites it with a freshly refreshed token before
/// replaying.
///
/// [QueuedInterceptor] serializes concurrent 401s (several endpoints commonly
/// fire in parallel, e.g. the admin dashboard), so a burst of expired-token
/// failures triggers exactly one refresh call, not one per request.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Future<StoredTokens?> Function() readTokens,
    required Future<void> Function(StoredTokens tokens) onTokensRefreshed,
    required Future<void> Function() onSessionExpired,
    required Dio refreshDio,
    required Dio retryDio,
  })  : _readTokens = readTokens,
        _onTokensRefreshed = onTokensRefreshed,
        _onSessionExpired = onSessionExpired,
        _refreshDio = refreshDio,
        _retryDio = retryDio;

  final Future<StoredTokens?> Function() _readTokens;
  final Future<void> Function(StoredTokens tokens) _onTokensRefreshed;
  final Future<void> Function() _onSessionExpired;
  final Dio _refreshDio;
  final Dio _retryDio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isAuthEndpoint = request.path.contains('/auth/');
    final alreadyRetried = request.extra['bookatRetried'] == true;

    if (err.response?.statusCode != 401 || isAuthEndpoint || alreadyRetried) {
      handler.next(err);
      return;
    }

    final tokens = await _readTokens();
    if (tokens == null || tokens.refreshToken.isEmpty) {
      handler.next(err);
      return;
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        ApiEndpoints.authRefresh,
        data: {'refreshToken': tokens.refreshToken},
      );

      final refreshed = _parseTokens(response.data);
      if (refreshed == null) {
        throw const FormatException('Invalid refresh token response.');
      }

      await _onTokensRefreshed(refreshed);

      request.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      request.extra = {...request.extra, 'bookatRetried': true};

      final retried = await _retryDio.fetch<dynamic>(request);
      handler.resolve(retried);
    } catch (_) {
      // The refresh token itself is invalid or expired — there is no way to
      // recover this request. Clear the session so the app returns to the
      // login screen instead of looping on 401s.
      await _onSessionExpired();
      handler.next(err);
    }
  }

  StoredTokens? _parseTokens(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final accessToken = _string(payload, ['access_token', 'accessToken']);
    final refreshToken = _string(payload, ['refresh_token', 'refreshToken']);

    if (accessToken.isEmpty) {
      return null;
    }

    return StoredTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  String _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }
}
