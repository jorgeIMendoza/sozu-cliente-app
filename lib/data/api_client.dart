import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';

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

/// Info del "version gate" nativo (versión mínima/sugerida + URLs de store).
/// Se invoca con la anon key: funciona pre-login, sin JWT de usuario ni
/// impersonación. Puede lanzar [ApiError]; el provider degrada a "sin gate".
Future<AppVersionInfo> fetchAppVersion() async =>
    AppVersionInfo.fromJson(await _invoke('cliente-app-version'));

Future<ClienteResumen> fetchClienteResumen({int? impersonate}) async =>
    ClienteResumen.fromJson(
      await _invoke('cliente-resumen', impersonate: impersonate),
    );

/// Ítems del menú lateral del portal cliente (submenús activos y permitidos,
/// mismo criterio que el portal web). Si la edge function aún no está
/// desplegada o falla, el provider degrada a la lista hardcodeada.
Future<List<MenuItemDto>> fetchClienteMenu({int? impersonate}) async {
  final res = await _invoke('cliente-menu', impersonate: impersonate);
  return ((res['items'] as List?) ?? [])
      .map((e) => MenuItemDto.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

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

/// Productos adicionales del cliente agrupados por propiedad.
Future<ClienteProductos> fetchClienteProductos({int? impersonate}) async =>
    ClienteProductos.fromJson(
      await _invoke('cliente-productos', impersonate: impersonate),
    );

Future<ClientePerfil> fetchClientePerfil({int? impersonate}) async =>
    ClientePerfil.fromJson(
      await _invoke('cliente-perfil', impersonate: impersonate),
    );

/// Catálogos para editar el perfil (régimen fiscal, uso CFDI y bancos).
Future<PerfilCatalogos> fetchPerfilCatalogos({int? impersonate}) async =>
    PerfilCatalogos.fromJson(
      await _invoke(
        'cliente-perfil',
        body: {'action': 'catalogos'},
        impersonate: impersonate,
      ),
    );

/// Actualiza los datos personales del cliente (nombre, RFC, CURP, teléfono).
Future<void> updatePerfilPersonal({
  required String nombreLegal,
  String? rfc,
  String? curp,
  String? clavePaisTelefono,
  String? telefono,
  String? ocupacion,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-perfil',
    body: {
      'action': 'update_personal',
      'nombre_legal': nombreLegal,
      'rfc': rfc,
      'curp': curp,
      'clave_pais_telefono': clavePaisTelefono,
      'telefono': telefono,
      'ocupacion': ocupacion,
    },
    impersonate: impersonate,
  );
}

/// Actualiza los datos fiscales (régimen, uso CFDI y dirección fiscal).
Future<void> updatePerfilFiscal({
  String? regimen,
  String? usoCfdi,
  String? codigoPostal,
  String? calle,
  String? numExt,
  String? numInt,
  String? colonia,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-perfil',
    body: {
      'action': 'update_fiscal',
      'regimen': regimen,
      'uso_cfdi': usoCfdi,
      'codigo_postal': codigoPostal,
      'calle': calle,
      'num_ext': numExt,
      'num_int': numInt,
      'colonia': colonia,
    },
    impersonate: impersonate,
  );
}

Map<String, dynamic> _cuentaBody({
  required String action,
  int? id,
  required int idBanco,
  required String numeroCuenta,
  String? cuentaClabe,
  String? cuentaSwift,
  required String titular,
  String? evidenciaBase64,
  String? evidenciaNombre,
  String? evidenciaContentType,
}) => {
  'action': action,
  if (id != null) 'id': id,
  'id_banco': idBanco,
  'numero_cuenta': numeroCuenta,
  if (cuentaClabe != null && cuentaClabe.isNotEmpty)
    'cuenta_clabe': cuentaClabe,
  if (cuentaSwift != null && cuentaSwift.isNotEmpty)
    'cuenta_swift': cuentaSwift,
  'titular': titular,
  if (evidenciaBase64 != null) 'evidencia_base64': evidenciaBase64,
  if (evidenciaNombre != null) 'evidencia_nombre': evidenciaNombre,
  if (evidenciaContentType != null)
    'evidencia_content_type': evidenciaContentType,
};

/// Alta de cuenta bancaria de dispersión. `numeroCuenta` (8-34) es la clave;
/// CLABE/SWIFT son opcionales. `evidencia*` = carátula del estado de cuenta.
Future<void> addCuentaBancaria({
  required int idBanco,
  required String numeroCuenta,
  String? cuentaClabe,
  String? cuentaSwift,
  required String titular,
  String? evidenciaBase64,
  String? evidenciaNombre,
  String? evidenciaContentType,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-perfil',
    body: _cuentaBody(
      action: 'cuenta_add',
      idBanco: idBanco,
      numeroCuenta: numeroCuenta,
      cuentaClabe: cuentaClabe,
      cuentaSwift: cuentaSwift,
      titular: titular,
      evidenciaBase64: evidenciaBase64,
      evidenciaNombre: evidenciaNombre,
      evidenciaContentType: evidenciaContentType,
    ),
    impersonate: impersonate,
  );
}

/// Edición de una cuenta bancaria propia.
Future<void> updateCuentaBancaria({
  required int id,
  required int idBanco,
  required String numeroCuenta,
  String? cuentaClabe,
  String? cuentaSwift,
  required String titular,
  String? evidenciaBase64,
  String? evidenciaNombre,
  String? evidenciaContentType,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-perfil',
    body: _cuentaBody(
      action: 'cuenta_update',
      id: id,
      idBanco: idBanco,
      numeroCuenta: numeroCuenta,
      cuentaClabe: cuentaClabe,
      cuentaSwift: cuentaSwift,
      titular: titular,
      evidenciaBase64: evidenciaBase64,
      evidenciaNombre: evidenciaNombre,
      evidenciaContentType: evidenciaContentType,
    ),
    impersonate: impersonate,
  );
}

/// Agrega un banco al catálogo (dedup en el backend). Devuelve id + nombre.
Future<({int id, String nombre})> agregarBancoCatalogo(
  String nombre, {
  int? impersonate,
}) async {
  final res = await _invoke(
    'cliente-perfil',
    body: {'action': 'banco_add', 'nombre': nombre},
    impersonate: impersonate,
  );
  return (id: asInt(res['id']), nombre: asString(res['nombre'], nombre));
}

/// Sube la foto de perfil (avatar) del cliente. `base64` es el contenido de la
/// imagen y `mime` su tipo (p.ej. image/jpeg). Devuelve la URL firmada de la
/// foto resultante, o null si el backend no la regresa.
Future<String?> avatarUpload({
  required String base64,
  required String mime,
  int? impersonate,
}) async {
  final res = await _invoke(
    'cliente-perfil',
    body: {'action': 'avatar_upload', 'base64': base64, 'mime': mime},
    impersonate: impersonate,
  );
  final url = res['foto_perfil_url'];
  return url is String && url.isNotEmpty ? url : null;
}

/// Elimina la foto de perfil (avatar) del cliente.
Future<void> avatarDelete({int? impersonate}) async {
  await _invoke(
    'cliente-perfil',
    body: {'action': 'avatar_delete'},
    impersonate: impersonate,
  );
}

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

/// Marca una notificación como NO leída (revertir el "leído").
Future<void> notifMarcarNoLeida(int id, {int? impersonate}) async {
  await _invoke(
    'cliente-notificaciones',
    body: {'action': 'marcar_no_leida', 'id': id},
    impersonate: impersonate,
  );
}

Future<EstadoCuenta> fetchEstadoCuenta(
  int idCuenta, {
  int? impersonate,
}) async => EstadoCuenta.fromJson(
  await _invoke(
    'cliente-estado-cuenta',
    body: {'id': idCuenta},
    impersonate: impersonate,
  ),
);

/// Datos para pagar un acuerdo (CLABE/beneficiario/concepto/monto/vencimiento).
Future<DatosPago> fetchDatosPago(int idAcuerdo, {int? impersonate}) async =>
    DatosPago.fromJson(
      await _invoke(
        'cliente-datos-pago',
        body: {'id': idAcuerdo},
        impersonate: impersonate,
      ),
    );

/// URL del recibo de un pago; el backend lo genera si aún no existe.
Future<String?> fetchReciboPagoUrl(int idPago, {int? impersonate}) async {
  final res = await _invoke(
    'cliente-recibo-pago',
    body: {'id': idPago},
    impersonate: impersonate,
  );
  final url = res['url'];
  return url is String && url.isNotEmpty ? url : null;
}

/// URL temporal del PDF del estado de cuenta de una propiedad (wrapper seguro).
Future<String?> fetchEstadoCuentaPdfUrl(
  int idCuenta, {
  int? impersonate,
}) async {
  final res = await _invoke(
    'cliente-estado-cuenta-pdf',
    body: {'id': idCuenta},
    impersonate: impersonate,
  );
  final url = res['url'];
  return url is String && url.isNotEmpty ? url : null;
}

/// Bancos con convenio para crédito hipotecario (catálogo dinámico).
Future<List<BancoConvenio>> fetchBancosConvenio({int? impersonate}) async {
  final res = await _invoke(
    'cliente-pago-final',
    body: {'action': 'bancos'},
    impersonate: impersonate,
  );
  return ((res['bancos'] as List?) ?? [])
      .map((e) => BancoConvenio.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Crea la solicitud de crédito hipotecario (precalificación).
Future<SolicitudCredito?> crearSolicitudCredito({
  required int idCuenta,
  required int idBanco,
  double? montoCredito,
  int? plazoMeses,
  int? impersonate,
}) async {
  final res = await _invoke(
    'cliente-pago-final',
    body: {
      'action': 'crear_solicitud',
      'id': idCuenta,
      'id_banco': idBanco,
      if (montoCredito != null) 'monto_credito': montoCredito,
      if (plazoMeses != null) 'plazo_meses': plazoMeses,
    },
    impersonate: impersonate,
  );
  return res['solicitud'] is Map
      ? SolicitudCredito.fromJson(
          Map<String, dynamic>.from(res['solicitud'] as Map),
        )
      : null;
}

/// Guarda la decisión de pago final de una cuenta (flujo "Pago final").
/// metodo: RECURSOS_PROPIOS | CREDITO_HIPOTECARIO. idBanco: 1 BBVA, 2
/// Santander, 3 Banorte (solo crédito con banco preferente).
Future<void> setPagoFinal(
  int idCuenta,
  String metodo, {
  int? idBanco,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-pago-final',
    body: {
      'id': idCuenta,
      'metodo': metodo,
      if (idBanco != null) 'id_banco': idBanco,
    },
    impersonate: impersonate,
  );
}

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

// ─── cliente-expediente ──────────────────────────────────────────────────────

/// El documento subido no pasó la validación del backend (razón en español,
/// lista para mostrar al usuario).
class DocumentoInvalidoError implements Exception {
  final String reason;
  DocumentoInvalidoError(this.reason);

  @override
  String toString() => 'DocumentoInvalidoError($reason)';
}

/// Expediente de identidad del cliente (slots con estatus del portal).
Future<ClienteExpediente> fetchClienteExpediente({int? impersonate}) async =>
    ClienteExpediente.fromJson(
      await _invoke(
        'cliente-expediente',
        body: {'action': 'listar'},
        impersonate: impersonate,
      ),
    );

/// Sube un documento del expediente. El backend valida el PDF (CURP/CSF/
/// domicilio/actas), lo guarda en Storage y registra el documento. Devuelve el
/// estatus resultante ('aprobado' | 'revision') y los datos detectados para
/// confirmar en el perfil: `datosFiscales` (CSF tipo 6), `datosCurp` (CURP tipo
/// 5) o `datosActa` (Acta tipo 1) - solo uno viene poblado. Lanza
/// [DocumentoInvalidoError] si el archivo no pasa la validación.
Future<
  ({
    String estatus,
    DatosFiscalesCSF? datosFiscales,
    DatosCURP? datosCurp,
    DatosActa? datosActa,
  })
>
subirDocumentoExpediente({
  required int tipoId,
  required String nombreArchivo,
  required String archivoBase64,
  String? contentType,
  int? impersonate,
}) async {
  try {
    final res = await _sb.functions.invoke(
      'cliente-expediente',
      body: {
        'action': 'subir',
        'tipo_id': tipoId,
        'nombre_archivo': nombreArchivo,
        'archivo_base64': archivoBase64,
        if (contentType != null) 'content_type': contentType,
      },
      headers: impersonate != null
          ? {'x-impersonate-id-persona': '$impersonate'}
          : null,
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
