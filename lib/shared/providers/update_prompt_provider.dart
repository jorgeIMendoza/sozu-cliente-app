import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Memoria del aviso de actualización: qué versión se pospuso y qué día.
///
/// Es lo que separa "recordar" de "fastidiar". El aviso era una franja fija en
/// todas las pantallas, sin manera de descartarla: molestaba siempre y aun así
/// no obligaba a nada. Ahora sale una vez y, si el usuario dice "Ahora no", se
/// calla hasta mañana o hasta que haya una versión más nueva.
///
/// `shared_preferences` y no `SecureSessionStorage`: no es dato sensible, y
/// perderlo solo hace que el aviso vuelva a salir una vez.
class UpdatePromptStore {
  UpdatePromptStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kVersion = 'update_prompt_snoozed_version';
  static const _kDay = 'update_prompt_snoozed_day';

  /// `2026-08-17`. Se guarda el DÍA y no un timestamp: "una vez al día" se lee
  /// del calendario del usuario, no de un plazo de 24 h que se corre solo.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// ¿Se muestra el aviso para [latestVersion]?
  ///
  /// Sí cuando la versión pospuesta es OTRA (salió una nueva: vuelve a
  /// preguntar aunque hoy ya dijera que no) o cuando el día cambió.
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

/// Se sobreescribe en `main.dart` con la instancia ya resuelta: leer
/// `SharedPreferences` es asíncrono y el gate no puede esperar sin parpadear.
final updatePromptStoreProvider = Provider<UpdatePromptStore>(
  (ref) => throw UnimplementedError('updatePromptStoreProvider sin override'),
);
