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

/// Alta de cuenta bancaria de dispersión (CLABE de 18 dígitos).
Future<void> addCuentaBancaria({
  required int idBanco,
  required String cuentaClabe,
  required String titular,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-perfil',
    body: {
      'action': 'cuenta_add',
      'id_banco': idBanco,
      'cuenta_clabe': cuentaClabe,
      'titular': titular,
    },
    impersonate: impersonate,
  );
}

/// Edición de una cuenta bancaria propia.
Future<void> updateCuentaBancaria({
  required int id,
  required int idBanco,
  required String cuentaClabe,
  required String titular,
  int? impersonate,
}) async {
  await _invoke(
    'cliente-perfil',
    body: {
      'action': 'cuenta_update',
      'id': id,
      'id_banco': idBanco,
      'cuenta_clabe': cuentaClabe,
      'titular': titular,
    },
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

/// Lista de clientes para el selector de impersonación (solo super admin).
Future<AdminClientes> fetchAdminClientes() async =>
    AdminClientes.fromJson(await _invoke('admin-clientes'));

/// Dueños/copropietarios de una unidad (proyecto + número de propiedad) para
/// el filtro "Ver como" del selector de impersonación. Requiere la versión de
/// admin-clientes con action=propietarios; con la versión previa el backend
/// regresa {clientes} y esto devuelve lista vacía (degrada sin romperse).
Future<List<AdminCliente>> fetchAdminPropietarios({
  required int idProyecto,
  required String numeroPropiedad,
}) async {
  final res = await _invoke(
    'admin-clientes',
    body: {
      'action': 'propietarios',
      'id_proyecto': idProyecto,
      'numero_propiedad': numeroPropiedad,
    },
  );
  return ((res['propietarios'] as List?) ?? [])
      .map((e) => AdminCliente.fromJson(Map<String, dynamic>.from(e)))
      .toList();
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

// ─── admin-avisos-app (solo super admin) ─────────────────────────────────────

List<CatalogoItem> _parseCatalogo(Map<String, dynamic> res, String key) =>
    ((res[key] as List?) ?? [])
        .map((e) => CatalogoItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

/// Proyectos activos comercializados por SOZU (para el filtro de avisos).
Future<List<CatalogoItem>> fetchAvisosProyectos() async {
  final res = await _invoke('admin-avisos-app', body: {'action': 'catalogos'});
  return _parseCatalogo(res, 'proyectos');
}

/// Modelos disponibles dentro de los proyectos seleccionados.
Future<List<CatalogoItem>> fetchAvisosModelos(List<int> idsProyectos) async {
  final res = await _invoke(
    'admin-avisos-app',
    body: {'action': 'modelos', 'ids_proyectos': idsProyectos},
  );
  return _parseCatalogo(res, 'modelos');
}

/// Niveles (numero_piso) existentes en los proyectos/modelos seleccionados.
Future<List<CatalogoItem>> fetchAvisosNiveles(
  List<int> idsProyectos, {
  List<int> idsModelos = const [],
}) async {
  final res = await _invoke(
    'admin-avisos-app',
    body: {
      'action': 'niveles',
      'ids_proyectos': idsProyectos,
      if (idsModelos.isNotEmpty) 'ids_modelos': idsModelos,
    },
  );
  return _parseCatalogo(res, 'niveles');
}

/// Propiedades de los proyectos seleccionados, acotadas a modelos/niveles.
Future<List<CatalogoItem>> fetchAvisosPropiedades(
  List<int> idsProyectos, {
  List<int> idsModelos = const [],
  List<int> idsNiveles = const [],
}) async {
  final res = await _invoke(
    'admin-avisos-app',
    body: {
      'action': 'propiedades',
      'ids_proyectos': idsProyectos,
      if (idsModelos.isNotEmpty) 'ids_modelos': idsModelos,
      if (idsNiveles.isNotEmpty) 'ids_niveles': idsNiveles,
    },
  );
  return _parseCatalogo(res, 'propiedades');
}

Future<List<AvisoApp>> fetchAvisosApp() async {
  final res = await _invoke('admin-avisos-app', body: {'action': 'listar'});
  return ((res['avisos'] as List?) ?? [])
      .map((e) => AvisoApp.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<AvisoApp> crearAvisoApp({
  required String titulo,
  required String mensaje,
  required String tipo,
  required String categoria,
  required List<String> canales,
  List<int> idsProyectos = const [],
  List<int> idsModelos = const [],
  List<int> idsNiveles = const [],
  List<int> idsPropiedades = const [],
  DateTime? programadoPara,
}) async {
  final res = await _invoke(
    'admin-avisos-app',
    body: {
      'action': 'crear',
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'categoria': categoria,
      'canales': canales,
      if (idsProyectos.isNotEmpty) 'ids_proyectos': idsProyectos,
      if (idsModelos.isNotEmpty) 'ids_modelos': idsModelos,
      if (idsNiveles.isNotEmpty) 'ids_niveles': idsNiveles,
      if (idsPropiedades.isNotEmpty) 'ids_propiedades': idsPropiedades,
      if (programadoPara != null)
        'programado_para': programadoPara.toUtc().toIso8601String(),
    },
  );
  return AvisoApp.fromJson(Map<String, dynamic>.from(res['aviso'] as Map));
}

/// Animación de llegada de notificaciones configurada (sobre | gol | cohete).
Future<String> fetchAnimacionCampana() async {
  final res = await _invoke('admin-avisos-app', body: {'action': 'config_get'});
  return (res['animacion_campana'] as String?) ?? 'gol';
}

Future<void> setAnimacionCampana(String animacion) async {
  await _invoke(
    'admin-avisos-app',
    body: {'action': 'config_set', 'animacion_campana': animacion},
  );
}

Future<bool> cancelarAvisoApp(int id) async {
  final res = await _invoke(
    'admin-avisos-app',
    body: {'action': 'cancelar', 'id': id},
  );
  return res['cancelado'] == true;
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
/// domicilio/actas), lo guarda en Storage y registra el documento. Devuelve
/// el estatus resultante: 'aprobado' | 'revision'. Lanza
/// [DocumentoInvalidoError] si el archivo no pasa la validación.
Future<String> subirDocumentoExpediente({
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
    if (data is Map) return (data['estatus'] as String?) ?? 'revision';
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
