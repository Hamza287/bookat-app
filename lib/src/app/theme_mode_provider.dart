import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_providers.dart';

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final value = preferences.getString(_key);
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.light,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, _value(mode));
  }

  String _value(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      _ => 'light',
    };
  }
}
