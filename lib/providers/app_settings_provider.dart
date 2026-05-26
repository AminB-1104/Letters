// ignore_for_file: prefer_initializing_formals
// Reason: keep `storage` as the public named param; the private `_storage`
// field is bound via the initializer list.

import 'package:flutter/material.dart';

import '../core/services/storage_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider({required StorageService storage}) : _storage = storage {
    final stored = _storage.getThemeMode();
    if (stored == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (stored == 'light') {
      _themeMode = ThemeMode.light;
    }
  }

  final StorageService _storage;

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _storage.setThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> toggleTheme() {
    return setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
