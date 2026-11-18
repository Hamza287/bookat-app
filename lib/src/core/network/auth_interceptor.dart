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

  /// Key under which a replayable copy of an outgoing [FormData] body is kept.
  static const _formDataCopyKey = 'bookatFormDataCopy';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // A FormData body is a single-use stream: once the request has been sent it
    // cannot be replayed, so a 401 on an image upload would fail even though
    // the refresh succeeded. Stash a clone now, while the body is still intact.
    final data = options.data;
    if (data is FormData && options.extra[_formDataCopyKey] == null) {
      options.extra = {...options.extra, _formDataCopyKey: data.clone()};
    }

    handler.next(options);
  }

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
      // A 401 with no refresh token to fall back on cannot be recovered, so the
      // session is finished — end it and let the app return to sign-in.
      //
      // Without this the user is stranded: an earlier build blanked the stored
      // refresh token (this API returns only `access_token` on refresh, and the
      // empty value was written straight back), leaving devices that still look
      // signed in but fail every authenticated call with "Please sign in again
      // before booking". Signing out turns that dead end into one clean login.
      await _onSessionExpired();
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

      // Swap in the untouched copy; the original stream was consumed by the
      // attempt that just failed.
      final formDataCopy = request.extra[_formDataCopyKey];
      if (formDataCopy is FormData) {
        request.data = formDataCopy;
      }

      final retried = await _retryDio.fetch<dynamic>(request);
      handler.resolve(retried);
    } on DioException catch (error) {
      // Only give up the session when the server actually rejected the refresh
      // token. A timeout or a dropped connection says nothing about whether the
      // session is still valid, and signing the user out over a flaky network
      // would lose their place for no reason.
      if (_isRejected(error)) {
        await _onSessionExpired();
      }
      handler.next(err);
    } catch (_) {
      // A malformed refresh response is a server-side problem, not proof that
      // this session is finished, so the session is left alone.
      handler.next(err);
    }
  }

  /// True when the refresh call came back with an authentication failure, as
  /// opposed to never reaching the server.
  bool _isRejected(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
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
