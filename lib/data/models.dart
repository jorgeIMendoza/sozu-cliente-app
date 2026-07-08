/// DTOs de las Edge Functions SOZU (espejo de src/lib/api.ts del app RN).
/// Parsers tolerantes: numeric de Postgres puede llegar como String.
library;

double asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String asString(Object? v, [String fallback = '']) => v?.toString() ?? fallback;

// ─── cliente-resumen ─────────────────────────────────────────────────────────

class ActividadItem {
  final int cuentaId;
  final String propiedad;
  final String tipo;
  final String categoria; // adquisicion | patrimonio
  final double monto;
  final String? fecha;
  final String accion;
  final String urgencia;

  ActividadItem.fromJson(Map<String, dynamic> j)
    : cuentaId = asInt(j['cuenta_id']),
      propiedad = asString(j['propiedad'], '—'),
      tipo = asString(j['tipo']),
      categoria = asString(j['categoria'], 'adquisicion'),
      monto = asDouble(j['monto']),
      fecha = j['fecha'] as String?,
      accion = asString(j['accion'], 'ver'),
      urgencia = asString(j['urgencia'], 'future');
}

class PendientePropiedad {
  final int cuentaId;
  final String proyecto;
  final String unidad;
  final String tipo;
  final String? fecha;
  final double monto;
  final String urgencia;

  PendientePropiedad.fromJson(Map<String, dynamic> j)
    : cuentaId = asInt(j['cuenta_id']),
      proyecto = asString(j['proyecto'], '—'),
      unidad = asString(j['unidad'], '—'),
      tipo = asString(j['tipo']),
      fecha = j['fecha'] as String?,
      monto = asDouble(j['monto']),
      urgencia = asString(j['urgencia'], 'future');
}

class ResumenFinanciero {
  final double patrimonioTotal;
  final double invertidoTotal;
  final double plusvaliaGenerada;
  final double plusvaliaPorcentaje;
  final double pagadoTotal;
  final double porcentajePagado;
  final double saldoPendiente;
  final int propiedadesActivas;
  final double activoValor;
  final int activoUnidades;
  final double adquisicionValor;
  final int adquisicionUnidades;

  ResumenFinanciero.fromJson(Map<String, dynamic> j)
    : patrimonioTotal = asDouble(j['patrimonio_total']),
      invertidoTotal = asDouble(j['invertido_total']),
      plusvaliaGenerada = asDouble(j['plusvalia_generada']),
      plusvaliaPorcentaje = asDouble(j['plusvalia_porcentaje']),
      pagadoTotal = asDouble(j['pagado_total']),
      porcentajePagado = asDouble(j['porcentaje_pagado']),
      saldoPendiente = asDouble(j['saldo_pendiente']),
      propiedadesActivas = asInt(j['propiedades_activas']),
      activoValor = asDouble(j['activo_valor']),
      activoUnidades = asInt(j['activo_unidades']),
      adquisicionValor = asDouble(j['adquisicion_valor']),
      adquisicionUnidades = asInt(j['adquisicion_unidades']);
}

class ClienteResumen {
  final String nombreLegal;
  final String iniciales;
  final String tipoCliente;
  final ResumenFinanciero resumen;
  final List<ActividadItem> actividad;
  final List<PendientePropiedad> pendientesPorPropiedad;

