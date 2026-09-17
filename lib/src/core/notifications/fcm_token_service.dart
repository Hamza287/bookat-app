import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmTokenService {
  const FcmTokenService(this._messaging);

  final FirebaseMessaging _messaging;

  Future<String?> getDeviceToken() async {
    await _requestPermission();

    if (_needsApnsToken) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) {
        return null;
      }
    }

    try {
      return _messaging.getToken();
    } on FirebaseException catch (error) {
      debugPrint('FCM token unavailable: ${error.message}');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Revokes the device token at Firebase. This is a network round trip with
  /// no built-in timeout, so it is bounded here — a hung delete must never
  /// stall the caller.
  Future<void> deleteDeviceToken() async {
    try {
      await _messaging.deleteToken().timeout(_deleteTimeout);
    } on TimeoutException {
      debugPrint('FCM token delete timed out.');
    } on FirebaseException catch (error) {
      debugPrint('FCM token delete failed: ${error.message}');
    }
  }

  static const _deleteTimeout = Duration(seconds: 5);

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  bool get _needsApnsToken {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    return null;
  }
}
