import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/ports/push_port.dart';

/// Implementacion actual de [PushPort] sobre Supabase (edge function
/// `cliente-push-token`): la unica frontera donde se conocen sus tipos.
class PushAdapter implements PushPort {
  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  /// Invoca la edge function con el JWT del usuario y normaliza cualquier fallo
  /// a [ApiError]. Sin cabecera de impersonacion: el token es del dispositivo.
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

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    await _invoke(
      'cliente-push-token',
      body: {'action': 'register', 'token': token, 'plataforma': platform},
    );
  }

  @override
  Future<void> unregisterToken(String token) async {
    await _invoke(
      'cliente-push-token',
      body: {'action': 'unregister', 'token': token},
    );
  }

  /// Sin fila en BD el backend no manda `push_activo`: se asume activo.
  @override
  Future<bool> enabled() async {
    final res = await _invoke(
      'cliente-push-token',
      body: {'action': 'pref_get'},
    );
    return (res['push_activo'] as bool?) ?? true;
  }

  @override
  Future<void> setEnabled(bool value) async {
    await _invoke(
      'cliente-push-token',
      body: {'action': 'pref_set', 'push_activo': value},
    );
  }
}
