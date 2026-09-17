import 'package:flutter/foundation.dart';

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

    try {
      await _apiClient.post(
        ApiEndpoints.notificationToken,
        headers: {'Authorization': 'Bearer $accessToken'},
        data: {
          'token': token,
          'deviceType': _deviceType(),
        },
      );
    } catch (error) {
      debugPrint('Notification token registration failed: $error');
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
