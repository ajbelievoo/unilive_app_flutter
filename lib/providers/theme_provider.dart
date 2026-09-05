import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app theme mode (light/dark/system) with persistence.
///
/// Ported from native `SettingActivity` dark mode toggle.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  static const String _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key) ?? 'light';
      _mode = _parseMode(stored);
    } catch (_) {
      _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _mode.name);
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  ThemeMode _parseMode(String s) {
    return switch (s) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }
}
