import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Capa de acceso a datos: SOLO Edge Functions (espejo de src/lib/api.ts).
/// La app nunca consulta tablas. Cada invoke envía el JWT del usuario.

class ApiError implements Exception {
  final int status;
  final String code;
  ApiError(this.status, this.code);

  @override
  String toString() => 'ApiError($status, $code)';
}

/// true si el error indica que el usuario NO es un cliente SOZU.
bool isNotClientError(Object e) =>
    e is ApiError &&
    e.status == 403 &&
    (e.code == 'forbidden_role' || e.code == 'no_persona');

SupabaseClient get _sb => Supabase.instance.client;

Future<Map<String, dynamic>> _invoke(
  String fn, {
  Map<String, dynamic>? body,
  int? impersonate,
}) async {
  try {
    final res = await _sb.functions.invoke(
      fn,
      body: body ?? {},
      headers: impersonate != null
          ? {'x-impersonate-id-persona': '$impersonate'}
          : null,
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

Future<ClienteResumen> fetchClienteResumen({int? impersonate}) async =>
    ClienteResumen.fromJson(
      await _invoke('cliente-resumen', impersonate: impersonate),
    );

Future<ClientePagos> fetchClientePagos({int? impersonate}) async =>
    ClientePagos.fromJson(
      await _invoke('cliente-pagos', impersonate: impersonate),
    );

Future<ClientePropiedades> fetchClientePropiedades({int? impersonate}) async =>
    ClientePropiedades.fromJson(
      await _invoke('cliente-propiedades', impersonate: impersonate),
    );

Future<PropiedadDetalle> fetchPropiedadDetalle(
  int id, {
  int? impersonate,
}) async => PropiedadDetalle.fromJson(
  await _invoke(
    'cliente-propiedad-detalle',
    body: {'id': id},
    impersonate: impersonate,
  ),
);

Future<ClientePerfil> fetchClientePerfil({int? impersonate}) async =>
    ClientePerfil.fromJson(
      await _invoke('cliente-perfil', impersonate: impersonate),
    );

Future<ClienteDocumentos> fetchClienteDocumentos({int? impersonate}) async =>
    ClienteDocumentos.fromJson(
      await _invoke('cliente-documentos', impersonate: impersonate),
    );

Future<ClienteNotificaciones> fetchClienteNotificaciones({
  String? action,
  int? id,
  int? impersonate,
}) async => ClienteNotificaciones.fromJson(
  await _invoke(
    'cliente-notificaciones',
    body: action != null ? {'action': action, if (id != null) 'id': id} : {},
    impersonate: impersonate,
  ),
);

/// Lista de clientes para el selector de impersonación (solo super admin).
Future<AdminClientes> fetchAdminClientes() async =>
    AdminClientes.fromJson(await _invoke('admin-clientes'));
