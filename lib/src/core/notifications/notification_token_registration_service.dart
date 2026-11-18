import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

import '../network/network.dart';

class NotificationTokenRegistrationService {
  const NotificationTokenRegistrationService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> registerToken({
    required String accessToken,
    required String token,
  }) async {
    if (accessToken.isEmpty || token.isEmpty) {
      return;
    }

    final body = {
      'token': token,
      'deviceType': _deviceType(),
    };

    try {
      debugPrint(
        '[FCM] POST ${AppConfig.baseUrl}${ApiEndpoints.notificationToken}\n'
        '[FCM] headers: {Authorization: Bearer ${accessToken.substring(0, 12)}...}\n'
        // Encoded, so this is byte-for-byte what goes over the wire rather
        // than Dart's map formatting.
        '[FCM] body: ${jsonEncode(body)}',
      );

      final response = await _apiClient.post(
        ApiEndpoints.notificationToken,
        headers: {'Authorization': 'Bearer $accessToken'},
        data: body,
      );

      debugPrint(
        '[FCM] <- ${response.statusCode} ${response.data}',
      );
    } on DioException catch (error) {
      debugPrint(
        '[FCM] registration FAILED ${error.response?.statusCode} '
        '${error.response?.data ?? error.message}',
      );
    } catch (error) {
      debugPrint('[FCM] registration failed: $error');
    }
  }

  Future<void> unregisterToken({
    required String accessToken,
    required String token,
  }) async {
    if (accessToken.isEmpty || token.isEmpty) {
      return;
    }

    try {
      await _apiClient.delete(
        ApiEndpoints.notificationTokenByToken(token),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } catch (error) {
      debugPrint('Notification token unregister failed: $error');
    }
  }
}

String _deviceType() {
  if (kIsWeb) {
    return 'web';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'ios',
    _ => 'web',
  };
}
