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

/// String no vacío o null (para URLs/textos opcionales del backend).
String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

// ─── cliente-app-version (version gate nativo) ───────────────────────────────

/// Info de versión para el "version gate" de la app nativa (Android/iOS).
/// La entrega la edge function `cliente-app-version` (anon key, pre-login).
class AppVersionInfo {
  /// Versión mínima soportada (SemVer, ej. "1.0.0"). Si la actual es menor,
  /// se fuerza la actualización. null => sin mínimo.
  final String? minVersion;

  /// Última versión publicada (SemVer). Si la actual es menor (y cumple el
  /// mínimo), se sugiere actualizar (aviso descartable). null => sin sugerencia.
  final String? latestVersion;

  /// Fuerza la actualización aunque la versión actual cumpla el mínimo.
  final bool forceUpdate;

  final String? androidStoreUrl;
  final String? iosStoreUrl;

  /// Texto opcional a mostrar en el aviso/pantalla de actualización.
  final String? updateMessage;

  const AppVersionInfo({
    this.minVersion,
    this.latestVersion,
    this.forceUpdate = false,
    this.androidStoreUrl,
    this.iosStoreUrl,
    this.updateMessage,
  });

  /// Info vacía (no gatea nada). Útil como degradación ante error.
  const AppVersionInfo.empty()
    : minVersion = null,
      latestVersion = null,
      forceUpdate = false,
      androidStoreUrl = null,
      iosStoreUrl = null,
      updateMessage = null;

  AppVersionInfo.fromJson(Map<String, dynamic> j)
    : minVersion = asStringOrNull(j['min_version']),
      latestVersion = asStringOrNull(j['latest_version']),
      forceUpdate = j['force_update'] == true,
      androidStoreUrl = asStringOrNull(j['android_store_url']),
      iosStoreUrl = asStringOrNull(j['ios_store_url']),
      updateMessage = asStringOrNull(j['update_message']);
}

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
      propiedad = asString(j['propiedad'], '-'),
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
      proyecto = asString(j['proyecto'], '-'),
      unidad = asString(j['unidad'], '-'),
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
      propiedad = asString(j['propiedad'], '-'),
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
    : propiedad = asString(j['propiedad'], '-'),
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

  // - Campos ricos del recibo (PaymentReceiptModal del portal). Additivos: si
  //   el backend aún no los expone llegan null y la UI del recibo degrada. -
  final String? rfc; // RFC del cliente
  final String? clabe; // CLABE STP enmascarada (solo últimos 4)
  final String? claveRastreo; // "Clave de rastreo" del recibo
  final String? referenciaStp; // referencia STP (SOZU-<cuenta>)
  final String? producto; // nombre del producto (productName del portal)
  final double? saldo; // saldo pendiente de la propiedad
  final double? totalPagado; // total pagado acumulado de la propiedad
  final double? valorActivo; // valor total del activo

  HistorialPago.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      propiedad = asString(j['propiedad'], '-'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      metodo = asString(j['metodo'], '-'),
      urlRecibo = j['url_recibo'] as String?,
      urlCep = j['url_cep'] as String?,
      rfc = j['rfc'] as String?,
      clabe = j['clabe'] as String?,
      claveRastreo = j['clave_rastreo'] as String?,
      referenciaStp = j['referencia_stp'] as String?,
      producto = (j['producto'] ?? j['product_name']) as String?,
      saldo = asDoubleOrNull(j['saldo']),
      totalPagado = asDoubleOrNull(j['total_pagado']),
      valorActivo = asDoubleOrNull(j['valor_activo']);
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

  // - Extensión Fase C (opcional en backend; degradan a null/0/false) -
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

  /// Cuota mensual de mantenimiento (backend `monthly_fee` = costo_mant_m2 × m2).
  /// 0 si el proyecto no tiene costo de mantenimiento o la propiedad no tiene m2.
  final double cuotaMensual;

  PropiedadCard.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '-'),
      proyecto = asString(j['proyecto'], '-'),
      modelo = asString(j['modelo'], '-'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      estatus = asString(j['estatus'], '-'),
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
      entregadaDesde = j['entregada_desde'] as String?,
      cuotaMensual = asDouble(j['monthly_fee']);

  /// Etiqueta de estatus derivada de la etapa activa, como el portal
  /// (getStageInfo): NUNCA el estatus crudo de disponibilidad de la BD, que
  /// puede decir "Pagada completamente" o "Vendida" aunque la cuenta tenga
  /// saldo pendiente. Si el backend aún no manda `etapa_activa`, cae al
  /// estatus crudo.
  String get estatusDerivado => switch (etapaActiva) {
    'preventa' => 'En Preventa',
    'pago_final' => 'Pago Pendiente',
    'escrituracion' => 'En Escrituración',
    'entrega' => 'Por Entregar',
    'post_entrega' => 'Entregada',
    _ => estatus,
  };
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
      propiedad = asString(j['propiedad'], '-'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      estatus = asString(j['estatus'], '-');
}

class MantenimientoCard {
  final int id;
  final String propiedad;
  final double saldoPendiente;
  final String? proximoPago;

  MantenimientoCard.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      propiedad = asString(j['propiedad'], '-'),
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
    : propiedad = asString(j['propiedad'], '-'),
      proyecto = asString(j['proyecto'], '-'),
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

  /// Posición del concepto en la secuencia del plan de pagos (la manda el
  /// backend en `esquema_pago[].orden`, ascendente: apartado primero,
  /// pago a escrituración/contraentrega al final). Se usa para ordenar el
  /// cronograma por etapa del plan. Puede venir null en cuentas legacy.
  final int? orden;

  final List<AplicacionPago> aplicaciones;

  EsquemaPagoItem.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      concepto = asString(j['concepto'], 'Pago'),
      fechaPago = j['fecha_pago'] as String?,
      monto = asDouble(j['monto']),
      pagado = asDouble(j['pagado']),
      saldo = asDouble(j['saldo']),
      pagoCompletado = j['pago_completado'] == true,
      orden = asIntOrNull(j['orden']),
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
      modelo = asString(j['modelo'], '-'),
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

  // - Extensión paridad portal (opcionales en backend; degradan a defaults) -
  /// Estatus de verificación: recibido | validado | rechazado.
  final String estatus;

  /// Categoría del portal: contrato | escritura | comprobante | cfdi |
  /// identificacion | garantia | otro.
  final String categoria;

  /// Cuenta de cobranza asociada (null = documento personal).
  final int? idCuenta;

  /// Etiqueta "Proyecto · U-número" (null = documento personal).
  final String? propiedad;

  /// Motivo de rechazo (opcional; solo cuando el backend lo expone para
  /// documentos con estatus `rechazado`).
  final String? motivoRechazo;

  DocumentoItem.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], 'Documento'),
      tipo = asString(j['tipo'], 'Documento'),
      fecha = j['fecha'] as String?,
      urlFirmada = j['url_firmada'] as String?,
      estatus = asString(j['estatus'], 'recibido'),
      categoria = asString(j['categoria'], 'otro'),
      idCuenta = asIntOrNull(j['id_cuenta']),
      propiedad = j['propiedad'] as String?,
      motivoRechazo = (j['motivo_rechazo'] ?? j['motivo']) as String?;
}

