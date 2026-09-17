import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session_model.dart';
import 'auth_local_data_source.dart';

class SharedPreferencesAuthLocalDataSource implements AuthLocalDataSource {
  const SharedPreferencesAuthLocalDataSource(this._preferences);

  static const _sessionKey = 'auth_session';

  final SharedPreferences _preferences;

  @override
  Future<AuthSessionModel?> readSession() async {
    final value = _preferences.getString(_sessionKey);
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }

      return AuthSessionModel.fromJson(decoded);
    } on FormatException {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    await _preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearSession() async {
    await _preferences.remove(_sessionKey);
  }
}
