import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Memoria del aviso de actualización: qué versión se pospuso y qué día.
class UpdatePromptStore {
  UpdatePromptStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kVersion = 'update_prompt_snoozed_version';
  static const _kDay = 'update_prompt_snoozed_day';

  /// `2026-08-17`. Es el DIA del calendario y no un timestamp: con un plazo de
  /// 24 h, quien pospone a las 23:00 no vuelve a ver el aviso hasta las 23:00.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Se muestra si la versión pospuesta es otra, o si cambió el día.
  bool shouldPrompt(String latestVersion, {required DateTime today}) {
    final version = _prefs.getString(_kVersion);
    if (version != latestVersion) return true;
    return _prefs.getString(_kDay) != dayKey(today);
  }

  /// "Ahora no": calla el aviso para esta versión y este día.
  Future<void> snooze(String latestVersion, {required DateTime today}) async {
    await _prefs.setString(_kVersion, latestVersion);
    await _prefs.setString(_kDay, dayKey(today));
  }
}

/// Lo sobreescribe `main.dart` con la instancia ya resuelta: resolverla dentro
/// del gate haría parpadear el aviso en el primer frame.
final updatePromptStoreProvider = Provider<UpdatePromptStore>(
  (ref) => throw UnimplementedError('updatePromptStoreProvider sin override'),
);