/// Factura CFDI de una propiedad (PDF + XML firmados), como el portal.
class FacturaDocumento {
  final int idCuenta;
  final String? propiedad;
  final String? pdf;
  final String? xml;

  FacturaDocumento.fromJson(Map<String, dynamic> j)
    : idCuenta = asInt(j['id_cuenta']),
      propiedad = j['propiedad'] as String?,
      pdf = j['pdf'] as String?,
      xml = j['xml'] as String?;
}

/// Factura CFDI de un pago de mantenimiento.
///
/// [idCuenta] es la cuenta PADRE, la misma que usa [FacturaDocumento]: con ella
/// las dos listas caen bajo la misma unidad. Llega null mientras el backend no
/// la mande, y entonces la factura queda sin unidad asignada.
class FacturaMantenimientoDoc {
  final int idPago;
  final int? idCuenta;
  final String? propiedad;
  final double? monto;
  final String? fecha;
  final String? pdf;
  final String? xml;

  FacturaMantenimientoDoc.fromJson(Map<String, dynamic> j)
    : idPago = asInt(j['id_pago']),
      idCuenta = j['id_cuenta'] == null ? null : asInt(j['id_cuenta']),
      propiedad = j['propiedad'] as String?,
      monto = j['monto'] == null ? null : asDouble(j['monto']),
      fecha = j['fecha'] as String?,
      pdf = j['pdf'] as String?,
      xml = j['xml'] as String?;
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
      nombre = asString(j['nombre'], '-'),
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
      bancoNombre = asString(j['banco_nombre'], '-'),
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
    : nombre = asString(j['nombre'], '-'),
      email = j['email'] as String?,
      porcentaje = asDouble(j['porcentaje']);
}

/// Agente comercial asignado a la cuenta (card lateral "Tu agente comercial"
/// del detalle en modo portal, espejo de AgentSideCard). Extensión ADITIVA:
/// el edge puede desplegar estos datos después; si el objeto llega null/ausente
/// la card se oculta por completo (degradación).
class AgenteComercial {
  final String nombre;
  final String titulo;

  /// Teléfono en formato visible ("+52 33 1234 5678") o null.
  final String? telefono;

  /// WhatsApp solo dígitos ("523312345678") para el deep link wa.me, o null.
  final String? whatsapp;
  final String? email;

  /// Tiempo de respuesta promedio ("Responde en ~2 h"), opcional.
  final String? tiempoRespuesta;

