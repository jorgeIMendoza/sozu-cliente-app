import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/facturacion/ports/documents_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion de [DocumentsPort] sobre la edge function
/// `cliente-documentos` (Supabase).
class DocumentsAdapter implements DocumentsPort {
  /// Cliente que se esta viendo cuando un super admin impersona; null = el propio.
  final int? impersonate;

  const DocumentsAdapter({this.impersonate});

  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  Map<String, String>? get _headers =>
      impersonate != null ? {'x-impersonate-id-persona': '$impersonate'} : null;

  /// Invoca una edge function con el JWT del usuario (y la cabecera de
  /// impersonacion si aplica) y normaliza cualquier fallo a [ApiError].
  Future<Map<String, dynamic>> _invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        fn,
        body: body ?? {},
        headers: _headers,
      );
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
  Future<ClienteDocumentos> documents() async =>
      ClienteDocumentos.fromJson(await _invoke('cliente-documentos'));
}
