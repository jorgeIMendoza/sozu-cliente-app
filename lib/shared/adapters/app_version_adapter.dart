import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/ports/app_version_port.dart';

/// Implementacion actual de [AppVersionPort] sobre Supabase (edge function
/// `cliente-app-version`): la unica frontera donde se conocen sus tipos.
class AppVersionAdapter implements AppVersionPort {
  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  /// Invoca la edge function y normaliza cualquier fallo a [ApiError]. Va con
  /// la llave anonima cuando no hay sesion: el gate funciona pre-login.
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
  Future<AppVersionInfo> version() async =>
      AppVersionInfo.fromJson(await _invoke('cliente-app-version'));
}
