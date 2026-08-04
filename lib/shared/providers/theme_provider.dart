import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema claro/oscuro/automático, persistida.
///
/// No es dato sensible: va en `shared_preferences`, no en
/// `SecureSessionStorage` (que es solo para tokens).
class ThemeController extends ChangeNotifier {
  static const _key = 'sozu_theme_pref';

  ThemeMode mode = ThemeMode.system;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = _parse(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    if (m == mode) return;
    mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _serialize(m));
  }

  static ThemeMode _parse(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _serialize(ThemeMode m) => switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final themeProvider = ChangeNotifierProvider<ThemeController>(
  (ref) => ThemeController(),
);