  ClienteResumen.fromJson(Map<String, dynamic> j)
    : nombreLegal = asString(
        (j['cliente'] as Map?)?['nombre_legal'],
        'Cliente',
      ),
      iniciales = asString((j['cliente'] as Map?)?['iniciales'], '?'),
      tipoCliente = asString((j['cliente'] as Map?)?['tipo'], 'Inversionista'),
      resumen = ResumenFinanciero.fromJson(
        Map<String, dynamic>.from(j['resumen'] as Map),
      ),
      actividad = ((j['actividad'] as List?) ?? [])
          .map((e) => ActividadItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pendientesPorPropiedad = ((j['pendientes_por_propiedad'] as List?) ?? [])
          .map((e) => PendientePropiedad.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

// ─── cliente-pagos ───────────────────────────────────────────────────────────

class ProximoPago {
  final int id;
  final String concepto;
  final String propiedad;
  final String? fechaPago;
  final double monto;
  final bool vencido;

  ProximoPago.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      propiedad = asString(j['propiedad'], '—'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      vencido = j['vencido'] == true;
}

class HistorialPago {
  final int id;
  final String concepto;
  final String propiedad;
  final String? fechaPago;
  final double monto;
  final String metodo;
  final String? urlRecibo;
  final String? urlCep;

  HistorialPago.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      propiedad = asString(j['propiedad'], '—'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      metodo = asString(j['metodo'], '—'),
      urlRecibo = j['url_recibo'] as String?,
      urlCep = j['url_cep'] as String?;
}

class ClientePagos {
  final double saldoTotal;
  final double saldoPagado;
  final double saldoPendiente;
  final List<ProximoPago> proximosPagos;
  final List<HistorialPago> historial;

  ClientePagos.fromJson(Map<String, dynamic> j)
    : saldoTotal = asDouble((j['saldo'] as Map?)?['total']),
      saldoPagado = asDouble((j['saldo'] as Map?)?['pagado']),
      saldoPendiente = asDouble((j['saldo'] as Map?)?['pendiente']),
      proximosPagos = ((j['proximos_pagos'] as List?) ?? [])
          .map((e) => ProximoPago.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      historial = ((j['historial'] as List?) ?? [])
          .map((e) => HistorialPago.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

// ─── cliente-propiedades ─────────────────────────────────────────────────────

class PropiedadCard {
  final int id;
  final String nombre;
  final String proyecto;
  final String modelo;
  final double monto;
  final double avancePago;
  final String estatus;
  final String? urlImagen;

  PropiedadCard.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '—'),
      proyecto = asString(j['proyecto'], '—'),
      modelo = asString(j['modelo'], '—'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      estatus = asString(j['estatus'], '—'),
      urlImagen = j['url_imagen'] as String?;
}

class ProductoCard {
  final int id;
  final String nombre;
  final String propiedad;
  final double monto;
  final double avancePago;
  final String estatus;

  ProductoCard.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], 'Producto adicional'),
      propiedad = asString(j['propiedad'], '—'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      estatus = asString(j['estatus'], '—');
}

class MantenimientoCard {
  final int id;
  final String propiedad;
  final double saldoPendiente;
  final String? proximoPago;

  MantenimientoCard.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      propiedad = asString(j['propiedad'], '—'),
      saldoPendiente = asDouble(j['saldo_pendiente']),
      proximoPago = j['proximo_pago'] as String?;
}

class ClientePropiedades {
  final List<PropiedadCard> enAdquisicion;
  final List<PropiedadCard> patrimonioActivo;
  final List<ProductoCard> productos;
  final List<MantenimientoCard> mantenimiento;
  final double totalAdquisicion;
  final double totalActivo;
  final double totalProductos;

  ClientePropiedades.fromJson(Map<String, dynamic> j)
    : enAdquisicion = ((j['en_adquisicion'] as List?) ?? [])
          .map((e) => PropiedadCard.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      patrimonioActivo = ((j['patrimonio_activo'] as List?) ?? [])
          .map((e) => PropiedadCard.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      productos = ((j['productos'] as List?) ?? [])
          .map((e) => ProductoCard.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      mantenimiento = ((j['mantenimiento'] as List?) ?? [])
          .map((e) => MantenimientoCard.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalAdquisicion = asDouble((j['totales'] as Map?)?['en_adquisicion']),
      totalActivo = asDouble((j['totales'] as Map?)?['activo']),
      totalProductos = asDouble((j['totales'] as Map?)?['productos']);
}

// ─── cliente-propiedad-detalle ───────────────────────────────────────────────

class EtapaStage {
  final String id;
  final String label;
  final String status; // completed | active | pending

  EtapaStage.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      label = asString(j['label']),
      status = asString(j['status'], 'pending');
}

class EsquemaPagoItem {
  final int id;
  final String concepto;
  final String? fechaPago;
  final double monto;
  final double pagado;
  final double saldo;
  final bool pagoCompletado;

  EsquemaPagoItem.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      saldo = asDouble(j['saldo']),
      pagoCompletado = j['pago_completado'] == true;
}

class ProductoDetalle {
  final int id;
  final String nombre;
  final String estatus;
  final double monto;
  final double avance;

  ProductoDetalle.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], 'Producto adicional'),
      estatus = asString(j['estatus'], 'Pendiente'),
      monto = asDouble(j['monto']),
      avance = asDouble(j['avance']);
}

class RegionNivel {
  final String unitNumber;
  final List<List<double>> polygon;

  RegionNivel.fromJson(Map<String, dynamic> j)
    : unitNumber = asString(j['unit_number']),
      polygon = ((j['polygon'] as List?) ?? [])
          .map((p) => ((p as List).map(asDouble).toList()))
          .where((p) => p.length >= 2)
          .toList();
}

class FichaTecnica {
  final int? numeroPiso;
  final int? totalPisos;
  final String modelo;
  final String? numeroDepa;
  final double? m2Total;
  final String? planoNivelUrl;
  final String? planoDistribucionUrl;
  final List<RegionNivel> regiones;

  FichaTecnica.fromJson(Map<String, dynamic> j)
    : numeroPiso = asIntOrNull(j['numero_piso']),
      totalPisos = asIntOrNull(j['total_pisos']),
      modelo = asString(j['modelo'], '—'),
      numeroDepa = j['numero_depa'] as String?,
      m2Total = asDoubleOrNull(j['m2_total']),
      planoNivelUrl = j['plano_nivel_url'] as String?,
      planoDistribucionUrl = j['plano_distribucion_url'] as String?,
      regiones = ((j['regiones'] as List?) ?? [])
          .map((e) => RegionNivel.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.polygon.length >= 3)
          .toList();
}

class DocumentoItem {
  final int id;
  final String nombre;
  final String tipo;
  final String? fecha;
  final String? urlFirmada;

  DocumentoItem.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], 'Documento'),
      tipo = asString(j['tipo'], 'Documento'),
      fecha = j['fecha'] as String?,
      urlFirmada = j['url_firmada'] as String?;
}

class PropiedadDetalle {
  final int id;
  final String nombre;
  final String proyecto;
  final String modelo;
  final String tipo;
  final String estatus;
  final String categoria; // adquisicion | patrimonio
  final double monto;
  final double avancePago;
  final double pagado;
  final double saldoPendiente;
  final String unidad;
  final int recamaras;
  final int banos;
  final String entrega;
  final double? m2Interiores;
  final double? m2Exteriores;
  final double? m2Total;
  final int? numeroPiso;
  final int? totalPisos;
  final String? urlImagen;
  final String etapaActiva;
  final List<EtapaStage> stages;
  final List<EsquemaPagoItem> esquemaPago;
  final List<ProductoDetalle> productos;
  final FichaTecnica ficha;
  final List<DocumentoItem> documentos;

  PropiedadDetalle.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '—'),
      proyecto = asString(j['proyecto'], '—'),
      modelo = asString(j['modelo'], '—'),
      tipo = asString(j['tipo'], '—'),
      estatus = asString(j['estatus'], '—'),
      categoria = asString(j['categoria'], 'adquisicion'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      pagado = asDouble(j['pagado']),
      saldoPendiente = asDouble(j['saldo_pendiente']),
      unidad = asString(j['unidad'], '—'),
      recamaras = asInt(j['recamaras']),
      banos = asInt(j['banos']),
      entrega = asString(j['entrega'], 'Por confirmar'),
      m2Interiores = asDoubleOrNull(j['m2_interiores']),
      m2Exteriores = asDoubleOrNull(j['m2_exteriores']),
      m2Total = asDoubleOrNull(j['m2_total']),
      numeroPiso = asIntOrNull(j['numero_piso']),
      totalPisos = asIntOrNull(j['total_pisos']),
      urlImagen = j['url_imagen'] as String?,
      etapaActiva = asString((j['etapa'] as Map?)?['activa'], 'preventa'),
      stages = (((j['etapa'] as Map?)?['stages'] as List?) ?? [])
          .map((e) => EtapaStage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      esquemaPago = ((j['esquema_pago'] as List?) ?? [])
          .map((e) => EsquemaPagoItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      productos = ((j['productos'] as List?) ?? [])
          .map((e) => ProductoDetalle.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      ficha = FichaTecnica.fromJson(
        Map<String, dynamic>.from((j['ficha'] as Map?) ?? {}),
      ),
      documentos = ((j['documentos'] as List?) ?? [])
          .map((e) => DocumentoItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

// ─── cliente-perfil ──────────────────────────────────────────────────────────

class ClientePerfil {
  final String nombreLegal;
  final String? email;
  final String? telefono;
  final String tipo;
  final String iniciales;

  ClientePerfil.fromJson(Map<String, dynamic> j)
    : nombreLegal = asString(j['nombre_legal'], 'Cliente'),
      email = j['email'] as String?,
      telefono = j['telefono'] as String?,
      tipo = asString(j['tipo'], 'Inversionista'),
      iniciales = asString(j['iniciales'], '?');
}

// ─── cliente-documentos ──────────────────────────────────────────────────────

class ClienteDocumentos {
  final List<DocumentoItem> documentos;
  final int total;

  ClienteDocumentos.fromJson(Map<String, dynamic> j)
    : documentos = ((j['documentos'] as List?) ?? [])
          .map((e) => DocumentoItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total = asInt(j['total']);
}

// ─── cliente-notificaciones ──────────────────────────────────────────────────

class Notificacion {
  final int id;
  final String tipo;
  final String? categoria;
  final String titulo;
  final String descripcion;
  final String? fecha;
  final bool leida;

  Notificacion.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      tipo = asString(j['tipo'], 'informativa'),
      categoria = j['categoria'] as String?,
      titulo = asString(j['titulo']),
      descripcion = asString(j['descripcion']),
      fecha = j['fecha'] as String?,
      leida = j['leida'] == true;
}

class ClienteNotificaciones {
  final List<Notificacion> notificaciones;
  final int noLeidas;

  ClienteNotificaciones.fromJson(Map<String, dynamic> j)
    : notificaciones = ((j['notificaciones'] as List?) ?? [])
          .map((e) => Notificacion.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      noLeidas = asInt(j['no_leidas']);
}

// ─── cliente-datos-pago (drawer "Datos para pago") ──────────────────────────

class DatosPago {
  final String concepto;
  final double monto;
  final double saldoPendiente;
  final String? fechaPago;
  final String propiedad;
  final String? clabe;
  final String? beneficiario;

  DatosPago.fromJson(Map<String, dynamic> j)
    : concepto = asString(j['concepto'], 'Pago'),
      monto = asDouble(j['monto']),
      saldoPendiente = asDouble(j['saldo_pendiente']),
      fechaPago = j['fecha_pago'] as String?,
      propiedad = asString(j['propiedad'], '—'),
      clabe = j['clabe'] as String?,
      beneficiario = j['beneficiario'] as String?;
}

// ─── cliente-estado-cuenta (por propiedad) ──────────────────────────────────

class AcuerdoPago {
  final int orden;
  final String concepto;
  final String? fecha;
  final double monto;
  final double pagado;
  final double pendiente;
  final bool pagadoCompleto;

  AcuerdoPago.fromJson(Map<String, dynamic> j)
    : orden = asInt(j['orden']),
      concepto = asString(j['concepto'], 'N/A'),
      fecha = j['fecha'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      pendiente = asDouble(j['pendiente']),
      pagadoCompleto = j['pagado_completo'] == true;
}

class MultaItem {
  final String descripcion;
  final double monto;
  final double pagado;
  final double pendiente;
  final bool pagada;

  MultaItem.fromJson(Map<String, dynamic> j)
    : descripcion = asString(j['descripcion'], 'Multa'),
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      pendiente = asDouble(j['pendiente']),
      pagada = j['pagada'] == true;
}

class PagoRealizado {
  final int id;
  final String? fecha;
  final String metodo;
  final String? referencia;
  final double monto;
  final String? urlRecibo;
  final String? urlCep;

  PagoRealizado.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      fecha = j['fecha'] as String?,
      metodo = asString(j['metodo'], 'N/A'),
      referencia = j['referencia'] as String?,
      monto = asDouble(j['monto']),
      urlRecibo = j['url_recibo'] as String?,
      urlCep = j['url_cep'] as String?;
}

class EstadoCuenta {
  final double precioFinal;
  final double totalPagado;
  final double totalMultas;
  final double saldoPendiente;
  final String moneda;
  final List<AcuerdoPago> acuerdos;
  final List<MultaItem> multas;
  final List<PagoRealizado> pagos;
  final double totalPagos;

  EstadoCuenta.fromJson(Map<String, dynamic> j)
    : precioFinal = asDouble((j['resumen'] as Map?)?['precio_final']),
      totalPagado = asDouble((j['resumen'] as Map?)?['total_pagado']),
      totalMultas = asDouble((j['resumen'] as Map?)?['total_multas']),
      saldoPendiente = asDouble((j['resumen'] as Map?)?['saldo_pendiente']),
      moneda = asString((j['resumen'] as Map?)?['moneda'], 'MXN'),
      acuerdos = ((j['acuerdos'] as List?) ?? [])
          .map((e) => AcuerdoPago.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      multas = ((j['multas'] as List?) ?? [])
          .map((e) => MultaItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagos = ((j['pagos'] as List?) ?? [])
          .map((e) => PagoRealizado.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalPagos = asDouble(j['total_pagos']);
}

// ─── admin-clientes (selector de impersonación, solo web) ────────────────────

class AdminCliente {
  final int idPersona;
  final String nombre;
  final String? email;

  AdminCliente.fromJson(Map<String, dynamic> j)
    : idPersona = asInt(j['id_persona']),
      nombre = asString(j['nombre'], 'Cliente'),
      email = j['email'] as String?;
}

class AdminClientes {
  final List<AdminCliente> clientes;

  AdminClientes.fromJson(Map<String, dynamic> j)
    : clientes = ((j['clientes'] as List?) ?? [])
          .map((e) => AdminCliente.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}