  AgenteComercial.fromJson(Map<String, dynamic> j)
    : nombre = asString(j['nombre'], '-'),
      titulo = asString(j['titulo'], 'Asesor SOZU'),
      telefono = j['telefono'] as String?,
      whatsapp = j['whatsapp'] as String?,
      email = j['email'] as String?,
      tiempoRespuesta = j['tiempo_respuesta'] as String?;
}

/// Hito del avance de obra (fase constructiva + % + si está completado).
class HitoObra {
  final String fase;
  final int pct;
  final bool completado;

  HitoObra.fromJson(Map<String, dynamic> j)
    : fase = asString(j['fase'], '-'),
      pct = asInt(j['pct']),
      completado = j['completado'] == true;
}

/// Avance de obra del proyecto (card "Avance de obra" del detalle en modo
/// portal, espejo de ConstructionProgress; sin el video embebido). Extensión
/// ADITIVA con degradación: la card se oculta si el objeto llega null/ausente.
class AvanceObra {
  /// Título de la card ("Avance de obra" / "Proyecto entregado"), opcional.
  final String? estatus;

  /// Avance global 0-100.
  final double avanceGlobal;

  /// Texto de última actualización ya formateado por el backend, o null.
  final String? ultimaActualizacion;

  /// Fecha estimada de entrega (ISO) o null.
  final String? entregaEstimada;
  final List<HitoObra> hitos;

  AvanceObra.fromJson(Map<String, dynamic> j)
    : estatus = j['estatus'] as String?,
      avanceGlobal = asDouble(j['avance_global']),
      ultimaActualizacion = j['ultima_actualizacion'] as String?,
      entregaEstimada = j['entrega_estimada'] as String?,
      hitos = ((j['hitos'] as List?) ?? [])
          .map((e) => HitoObra.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  /// Degradación: la card solo se pinta si el backend mandó datos reales.
  /// Sin hitos (o con todos los porcentajes en 0) no hay nada que mostrar y
  /// se prefiere ocultar la card antes que inventar un desglose.
  bool get tieneDatosReales =>
      hitos.isNotEmpty && (avanceGlobal > 0 || hitos.any((h) => h.pct > 0));
}

/// Foto de la galería de la propiedad (render + obra). Extensión ADITIVA:
/// el backend puede desplegar `galeria` después; degrada a lista vacía.
class GaleriaFoto {
  final String url;

  /// Categoría del portal (p.ej. render | fachada | interior | obra | amenidad).
  final String categoria;

  GaleriaFoto.fromJson(Map<String, dynamic> j)
    : url = asString(j['url']),
      categoria = asString(j['categoria'], 'otro');
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

  /// Galería de fotos de la propiedad (render/obra). Extensión ADITIVA;
  /// degrada a lista vacía si el backend aún no la manda.
  final List<GaleriaFoto> galeria;

  /// URL del video del avance de obra (embebido). null/ausente = sin video.
  final String? videoObraUrl;
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

  /// Agente comercial asignado (card lateral en portal). null/ausente =
  /// card oculta. Backend puede desplegar este campo después (aditivo).
  final AgenteComercial? agente;

  /// Avance de obra del proyecto (card en portal). null/ausente = card
  /// oculta. Backend puede desplegar este campo después (aditivo).
  final AvanceObra? avanceObra;

