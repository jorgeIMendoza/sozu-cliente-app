import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/documents/ports/documents_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion de [DocumentsPort] sobre Supabase (edge functions
/// cliente-documentos y cliente-expediente).
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

  @override
  Future<ClienteExpediente> identityFile() async => ClienteExpediente.fromJson(
    await _invoke('cliente-expediente', body: {'action': 'listar'}),
  );

  @override
  Future<ExpedienteUpload> uploadIdentityDocument({
    required int typeId,
    required String fileName,
    required String fileBase64,
    String? contentType,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        'cliente-expediente',
        body: {
          'action': 'subir',
          'tipo_id': typeId,
          'nombre_archivo': fileName,
          'archivo_base64': fileBase64,
          if (contentType != null) 'content_type': contentType,
        },
        headers: _headers,
      );
      final data = res.data;
      if (data is Map) {
        final df = data['datos_fiscales'];
        final dc = data['datos_curp'];
        final da = data['datos_acta'];
        return (
          estatus: (data['estatus'] as String?) ?? 'revision',
          datosFiscales: df is Map
              ? DatosFiscalesCSF.fromJson(Map<String, dynamic>.from(df))
              : null,
          datosCurp: dc is Map
              ? DatosCURP.fromJson(Map<String, dynamic>.from(dc))
              : null,
          datosActa: da is Map
              ? DatosActa.fromJson(Map<String, dynamic>.from(da))
              : null,
        );
      }
      throw ApiError(500, 'empty_response');
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map) {
        final reason = details['reason'];
        if (reason is String && reason.isNotEmpty) {
          throw DocumentoInvalidoError(reason);
        }
        if (details['error'] != null) {
          throw ApiError(e.status, details['error'].toString());
        }
      }
      throw ApiError(e.status, 'internal_error');
    } on ApiError {
      rethrow;
    } on DocumentoInvalidoError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }
}
