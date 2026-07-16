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

  /// Mensaje contextual de la etapa activa para "Estás al día" (Fase C).
  final String? mensajeContexto;

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
      adquisicionUnidades = asInt(j['adquisicion_unidades']),
      mensajeContexto = j['mensaje_contexto'] as String?;
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

/// Pago aplicado a un acuerdo (abono): permite ver desglose, recibo y CEP por
/// aplicación. Contrato compartido por cliente-estado-cuenta, cliente-pagos y
/// cliente-propiedad-detalle (campo `aplicaciones` de cada acuerdo).
class AplicacionPago {
  final int idPago;
  final double monto;
  final String? fecha;
  final String? metodo;
  final String? claveRastreo;
  final String? urlCep;
  final String? urlRecibo;

  AplicacionPago.fromJson(Map<String, dynamic> j)
    : idPago = asInt(j['id_pago']),
      monto = asDouble(j['monto']),
      fecha = j['fecha'] as String?,
      metodo = j['metodo'] as String?,
      claveRastreo = j['clave_rastreo'] as String?,
      urlCep = j['url_cep'] as String?,
      urlRecibo = j['url_recibo'] as String?;
}

List<AplicacionPago> _parseAplicaciones(dynamic v) => ((v as List?) ?? [])
    .map((e) => AplicacionPago.fromJson(Map<String, dynamic>.from(e)))
    .toList();

class ProximoPago {
  final int id;
  final String concepto;
  final String propiedad;
  final String? fechaPago;
  final double monto;

  /// Abonado hasta ahora (para badge "Parcial" y "Faltan $X").
  final double pagado;
  final bool vencido;
  final List<AplicacionPago> aplicaciones;

  ProximoPago.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      propiedad = asString(j['propiedad'], '—'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      vencido = j['vencido'] == true,
      aplicaciones = _parseAplicaciones(j['aplicaciones']);
}

/// Cuota de mantenimiento en el historial de pagos (por propiedad).
class MantenimientoPago {
  final String propiedad;
  final String mes; // YYYY-MM
  final double monto;
  final String estatus; // pagado | pendiente | vencido

  MantenimientoPago.fromJson(Map<String, dynamic> j)
    : propiedad = asString(j['propiedad'], '—'),
      mes = asString(j['mes'], ''),
      monto = asDouble(j['monto']),
      estatus = asString(j['estatus'], 'pendiente');
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
  final List<MantenimientoPago> historialMantenimiento;

