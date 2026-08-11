import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/ports/expediente_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion de [ExpedientePort] sobre la edge function
/// `cliente-expediente` (Supabase).
class ExpedienteAdapter implements ExpedientePort {
  /// Cliente que se esta viendo cuando un super admin impersona; null = el propio.
  final int? impersonate;

  const ExpedienteAdapter({this.impersonate});

  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  Map<String, String>? get _headers =>
      impersonate != null ? {'x-impersonate-id-persona': '$impersonate'} : null;

  @override
  Future<ClienteExpediente> identityFile() async {
    try {
      final res = await _sb.functions.invoke(
        'cliente-expediente',
        body: {'action': 'listar'},
        headers: _headers,
      );
      final data = res.data;
      if (data is Map) {
        return ClienteExpediente.fromJson(Map<String, dynamic>.from(data));
      }
      throw ApiError(500, 'empty_response');
    } on FunctionException catch (e) {
      throw _fallo(e);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  @override
  Future<AnalisisDocumento?> analyzeDocument({
    required String slotKey,
    required int typeId,
    required String fileName,
    required String fileBase64,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        'cliente-expediente',
        body: {
          'action': 'analizar',
          'key': slotKey,
          'tipo_id': typeId,
          'nombre_archivo': fileName,
          'archivo_base64': fileBase64,
          'content_type': 'application/pdf',
        },
        headers: _headers,
      );
      final data = res.data;
      if (data is Map && data['resultado'] != null) {
        return AnalisisDocumento.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on FunctionException catch (e) {
      // `unknown_action` = edge function sin la accion todavia. Devolver null
      // manda al llamador al flujo de subida directa en vez de dejar al
      // cliente atorado con un error que no puede resolver.
      final details = e.details;
      if (details is Map && details['error'] == 'unknown_action') return null;
      throw _fallo(e);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  @override
  Future<ExpedienteUpload> uploadDocument({
    required int typeId,
    required String fileName,
    required String fileBase64,
    String? slotKey,
    String? hash,
    Map<String, String>? fields,
    int? docId,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        'cliente-expediente',
        body: {
          'action': 'subir',
          'tipo_id': typeId,
          'nombre_archivo': fileName,
          'archivo_base64': fileBase64,
          'content_type': 'application/pdf',
          if (slotKey != null) 'key': slotKey,
          if (hash != null) 'hash': hash,
          if (fields != null && fields.isNotEmpty) 'campos': fields,
          if (docId != null) 'doc_id': docId,
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
      throw _fallo(e);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  /// Traduce el fallo de la edge function: `reason` es el motivo ya redactado
  /// para el cliente y sube como [DocumentoInvalidoError]; el resto es
  /// [ApiError].
  Object _fallo(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final reason = details['reason'];
      if (reason is String && reason.isNotEmpty) {
        return DocumentoInvalidoError(reason);
      }
      if (details['error'] != null) {
        return ApiError(e.status, details['error'].toString());
      }
    }
    return ApiError(e.status, 'internal_error');
  }
}