  PropiedadDetalle.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      nombre = asString(j['nombre'], '-'),
      proyecto = asString(j['proyecto'], '-'),
      modelo = asString(j['modelo'], '-'),
      tipo = asString(j['tipo'], '-'),
      estatus = asString(j['estatus'], '-'),
      categoria = asString(j['categoria'], 'adquisicion'),
      monto = asDouble(j['monto']),
      avancePago = asDouble(j['avance_pago']),
      pagado = asDouble(j['pagado']),
      saldoPendiente = asDouble(j['saldo_pendiente']),
      unidad = asString(j['unidad'], '-'),
      recamaras = asInt(j['recamaras']),
      banos = asInt(j['banos']),
      entrega = asString(j['entrega'], 'Por confirmar'),
      m2Interiores = asDoubleOrNull(j['m2_interiores']),
      m2Exteriores = asDoubleOrNull(j['m2_exteriores']),
      m2Total = asDoubleOrNull(j['m2_total']),
      numeroPiso = asIntOrNull(j['numero_piso']),
      totalPisos = asIntOrNull(j['total_pisos']),
      urlImagen = j['url_imagen'] as String?,
      galeria = ((j['galeria'] as List?) ?? [])
          .map((e) => GaleriaFoto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      videoObraUrl = j['video_obra_url'] as String?,
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
          .toList(),
      agente = j['agente_comercial'] is Map
          ? AgenteComercial.fromJson(
              Map<String, dynamic>.from(j['agente_comercial'] as Map),
            )
          : null,
      avanceObra = j['avance_obra'] is Map
          ? AvanceObra.fromJson(
              Map<String, dynamic>.from(j['avance_obra'] as Map),
            )
          : null;

  // ── Montos efectivos (espejo del portal, use-portfolio.ts) ────────────────
  // El portal cae a propiedades.precio_lista cuando cuentas_cobranza tiene
  // precio_final = 0 (cuentas legacy). El backend del app aún puede mandar
  // monto = 0 en ese caso; como fallback local usamos la suma del plan de
  // pagos (acuerdos), que representa el precio contractual.

  /// Precio total efectivo: `monto` del backend o, si viene en 0, la suma
  /// del cronograma de pagos.
  double get montoEfectivo =>
      monto > 0 ? monto : esquemaPago.fold<double>(0, (s, e) => s + e.monto);

  /// Pagado efectivo: `pagado` del backend (Σ pagos activos) o, si viene en
  /// 0 pero hay abonos en el plan, la suma de lo aplicado por acuerdo.
  double get pagadoEfectivo =>
      pagado > 0 ? pagado : esquemaPago.fold<double>(0, (s, e) => s + e.pagado);

  /// Saldo pendiente efectivo (max 0, nunca negativo).
  double get saldoPendienteEfectivo => montoEfectivo > 0
      ? (montoEfectivo - pagadoEfectivo).clamp(0, montoEfectivo).toDouble()
      : saldoPendiente;

  /// % de avance de pago efectivo (0-100).
  double get avancePagoEfectivo => montoEfectivo > 0
      ? (pagadoEfectivo / montoEfectivo * 100).clamp(0, 100).toDouble()
      : avancePago;

  /// Orden del ciclo de vida de la transacción (espejo de use-portfolio.ts).
  static const List<String> _ordenEtapas = [
    'preventa',
    'pago_final',
    'escrituracion',
    'entrega',
    'post_entrega',
  ];

  /// Hay parcialidades/mensualidades pendientes en el plan de pagos (conceptos
  /// 4 Mensualidad y 5 Parcialidad del portal, que corren durante obra). Se
  /// detecta por el nombre del concepto ya que el app no expone id_concepto.
  bool get _hayParcialidadesPendientes => esquemaPago.any((e) {
    if (e.pagoCompletado) return false;
    final c = e.concepto.toLowerCase();
    return c.startsWith('parcialidad') || c.startsWith('mensualidad');
  });

  /// Etapa activa efectiva. Replica el "cap por realidad de pago" del portal
  /// (buildStages en use-portfolio.ts): escrituración/entrega/post-entrega
  /// exigen saldo ≈ 0. Si el backend manda una etapa más avanzada pero aún
  /// hay `saldoPendienteEfectivo > 0`, el estatus_disponibilidad está
  /// desfasado (p.ej. reprecio con cuenta nueva que hereda estatus de la
  /// anterior); se corrige a `pago_final` (o a `preventa` si todavía quedan
  /// parcialidades pendientes). Con saldo = 0 se respeta la etapa del backend.
  String get etapaActivaEfectiva {
    if (saldoPendienteEfectivo > 0) {
      final tope = _hayParcialidadesPendientes ? 'preventa' : 'pago_final';
      final idxTope = _ordenEtapas.indexOf(tope);
      final idxActiva = _ordenEtapas.indexOf(etapaActiva);
      if (idxActiva > idxTope) return tope;
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
      nombre = asString(j['nombre'], '-');
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
      titulo = asString(j['titulo'], '-'),
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

  /// URL firmada temporal de la foto de perfil (avatar). null si el cliente no
  /// tiene foto o el backend aún no expone el campo (degrada a iniciales).
  final String? fotoPerfilUrl;

  // Perfil extendido (espejo de ClientePerfil.tsx del portal). Con un backend
  // previo estos campos llegan null/vacíos y la UI degrada a "Sin dato".
  final String? clavePaisTelefono;
  final String? ocupacion;
  final String? tipoPersona; // pf | pm | pe (o variantes largas)
  final String? rfc;
  final String? curp;
  final String? regimen;
  final String? regimenNombre;
  final String? usoCfdi;
  final String? usoCfdiNombre;
  final String? cp;
  final String? calle;
  final String? numExt;
  final String? numInt;
  final String? colonia;
  final List<CuentaBancariaPerfil> cuentasBancarias;
  final List<int> docsTipos;
  final int perfilCompletado; // 0-100
  final String estatusPerfil; // verified | review | incomplete

  /// true si el cliente es persona moral. Decide qué documentos se le piden y
  /// qué datos NO aplican (una empresa no tiene CURP ni acta de nacimiento).
  bool get esMoral {
    final v = (tipoPersona ?? '').toLowerCase().trim();
    return v == 'pm' || v.contains('moral');
  }

  /// Etiqueta "Persona física/moral/extranjera" (espejo de tipo-persona.ts).
  String get tipoPersonaLabel {
    final v = (tipoPersona ?? '').toLowerCase().trim();
    if (v == 'pm' || v.contains('moral')) return 'Persona moral';
    if (v == 'pe' || v.contains('extranjer')) return 'Persona extranjera';
    return 'Persona física';
  }

  /// "601 - General de Ley..." o solo la clave si no hay nombre de catálogo.
  String? get regimenDisplay => regimen == null
      ? null
      : (regimenNombre != null ? '$regimen - $regimenNombre' : regimen);

  String? get usoCfdiDisplay => usoCfdi == null
      ? null
      : (usoCfdiNombre != null ? '$usoCfdi - $usoCfdiNombre' : usoCfdi);

  ClientePerfil.fromJson(Map<String, dynamic> j)
    : nombreLegal = asString(j['nombre_legal'], 'Cliente'),
      email = j['email'] as String?,
      telefono = j['telefono'] as String?,
      tipo = asString(j['tipo'], 'Inversionista'),
      iniciales = asString(j['iniciales'], '?'),
      fotoPerfilUrl = j['foto_perfil_url'] as String?,
      clavePaisTelefono = j['clave_pais_telefono'] as String?,
      ocupacion = j['ocupacion'] as String?,
      tipoPersona = j['tipo_persona'] as String?,
      rfc = j['rfc'] as String?,
      curp = j['curp'] as String?,
      regimen = j['regimen'] as String?,
      regimenNombre = j['regimen_nombre'] as String?,
      usoCfdi = j['uso_cfdi'] as String?,
      usoCfdiNombre = j['uso_cfdi_nombre'] as String?,
      cp = (j['direccion_fiscal'] is Map)
          ? (j['direccion_fiscal'] as Map)['codigo_postal'] as String?
          : null,
      calle = (j['direccion_fiscal'] is Map)
          ? (j['direccion_fiscal'] as Map)['calle'] as String?
          : null,
      numExt = (j['direccion_fiscal'] is Map)
          ? (j['direccion_fiscal'] as Map)['num_ext'] as String?
          : null,
      numInt = (j['direccion_fiscal'] is Map)
          ? (j['direccion_fiscal'] as Map)['num_int'] as String?
          : null,
      colonia = (j['direccion_fiscal'] is Map)
          ? (j['direccion_fiscal'] as Map)['colonia'] as String?
          : null,
      cuentasBancarias = ((j['cuentas_bancarias'] as List?) ?? [])
          .map(
            (e) => CuentaBancariaPerfil.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      docsTipos = ((j['docs_tipos'] as List?) ?? [])
          .map((e) => asInt(e))
          .toList(),
      perfilCompletado = asInt(j['perfil_completado']),
      estatusPerfil = asString(j['estatus_perfil'], 'incomplete');
}

/// Cuenta bancaria de dispersión del cliente (cliente-perfil).
class CuentaBancariaPerfil {
  final int id;
  final int idBanco;
  final String banco;

  /// Número de cuenta (clave real, 8-34; espejo del portal).
  final String? numeroCuenta;
  final String? clabe;

  /// Código SWIFT (opcional; cuentas internacionales).
  final String? swift;
  final String? titular;

  /// Estatus de verificación (1 revisión · 2 validada · 3 rechazada), opcional.
  final int? estatus;

  /// URL de la carátula del estado de cuenta (evidencia), opcional.
  final String? evidencia;

  CuentaBancariaPerfil.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      idBanco = asInt(j['id_banco']),
      banco = asString(j['banco'], 'Banco'),
      numeroCuenta = j['numero_cuenta'] as String?,
      clabe = j['clabe'] as String?,
      swift = j['swift'] as String?,
      titular = j['titular'] as String?,
      estatus = asIntOrNull(j['estatus']),
      evidencia = j['evidencia'] as String?;

  /// Últimos 4 dígitos enmascarados de la CLABE ("****1234") o null.
  String? get clabeMasked {
    final c = clabe;
    if (c == null || c.length < 4) return null;
    return '****${c.substring(c.length - 4)}';
  }

  /// Enmascarado del número de cuenta (o la CLABE si no hay número), como el
  /// portal: "****1234".
  String? get cuentaMasked {
    final c = (numeroCuenta != null && numeroCuenta!.isNotEmpty)
        ? numeroCuenta!
        : clabe;
    if (c == null || c.length < 4) return null;
    return '****${c.substring(c.length - 4)}';
  }
}

/// Datos fiscales detectados en la CSF (cliente-expediente subir → CSF),
/// para el diálogo de confirmación del expediente.
class DatosFiscalesCSF {
  final String? rfc;
  final String? curp;
  final String? nombre;
  final String? regimen;
  final String? codigoPostal;
  final String? calle;
  final String? numExt;
  final String? numInt;
  final String? colonia;

  DatosFiscalesCSF.fromJson(Map<String, dynamic> j)
    : rfc = j['rfc'] as String?,
      curp = j['curp'] as String?,
      nombre = j['nombre'] as String?,
      regimen = j['regimen'] as String?,
      codigoPostal = j['codigo_postal'] as String?,
      calle = j['calle'] as String?,
      numExt = j['num_ext'] as String?,
      numInt = j['num_int'] as String?,
      colonia = j['colonia'] as String?;
}

/// Datos detectados en la CURP (cliente-expediente subir → CURP tipo 5), para
/// el diálogo de confirmación del expediente (paridad con ConfirmDataModal).
class DatosCURP {
  final String? curp;
  final String? nombre;
  final String? fechaNacimiento;
  final String? sexo; // "H" | "M"

  DatosCURP.fromJson(Map<String, dynamic> j)
    : curp = j['curp'] as String?,
      nombre = j['nombre'] as String?,
      fechaNacimiento = j['fecha_nacimiento'] as String?,
      sexo = j['sexo'] as String?;

  /// Etiqueta legible del sexo ("Hombre"/"Mujer"/"").
  String get sexoLabel => sexo == 'H'
      ? 'Hombre'
      : sexo == 'M'
      ? 'Mujer'
      : '';
}

/// Datos detectados en el Acta de nacimiento (cliente-expediente subir → tipo
/// 1), para el diálogo de confirmación del expediente.
class DatosActa {
  final String? curp;
  final String? nombre;
  final String? fechaNacimiento;
  final String? sexo; // "H" | "M"
  final String? lugarNacimiento;

  DatosActa.fromJson(Map<String, dynamic> j)
    : curp = j['curp'] as String?,
      nombre = j['nombre'] as String?,
      fechaNacimiento = j['fecha_nacimiento'] as String?,
      sexo = j['sexo'] as String?,
      lugarNacimiento = j['lugar_nacimiento'] as String?;

  String get sexoLabel => sexo == 'H'
      ? 'Hombre'
      : sexo == 'M'
      ? 'Mujer'
      : '';
}

/// Catálogos para editar el perfil (cliente-perfil action=catalogos).
class PerfilCatalogos {
  final List<({String id, String nombre})> regimen;
  final List<({String codigo, String nombre})> usoCfdi;
  final List<({int id, String nombre})> bancos;

  PerfilCatalogos.fromJson(Map<String, dynamic> j)
    : regimen = ((j['regimen'] as List?) ?? [])
          .map(
            (e) =>
                (id: asString((e as Map)['id']), nombre: asString(e['nombre'])),
          )
          .toList(),
      usoCfdi = ((j['uso_cfdi'] as List?) ?? [])
          .map(
            (e) => (
              codigo: asString((e as Map)['codigo']),
              nombre: asString(e['nombre']),
            ),
          )
          .toList(),
      bancos = ((j['bancos'] as List?) ?? [])
          .map(
            (e) => (id: asInt((e as Map)['id']), nombre: asString(e['nombre'])),
          )
          .toList();
}

// ─── cliente-documentos ──────────────────────────────────────────────────────

class ClienteDocumentos {
  final List<DocumentoItem> documentos;
  final List<FacturaDocumento> facturas;
  final List<FacturaMantenimientoDoc> facturasMantenimiento;
  final int total;

  ClienteDocumentos.fromJson(Map<String, dynamic> j)
    : documentos = ((j['documentos'] as List?) ?? [])
          .map((e) => DocumentoItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      facturas = ((j['facturas'] as List?) ?? [])
          .map((e) => FacturaDocumento.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      facturasMantenimiento = ((j['facturas_mantenimiento'] as List?) ?? [])
          .map(
            (e) =>
                FacturaMantenimientoDoc.fromJson(Map<String, dynamic>.from(e)),
          )
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

  /// URL de acción del portal (p.ej. "/pagos", "/propiedades/12"); el app la
  /// mapea a una ruta de su router al tocar la notificación.
  final String? urlAccion;

  /// Texto del enlace de acción al pie de la fila (p.ej. "Ver detalle").
  final String? etiquetaAccion;
  final bool leida;

  Notificacion.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      tipo = asString(j['tipo'], 'informativa'),
      categoria = j['categoria'] as String?,
      titulo = asString(j['titulo']),
      descripcion = asString(j['descripcion']),
      fecha = j['fecha'] as String?,
      urlAccion = j['url_accion'] as String?,
      etiquetaAccion = j['etiqueta_accion'] as String?,
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
      propiedad = asString(j['propiedad'], '-'),
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

// ─── cliente-expediente ──────────────────────────────────────────────────────

/// Grupo del expediente ("Documentos personales", "Documentos de la empresa",
/// …). El backend manda el orden; el app no lo reordena.
class ExpedienteGrupo {
  final String key;
  final String titulo;

  /// `self` = la persona logueada · `rep` = su representante legal.
  final String owner;

  ExpedienteGrupo.fromJson(Map<String, dynamic> j)
    : key = asString(j['key']),
      titulo = asString(j['titulo']),
      owner = asString(j['owner'], 'self');

  const ExpedienteGrupo({
    required this.key,
    required this.titulo,
    this.owner = 'self',
  });
}

/// Alternativa de un slot que admite varios documentos excluyentes entre sí
/// (identificación oficial: INE completo **o** pasaporte, nunca los dos).
typedef ExpedienteOpcion = ({int tipoId, String label});

/// Representante legal de un cliente persona moral. `bloqueado` es true
/// cuando la persona moral no lo tiene ligado en la base: sus documentos se
/// muestran, pero no se pueden subir hasta que exista el vínculo.
class ExpedienteRepLegal {
  final int? idPersona;
  final String? nombre;
  final bool bloqueado;
  final String? motivo;

  ExpedienteRepLegal.fromJson(Map<String, dynamic> j)
    : idPersona = asIntOrNull(j['id_persona']),
      nombre = asStringOrNull(j['nombre']),
      bloqueado = j['bloqueado'] == true,
      motivo = asStringOrNull(j['motivo']);
}

/// Slot del expediente. `estatus`: aprobado | revision | rechazado | expirado
/// | pendiente | opcional.
///
/// La identidad del slot es [key], NO [tipoId]: en persona moral los tipos 6
/// (CSF) y 8 (domicilio) aparecen dos veces, una de la empresa y otra del
/// representante legal.
class ExpedienteSlot {
  final String key;
  final int tipoId;
  final String nombre;
  final bool requerido;
  final String estatus;
  final String? fecha;
  final String? urlFirmada;
  final bool puedeSubir;

  /// true si el backend solo acepta el PDF original (CURP, CSF, etc.).
  final bool soloPdf;

  /// Grupo al que pertenece. Vacío con el backend anterior a PF/PM.
  final String grupo;

  /// De quién es el documento: `self` o `rep`.
  final String owner;

  /// Por qué no se puede subir cuando la causa es externa al estatus (p. ej.
  /// una persona moral sin representante legal ligado).
  final String? bloqueadoMotivo;

  /// Documentos excluyentes; vacío si el slot admite uno solo.
  final List<ExpedienteOpcion> opciones;

  /// Instrucción para el cliente antes de elegir el archivo.
  final String? nota;

  /// El slot acepta VARIOS documentos (anexos), cada uno su propia fila.
  final bool multiple;

  /// Anexos del slot múltiple, del más reciente al más viejo. Vacío en los
  /// demás slots, que solo tienen el vigente ([urlFirmada]).
  final List<ExpedienteAnexo> documentos;

  ExpedienteSlot.fromJson(Map<String, dynamic> j)
    : key = asString(j['key']),
      tipoId = asInt(j['tipo_id']),
      nombre = asString(j['nombre'], 'Documento'),
      requerido = j['requerido'] == true,
      estatus = asString(j['estatus'], 'pendiente'),
      fecha = j['fecha'] as String?,
      urlFirmada = j['url_firmada'] as String?,
      puedeSubir = j['puede_subir'] == true,
      soloPdf = j['solo_pdf'] == true,
      grupo = asString(j['grupo']),
      owner = asString(j['owner'], 'self'),
      multiple = j['multiple'] == true,
      documentos = ((j['documentos'] as List?) ?? [])
          .map((e) => ExpedienteAnexo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      bloqueadoMotivo = asStringOrNull(j['bloqueado_motivo']),
      opciones = ((j['opciones'] as List?) ?? [])
          .map(
            (e) => (
              tipoId: asInt((e as Map)['tipo_id']),
              label: asString(e['label']),
            ),
          )
          .toList(),
      nota = asStringOrNull(j['nota']);

  /// Slot armado en el cliente. Lo usa la fusión de la identificación oficial
  /// mientras el backend siga mandando INE y pasaporte por separado.
  const ExpedienteSlot({
    required this.key,
    required this.tipoId,
    required this.nombre,
    required this.estatus,
    this.requerido = false,
    this.fecha,
    this.urlFirmada,
    this.puedeSubir = false,
    this.soloPdf = true,
    this.grupo = '',
    this.owner = 'self',
    this.bloqueadoMotivo,
    this.opciones = const [],
    this.nota,
    this.multiple = false,
    this.documentos = const [],
  });
}

/// Un anexo de un slot múltiple ("Otros documentos"). Cada uno se ve, se
/// reemplaza y se verifica por separado.
class ExpedienteAnexo {
  final int id;
  final String estatus;
  final String? fecha;
  final String? urlFirmada;

  /// Lo que el cliente escribió para distinguir este anexo de los otros.
  final String? descripcion;

  ExpedienteAnexo.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      estatus = asString(j['estatus'], 'revision'),
      fecha = j['fecha'] as String?,
      urlFirmada = j['url_firmada'] as String?,
      descripcion = asStringOrNull(j['descripcion']);
}

class ClienteExpediente {
  final List<ExpedienteSlot> slots;
  final int requeridosTotal;
  final int requeridosAprobados;
  final int subidos;

  /// `pf` | `pm`. Cae a `pf` con el backend anterior, que es como se comportaba.
  final String tipoPersona;

  /// Vacío con el backend anterior; el app arma entonces los grupos por su
  /// cuenta (ver `ExpedienteLayout`).
  final List<ExpedienteGrupo> grupos;

  /// Solo en persona moral.
  final ExpedienteRepLegal? repLegal;

  ClienteExpediente.fromJson(Map<String, dynamic> j)
    : slots = ((j['slots'] as List?) ?? [])
          .map((e) => ExpedienteSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      requeridosTotal = asInt(j['requeridos_total']),
      requeridosAprobados = asInt(j['requeridos_aprobados']),
      subidos = asInt(j['subidos']),
      tipoPersona = asString(j['tipo_persona'], 'pf'),
      grupos = ((j['grupos'] as List?) ?? [])
          .map((e) => ExpedienteGrupo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      repLegal = j['rep_legal'] is Map
          ? ExpedienteRepLegal.fromJson(
              Map<String, dynamic>.from(j['rep_legal'] as Map),
            )
          : null;

  bool get esMoral => tipoPersona.toLowerCase().startsWith('pm');
}

/// Campo que el backend extrajo de un documento y el cliente confirma o
/// corrige antes de que el archivo se guarde.
///
/// `tipo` gobierna cómo se pinta y se valida el campo: texto | fecha | curp |
/// rfc | cp | sexo | regimen.
class CampoExtraido {
  final String key;
  final String label;
  final String? valor;
  final bool requerido;
  final String tipo;
  final bool mono;

  /// Se muestra pero no se guarda (aún no hay dónde, p. ej. actividad
  /// económica). El app lo pinta deshabilitado con su nota.
  final bool soloLectura;
  final String? ayuda;

  /// Valores a elegir cuando el backend no pudo resolver el campo contra su
  /// catálogo (régimen fiscal, principalmente).
  final List<({String id, String nombre})> opciones;

  CampoExtraido.fromJson(Map<String, dynamic> j)
    : key = asString(j['key']),
      label = asString(j['label']),
      valor = asStringOrNull(j['valor']),
      requerido = j['requerido'] == true,
      tipo = asString(j['tipo'], 'texto'),
      mono = j['mono'] == true,
      soloLectura = j['solo_lectura'] == true,
      ayuda = asStringOrNull(j['ayuda']),
      opciones = ((j['opciones'] as List?) ?? [])
          .map(
            (e) =>
                (id: asString((e as Map)['id']), nombre: asString(e['nombre'])),
          )
          .toList();
}

/// Veredicto de `cliente-expediente action=analizar`: qué se detectó en el PDF
/// sin haberlo guardado todavía.
///
/// `resultado`:
/// - `valido`     el documento pasó su validación; al confirmar queda aprobado.
/// - `sin_texto`  es un PDF real pero escaneado; al confirmar queda en
///                revisión y los campos los escribe el cliente.
/// - `rechazado`  no procede (vencido o no es ese documento). `motivo` lo dice.
class AnalisisDocumento {
  final String resultado;
  final String? motivo;

  /// Estatus que tendrá el documento al confirmar: `aprobado` | `revision`.
  final String estatusPrevisto;
  final List<CampoExtraido> campos;

  /// sha256 del archivo analizado; viaja de vuelta en `subir` para que el
  /// backend confirme que se guarda el mismo archivo que el cliente revisó.
  final String? hash;

  AnalisisDocumento.fromJson(Map<String, dynamic> j)
    : resultado = asString(j['resultado'], 'sin_texto'),
      motivo = asStringOrNull(j['motivo']),
      estatusPrevisto = asString(j['estatus_previsto'], 'revision'),
      campos = ((j['campos'] as List?) ?? [])
          .map((e) => CampoExtraido.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hash = asStringOrNull(j['hash']);

  bool get valido => resultado == 'valido';
  bool get rechazado => resultado == 'rechazado';

  /// Sin extracción utilizable: el cliente captura los campos a mano.
  bool get sinTexto => resultado == 'sin_texto';
}

// ─── cliente-menu ────────────────────────────────────────────────────────────

/// Ítem del menú del Portal del Cliente servido por la edge function
/// `cliente-menu` (submenús activos y permitidos, mismo criterio que el portal
/// web). `route` es la `vista_front_end` del portal (p.ej.
/// `/admin/portal-cliente/inicio`); la app la mapea a su ruta interna + icono.
class MenuItemDto {
  final int id;
  final String label;
  final String route;
  final int orden;

  MenuItemDto.fromJson(Map<String, dynamic> j)
    : id = asInt(j['id']),
      label = asString(j['label']),
      route = asString(j['route']),
      orden = asInt(j['orden']);
}