  ClientePagos.fromJson(Map<String, dynamic> j)
    : saldoTotal = asDouble((j['saldo'] as Map?)?['total']),
      saldoPagado = asDouble((j['saldo'] as Map?)?['pagado']),
      saldoPendiente = asDouble((j['saldo'] as Map?)?['pendiente']),
      proximosPagos = ((j['proximos_pagos'] as List?) ?? [])
          .map((e) => ProximoPago.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      historial = ((j['historial'] as List?) ?? [])
          .map((e) => HistorialPago.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      historialMantenimiento = ((j['historial_mantenimiento'] as List?) ?? [])
          .map((e) => MantenimientoPago.fromJson(Map<String, dynamic>.from(e)))
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

  // — Extensión Fase C (opcional en backend; degradan a null/0/false) —
  /// Valor de mercado estimado (m2 × precio_m2_actual del proyecto).
  final double? valorActual;
  final double? plusvaliaPct;
  final double? plusvaliaMonto;
  final String? ubicacion;
  final bool pagoPendiente;
  final String? etapaActiva;
  final double saldoPendiente;
  final String? proximaFecha;
  final int docsPendientes;
  final String? entregadaDesde;

  PropiedadCard.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '—'),
      proyecto = asString(j['proyecto'], '—'),
      modelo = asString(j['modelo'], '—'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      estatus = asString(j['estatus'], '—'),
      urlImagen = j['url_imagen'] as String?,
      valorActual = asDoubleOrNull(j['valor_actual']),
      plusvaliaPct = asDoubleOrNull(j['plusvalia_pct']),
      plusvaliaMonto = asDoubleOrNull(j['plusvalia_monto']),
      ubicacion = j['ubicacion'] as String?,
      pagoPendiente = j['pago_pendiente'] == true,
      etapaActiva = j['etapa_activa'] as String?,
      saldoPendiente = asDouble(j['saldo_pendiente']),
      proximaFecha = j['proxima_fecha'] as String?,
      docsPendientes = asInt(j['docs_pendientes']),
      entregadaDesde = j['entregada_desde'] as String?;
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
      totalProductos = asDouble((j['totales'] as Map?)?['productos']),
      // Fase C: valor de mercado y plusvalía del patrimonio (opcionales).
      totalActivoValorActual = asDoubleOrNull(
        (j['totales'] as Map?)?['activo_valor_actual'],
      ),
      totalPlusvalia = asDoubleOrNull((j['totales'] as Map?)?['plusvalia']);

  final double? totalActivoValorActual;
  final double? totalPlusvalia;
}

// ─── cliente-productos ───────────────────────────────────────────────────────

/// Acuerdo de pago de un producto adicional.
class ProductoAcuerdo {
  final int id;
  final String concepto;
  final String? fecha;
  final double monto;
  final double pagado;
  final bool completado;
  final String? fechaPago;
  final String? urlCep;
  final String? urlRecibo;

  ProductoAcuerdo.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      fecha = j['fecha'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      completado = j['completado'] == true,
      fechaPago = j['fecha_pago'] as String?,
      urlCep = j['url_cep'] as String?,
      urlRecibo = j['url_recibo'] as String?;
}

/// Producto adicional contratado (cajón, bodega, etc.) con su plan de pagos.
class ProductoCliente {
  final int cuentaId;
  final String nombre;
  final String? descripcion;
  final double precioFinal;
  final double totalPagado;
  final double saldoPendiente;
  final String estatus; // Pendiente | En curso | Pagado
  final String? clabe;
  final String? proximaFecha;
  final List<ProductoAcuerdo> acuerdos;

  double get avancePct =>
      precioFinal > 0 ? (totalPagado / precioFinal * 100).clamp(0, 100) : 0;

  ProductoCliente.fromJson(Map<String, dynamic> j)
    : cuentaId = asInt(j['cuenta_id']),
      nombre = asString(j['nombre'], 'Producto adicional'),
      descripcion = j['descripcion'] as String?,
      precioFinal = asDouble(j['precio_final']),
      totalPagado = asDouble(j['total_pagado']),
      saldoPendiente = asDouble(j['saldo_pendiente']),
      estatus = asString(j['estatus'], 'Pendiente'),
      clabe = j['clabe'] as String?,
      proximaFecha = j['proxima_fecha'] as String?,
      acuerdos = ((j['acuerdos'] as List?) ?? [])
          .map((e) => ProductoAcuerdo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

/// Productos agrupados por propiedad.
class ProductosPropiedad {
  final String propiedad;
  final String proyecto;
  final int? cuentaPropiedadId;
  final List<ProductoCliente> productos;

  ProductosPropiedad.fromJson(Map<String, dynamic> j)
    : propiedad = asString(j['propiedad'], '—'),
      proyecto = asString(j['proyecto'], '—'),
      cuentaPropiedadId = asIntOrNull(j['id_cuenta_propiedad']),
      productos = ((j['productos'] as List?) ?? [])
          .map((e) => ProductoCliente.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

class ClienteProductos {
  final List<ProductosPropiedad> propiedades;

  ClienteProductos.fromJson(Map<String, dynamic> j)
    : propiedades = ((j['propiedades'] as List?) ?? [])
          .map((e) => ProductosPropiedad.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  /// Busca un producto por su cuenta (para el detalle por ruta).
  ProductoCliente? productoPorCuenta(int cuentaId) {
    for (final p in propiedades) {
      for (final prod in p.productos) {
        if (prod.cuentaId == cuentaId) return prod;
      }
    }
    return null;
  }
}

// ─── cliente-propiedad-detalle ───────────────────────────────────────────────

class EtapaStage {
  final String id;
  final String label;
  final String status; // completed | active | pending

  const EtapaStage({
    required this.id,
    required this.label,
    required this.status,
  });

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
  final List<AplicacionPago> aplicaciones;

  EsquemaPagoItem.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      saldo = asDouble(j['saldo']),
      pagoCompletado = j['pago_completado'] == true,
      aplicaciones = _parseAplicaciones(j['aplicaciones']);
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

/// Banco con convenio para crédito hipotecario (catálogo dinámico).
class BancoConvenio {
  final int id;
  final String nombre;
  final String? producto;
  final double? tasaDesde;
  final String? color;

  BancoConvenio.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '—'),
      producto = j['producto'] as String?,
      tasaDesde = asDoubleOrNull(j['tasa_desde']),
      color = j['color'] as String?;
}

/// Solicitud de crédito hipotecario del cliente (estatus real).
class SolicitudCredito {
  final int id;
  final String bancoNombre;
  final String estatus;
  final String? fechaSolicitud;
  final String? fechaExpiracion;
  final bool puedeCambiar;

  SolicitudCredito.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      bancoNombre = asString(j['banco_nombre'], '—'),
      estatus = asString(j['estatus'], 'en_revision'),
      fechaSolicitud = j['fecha_solicitud'] as String?,
      fechaExpiracion = j['fecha_expiracion'] as String?,
      puedeCambiar = j['puede_cambiar'] == true;
}

/// Ubicación geográfica del proyecto (para el mapa "cómo llegar").
class PropiedadUbicacion {
  final double latitud;
  final double longitud;
  final String? direccion;

  PropiedadUbicacion.fromJson(Map<String, dynamic> j)
    : latitud = asDouble(j['latitud']),
      longitud = asDouble(j['longitud']),
      direccion = j['direccion'] as String?;
}

/// Copropietario de una cuenta (compradores + personas): nombre, email y
/// porcentaje de copropiedad.
class Copropietario {
  final String nombre;
  final String? email;
  final double porcentaje;

  Copropietario.fromJson(Map<String, dynamic> j)
    : nombre = asString(j['nombre'], '—'),
      email = j['email'] as String?,
      porcentaje = asDouble(j['porcentaje']);
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
  final PropiedadUbicacion? ubicacion;

  /// Método de pago final elegido: RECURSOS_PROPIOS | CREDITO_HIPOTECARIO
  /// (null hasta que el cliente decide, solo aplica en etapa pago_final).
  final String? tipoFinanciamiento;

  /// Solicitud de crédito hipotecario vigente (null si no hay).
  final SolicitudCredito? solicitudCredito;

  /// Propiedad en proceso legal: modo solo lectura (sin CTAs de pago).
  final bool enDemanda;
  final String etapaActiva;
  final List<EtapaStage> stages;
  final List<EsquemaPagoItem> esquemaPago;
  final List<ProductoDetalle> productos;
  final FichaTecnica ficha;
  final List<DocumentoItem> documentos;

  /// Copropietarios de la cuenta (la sección solo se muestra si hay > 1).
  final List<Copropietario> copropietarios;

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
      ubicacion = j['ubicacion'] is Map
          ? PropiedadUbicacion.fromJson(
              Map<String, dynamic>.from(j['ubicacion'] as Map),
            )
          : null,
      tipoFinanciamiento = j['tipo_financiamiento'] as String?,
      solicitudCredito = j['solicitud_credito'] is Map
          ? SolicitudCredito.fromJson(
              Map<String, dynamic>.from(j['solicitud_credito'] as Map),
            )
          : null,
      enDemanda = j['en_demanda'] == true,
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
          .toList(),
      copropietarios = ((j['copropietarios'] as List?) ?? [])
          .map((e) => Copropietario.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  // ── Montos efectivos (espejo del portal, use-portfolio.ts) ────────────────
  // El portal cae a propiedades.precio_lista cuando cuentas_cobranza tiene
  // precio_final = 0 (cuentas legacy). El backend del app aún puede mandar
  // monto = 0 en ese caso; como fallback local usamos la suma del plan de
  // pagos (acuerdos), que representa el precio contractual.

  /// Precio total efectivo: `monto` del backend o, si viene en 0, la suma
  /// del cronograma de pagos.
  double get montoEfectivo => monto > 0
      ? monto
      : esquemaPago.fold<double>(0, (s, e) => s + e.monto);

  /// Pagado efectivo: `pagado` del backend (Σ pagos activos) o, si viene en
  /// 0 pero hay abonos en el plan, la suma de lo aplicado por acuerdo.
  double get pagadoEfectivo => pagado > 0
      ? pagado
      : esquemaPago.fold<double>(0, (s, e) => s + e.pagado);

  /// Saldo pendiente efectivo (max 0, nunca negativo).
  double get saldoPendienteEfectivo => montoEfectivo > 0
      ? (montoEfectivo - pagadoEfectivo).clamp(0, montoEfectivo).toDouble()
      : saldoPendiente;

  /// % de avance de pago efectivo (0-100).
  double get avancePagoEfectivo => montoEfectivo > 0
      ? (pagadoEfectivo / montoEfectivo * 100).clamp(0, 100).toDouble()
      : avancePago;

  /// Etapa activa efectiva. Solo cuando el backend mandó monto = 0 (cuenta
  /// legacy sin precio_final) su saldo/etapa se calcularon con precio 0 y la
  /// cuenta salta a "escrituración" aunque deba dinero; en ese caso se
  /// corrige a `pago_final` (criterio byPaymentProgress del portal:
  /// saldo > 0 → pago final). Con monto > 0 la etapa del backend ya es
  /// idéntica a la del portal y se respeta.
  String get etapaActivaEfectiva {
    if (monto <= 0 &&
        saldoPendienteEfectivo > 0 &&
        etapaActiva == 'escrituracion') {
      return 'pago_final';
    }
    return etapaActiva;
  }

  /// Stages con el status recalculado cuando aplica la corrección de etapa
  /// (mantiene ids/labels del backend; solo mueve la etapa activa).
  List<EtapaStage> get stagesEfectivos {
    final activa = etapaActivaEfectiva;
    if (activa == etapaActiva) return stages;
    final activeIdx = stages.indexWhere((s) => s.id == activa);
    if (activeIdx < 0) return stages;
    return [
      for (var i = 0; i < stages.length; i++)
        EtapaStage(
          id: stages[i].id,
          label: stages[i].label,
          status: i < activeIdx
              ? 'completed'
              : i == activeIdx
                  ? 'active'
                  : 'pending',
        ),
    ];
  }
}

// ─── admin-avisos-app ────────────────────────────────────────────────────────

/// Item genérico de catálogo (proyecto, modelo, propiedad) para filtros.
class CatalogoItem {
  final int id;
  final String nombre;

  CatalogoItem.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '—');
}

/// Aviso enviado (o programado) desde el acceso admin a clientes del app.
class AvisoApp {
  final int id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final String categoria;
  final List<String> canales;
  final List<int> idsProyectos;
  final List<int> idsModelos;
  final List<int> idsPropiedades;
  final String? programadoPara;
  final String estado; // pendiente | enviado | cancelado | error
  final int? totalDestinatarios;
  final int? totalPush;
  final int? totalEmail;
  final int? totalWa;
  final String? creadoPor;
  final String? fechaCreacion;

  AvisoApp.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      titulo = asString(j['titulo'], '—'),
      mensaje = asString(j['mensaje'], ''),
      tipo = asString(j['tipo'], 'informativa'),
      categoria = asString(j['categoria'], 'pagos'),
      canales = ((j['canales'] as List?) ?? []).map((e) => '$e').toList(),
      idsProyectos = ((j['ids_proyectos'] as List?) ?? [])
          .map((e) => asInt(e))
          .toList(),
      idsModelos = ((j['ids_modelos'] as List?) ?? [])
          .map((e) => asInt(e))
          .toList(),
      idsPropiedades = ((j['ids_propiedades'] as List?) ?? [])
          .map((e) => asInt(e))
          .toList(),
      programadoPara = j['programado_para'] as String?,
      estado = asString(j['estado'], 'pendiente'),
      totalDestinatarios = asIntOrNull(j['total_destinatarios']),
      totalPush = asIntOrNull(j['total_push']),
      totalEmail = asIntOrNull(j['total_email']),
      totalWa = asIntOrNull(j['total_wa']),
      creadoPor = j['creado_por'] as String?,
      fechaCreacion = j['fecha_creacion'] as String?;
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

  /// Animación de llegada configurada por el admin: sobre | gol | cohete.
  final String animacionCampana;

  ClienteNotificaciones.fromJson(Map<String, dynamic> j)
    : notificaciones = ((j['notificaciones'] as List?) ?? [])
          .map((e) => Notificacion.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      noLeidas = asInt(j['no_leidas']),
      animacionCampana = asString(j['animacion_campana'], 'gol');
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
  final List<AplicacionPago> aplicaciones;

  AcuerdoPago.fromJson(Map<String, dynamic> j)
    : orden = asInt(j['orden']),
      concepto = asString(j['concepto'], 'N/A'),
      fecha = j['fecha'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      pendiente = asDouble(j['pendiente']),
      pagadoCompleto = j['pagado_completo'] == true,
      aplicaciones = _parseAplicaciones(j['aplicaciones']);
}

/// Instrucciones de transferencia STP del estado de cuenta.
class InstruccionesPago {
  final String? clabe;
  final String? banco;
  final String? beneficiario;
  final String referencia;

  InstruccionesPago.fromJson(Map<String, dynamic> j)
    : clabe = j['clabe'] as String?,
      banco = j['banco'] as String?,
      beneficiario = j['beneficiario'] as String?,
      referencia = asString(j['referencia'], '');
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
  final InstruccionesPago? instrucciones;

  EstadoCuenta.fromJson(Map<String, dynamic> j)
    : precioFinal = asDouble((j['resumen'] as Map?)?['precio_final']),
      totalPagado = asDouble((j['resumen'] as Map?)?['total_pagado']),
      totalMultas = asDouble((j['resumen'] as Map?)?['total_multas']),
      saldoPendiente = asDouble((j['resumen'] as Map?)?['saldo_pendiente']),
      moneda = asString((j['resumen'] as Map?)?['moneda'], 'MXN'),
      instrucciones = j['instrucciones_pago'] is Map
          ? InstruccionesPago.fromJson(
              Map<String, dynamic>.from(j['instrucciones_pago'] as Map),
            )
          : null,
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
