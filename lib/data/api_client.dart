import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';

/// Resto transversal de la capa de acceso a datos: push y version gate.
/// Los datos del cliente viven en los adaptadores de
/// `features/client/<hoja>/adapters/` (tanda hexagonal); push y version
/// migraran a los puertos de `shared/ports/` en una tanda posterior.

class ApiError implements Exception {
  final int status;
  final String code;
  ApiError(this.status, this.code);

  @override
  String toString() => 'ApiError($status, $code)';
}

SupabaseClient get _sb => Supabase.instance.client;

Future<Map<String, dynamic>> _invoke(
  String fn, {
  Map<String, dynamic>? body,
}) async {
  try {
    final res = await _sb.functions.invoke(fn, body: body ?? {});
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiError(500, 'empty_response');
  } on FunctionException catch (e) {
    var code = 'internal_error';
    final details = e.details;
    if (details is Map && details['error'] != null) {
      code = details['error'].toString();
    }
    throw ApiError(e.status, code);
  } on ApiError {
    rethrow;
  } catch (_) {
    throw ApiError(0, 'network_error');
  }
}

/// Info del "version gate" nativo (versión mínima/sugerida + URLs de store).
/// Se invoca con la anon key: funciona pre-login, sin JWT de usuario ni
/// impersonación. Puede lanzar [ApiError]; el provider degrada a "sin gate".
Future<AppVersionInfo> fetchAppVersion() async =>
    AppVersionInfo.fromJson(await _invoke('cliente-app-version'));

/// Registra el token FCM del dispositivo para recibir push (solo móvil).
Future<void> registrarPushToken(String token, String plataforma) async {
  await _invoke(
    'cliente-push-token',
    body: {'action': 'register', 'token': token, 'plataforma': plataforma},
  );
}

/// Da de baja el token FCM (al cerrar sesión). Best-effort.
Future<void> eliminarPushToken(String token) async {
  await _invoke(
    'cliente-push-token',
    body: {'action': 'unregister', 'token': token},
  );
}

/// Preferencia de push del cliente (sin fila en BD = true).
Future<bool> fetchPushPref() async {
  final res = await _invoke('cliente-push-token', body: {'action': 'pref_get'});
  return (res['push_activo'] as bool?) ?? true;
}

/// Activa/desactiva los push. No da de baja tokens: el dispatch filtra por
/// esta preferencia, así reactivar es instantáneo.
Future<void> setPushPref(bool activo) async {
  await _invoke(
    'cliente-push-token',
    body: {'action': 'pref_set', 'push_activo': activo},
  );
}
