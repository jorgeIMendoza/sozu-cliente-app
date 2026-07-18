import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/copropietarios_section.dart';
import '../widgets/cronograma_pagos.dart';
import '../widgets/etapa_actual_stepper.dart';
import '../widgets/fx.dart';
import '../widgets/level_map.dart';
import '../widgets/network_image.dart';
import '../widgets/payment_method_badge.dart';
import '../widgets/portal_widgets.dart';
import '../widgets/pulsing_pin.dart';
import 'como_llegar_screen.dart';
import 'pago_final_screen.dart';

/// Detalle de propiedad: datos técnicos, productos adicionales, etapa actual,
/// cronograma de pagos (tarjeta colapsable con pagos aplicados y CEP), ficha
/// técnica (LevelMap) y documentos.
class PropiedadDetalleScreen extends ConsumerStatefulWidget {
  final int cuentaId;

  const PropiedadDetalleScreen({super.key, required this.cuentaId});

  @override
  ConsumerState<PropiedadDetalleScreen> createState() =>
      _PropiedadDetalleScreenState();
}

class _PropiedadDetalleScreenState
    extends ConsumerState<PropiedadDetalleScreen> {
  /// Ancla del cronograma para el fallback de "Confirmar plan de pagos".
  final GlobalKey _cronoKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final detalle = ref.watch(propiedadDetalleProvider(widget.cuentaId));

    // Modo portal (web ≥1024): el shell (sidebar + topbar) ya envuelve la
    // pantalla; sin AppBar propio ni CTA sticky (patrón de estado_cuenta).
    if (isPortalMode(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(
            key: ValueKey(
              detalle.isLoading
                  ? 'cargando'
                  : detalle.hasError
                      ? 'error'
                      : 'datos',
            ),
            child: _portalBody(detalle),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(detalle.valueOrNull?.nombre ?? 'Propiedad')),
      // CTA sticky de pago solo en pantallas angostas (patrón del portal:
      // AcquisitionStickyCTA es md:hidden).
      bottomNavigationBar: _stickyCta(context, detalle.valueOrNull),
      // Fade suave entre skeleton → datos (sin salto al cargar).
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(
            detalle.isLoading
                ? 'cargando'
                : detalle.hasError
                    ? 'error'
                    : 'datos',
          ),
          child: _body(context, tone, detalle),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SozuTone tone,
    AsyncValue<PropiedadDetalle> detalle,
  ) {
    return detalle.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Skeleton(height: 180, radius: 16),
            SizedBox(height: 16),
            Skeleton(width: 200, height: 20),
            SizedBox(height: 16),
            Skeleton(height: 120, radius: 16),
          ],
        ),
        error: (_, __) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorCard(
              title: 'No pudimos cargar esta propiedad',
              onRetry: () =>
                  ref.invalidate(propiedadDetalleProvider(widget.cuentaId)),
            ),
          ],
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Hero (transición compartida con la imagen de la tarjeta)
            Hero(
              tag: 'prop-img-${widget.cuentaId}',
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: SozuNetworkImage(url: d.urlImagen),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Propiedad en proceso legal → modo solo lectura (paso 17):
                  // banner arriba y sin CTAs de pago en toda la pantalla.
                  if (d.enDemanda) ...[
                    const _DemandaBanner(),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.proyecto.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: tone.primaryDark,
                                )),
                            Text(d.nombre,
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: tone.textPrimary)),
                            Text('${d.modelo} · ${d.tipo}',
                                style: TextStyle(
                                    fontSize: 14, color: tone.textSecondary)),
                          ],
                        ),
                      ),
                      _estatusChip(d),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Método de pago final elegido (espejo del portal); el badge
                  // no renderiza nada si tipoFinanciamiento es null.
                  if (d.tipoFinanciamiento != null) ...[
                    PaymentMethodBadge(
                      tipoFinanciamiento: d.tipoFinanciamiento,
                      solicitud: d.solicitudCredito,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Avance
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Avance de pago · ${d.avancePagoEfectivo.round()}%',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: tone.textPrimary)),
                            Text(
                                '${formatMXN(d.pagadoEfectivo)} de ${formatMXN(d.montoEfectivo)}',
                                style: TextStyle(
                                    fontSize: 12, color: tone.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SozuProgressBar(percent: d.avancePagoEfectivo),
                        if (d.saldoPendienteEfectivo > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                'Saldo pendiente: ${formatMXN(d.saldoPendienteEfectivo)}',
                                style: TextStyle(
                                    fontSize: 12, color: tone.pending)),
                          ),
                      ],
                    ),
                  ),

                  // CTA de pago (etapa pago_final con saldo; oculto en
                  // demanda → solo lectura).
                  if (!d.enDemanda &&
                      d.etapaActivaEfectiva == 'pago_final' &&
                      d.saldoPendienteEfectivo > 0) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _pagar(context, d),
                      icon: Icon(
                          d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO'
                              ? Icons.account_balance_outlined
                              : Icons.payments_outlined,
                          size: 18),
                      label: Text(d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO'
                          ? 'Ver crédito hipotecario'
                          : 'Pagar ${formatMXN(d.saldoPendienteEfectivo)}'),
                    ),
                  ],

                  // CTA de preventa (paso 15, espejo de getContextualCTA del
                  // portal): botón secundario que lleva a pagar el siguiente
                  // acuerdo pendiente (o al cronograma si no hay pendientes).
                  if (!d.enDemanda &&
                      d.etapaActivaEfectiva == 'preventa' &&
                      d.saldoPendienteEfectivo > 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _confirmarPlan(context, d),
                      icon: const Icon(Icons.event_available_outlined,
                          size: 18),
                      label: const Text('Confirmar plan de pagos'),
                    ),
                  ],

                  // Datos técnicos
                  const SectionTitle(
                      icon: Icons.construction_outlined,
                      text: 'Datos técnicos'),
                  AppCard(
                    child: Wrap(
                      runSpacing: 12,
                      children: [
                        _dato(tone, 'PROYECTO', d.proyecto),
                        _dato(tone, 'UNIDAD', 'U-${d.unidad}'),
                        _dato(tone, 'TIPO', d.tipo),
                        _dato(
                            tone,
                            'ÁREA',
                            d.m2Interiores != null
                                ? '${d.m2Interiores} m²'
                                : '—'),
                        _dato(tone, 'RECÁMARAS', '${d.recamaras}'),
                        _dato(tone, 'BAÑOS', '${d.banos}'),
                        _dato(tone, 'PISO',
                            d.numeroPiso != null ? '${d.numeroPiso}' : '—'),
                        _dato(tone, 'ENTREGA', d.entrega),
                      ],
                    ),
                  ),

                  // Copropietarios (solo si la cuenta tiene más de un
                  // propietario; el widget se oculta solo en caso contrario).
                  CopropietariosSection(copropietarios: d.copropietarios),

                  // Ubicación del proyecto (solo si tiene coordenadas)
                  if (d.ubicacion != null)
                    _UbicacionSection(
                      ubicacion: d.ubicacion!,
                      proyecto: d.proyecto,
                    ),

                  // Productos adicionales
                  if (d.productos.isNotEmpty) ...[
                    SectionTitle(
                        icon: Icons.inventory_2_outlined,
                        text: 'Productos adicionales · ${d.productos.length}'),
                    for (final p in d.productos) ...[
                      _ProductoRow(p: p),
                      const SizedBox(height: 10),
                    ],
                  ],

                  // Etapa actual (stepper estilo portal del cliente)
                  EtapaActualStepper(
                    stages: d.stagesEfectivos,
                    activa: d.etapaActivaEfectiva,
                    saldoPendiente: d.saldoPendienteEfectivo,
                  ),

                  // Cronograma de pagos (tarjeta colapsable estilo portal
                  // del cliente, con pagos aplicados y CEP por concepto).
                  KeyedSubtree(
                    key: _cronoKey,
                    child: CronogramaPagos(esquemaPago: d.esquemaPago),
                  ),

                  // Ficha técnica
                  if (d.ficha.numeroPiso != null ||
                      d.ficha.planoNivelUrl != null ||
                      d.ficha.planoDistribucionUrl != null ||
                      d.ficha.regiones.isNotEmpty)
                    _FichaTecnica(ficha: d.ficha),

                  // Documentos
                  const SectionTitle(
                      icon: Icons.description_outlined, text: 'Documentos'),
                  if (d.documentos.isEmpty)
                    const EmptyCard(
                        icon: Icons.folder_open_outlined,
                        text: 'Sin documentos para esta propiedad')
                  else
                    for (final doc in d.documentos) ...[
                      _DocRow(d: doc),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
    );
  }

  /// Routing del botón Pagar (espejo del portal admin): primera vez en el
  /// último pago → panel "Pago final" (elegir método); crédito hipotecario ya
  /// elegido → estatus del crédito; en cualquier otro caso → instrucciones
  /// STP del siguiente acuerdo pendiente.
  void _pagar(BuildContext context, PropiedadDetalle d) {
    final pendientes = d.esquemaPago.where((e) => !e.pagoCompletado).toList();
    final siguiente = pendientes.firstOrNull;
    final esUltimoPago = pendientes.length == 1;
    if ((esUltimoPago && d.tipoFinanciamiento == null) ||
        d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PagoFinalScreen(
            cuentaId: widget.cuentaId,
            unidad: d.unidad,
            proyecto: d.proyecto,
            saldo: d.saldoPendienteEfectivo,
            acuerdoId: siguiente?.id,
            tipoFinanciamiento: d.tipoFinanciamiento,
            solicitud: d.solicitudCredito,
          ),
        ),
      );
    } else if (siguiente != null) {
      context.push('/pagar?id=${siguiente.id}');
    }
  }

  /// CTA de preventa: lleva a las instrucciones de pago del siguiente acuerdo
  /// pendiente (lo mismo que hace el portal al confirmar el plan); si no hay
  /// acuerdos pendientes, hace scroll al cronograma para revisarlo.
  void _confirmarPlan(BuildContext context, PropiedadDetalle d) {
    final siguiente =
        d.esquemaPago.where((e) => !e.pagoCompletado).firstOrNull;
    if (siguiente != null) {
      context.push('/pagar?id=${siguiente.id}');
    } else if (_cronoKey.currentContext != null) {
      Scrollable.ensureVisible(
        _cronoKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Barra sticky inferior con el CTA principal (solo pantallas angostas,
  /// espejo de AcquisitionStickyCTA del portal). Null si no aplica: pantalla
  /// ancha, sin datos, en demanda o etapa sin CTA de pago.
  Widget? _stickyCta(BuildContext context, PropiedadDetalle? d) {
    if (d == null || d.enDemanda) return null;
    if (MediaQuery.of(context).size.width >= 700) return null;

    Widget? boton;
    if (d.etapaActivaEfectiva == 'pago_final' &&
        d.saldoPendienteEfectivo > 0) {
      final esCredito = d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO';
      boton = FilledButton.icon(
        onPressed: () => _pagar(context, d),
        icon: Icon(
            esCredito
                ? Icons.account_balance_outlined
                : Icons.payments_outlined,
            size: 18),
        label: Text(esCredito
            ? 'Ver crédito hipotecario'
            : 'Pagar ${formatMXN(d.saldoPendienteEfectivo)}'),
      );
    } else if (d.etapaActivaEfectiva == 'preventa' &&
        d.saldoPendienteEfectivo > 0) {
      boton = FilledButton.icon(
        onPressed: () => _confirmarPlan(context, d),
        icon: const Icon(Icons.event_available_outlined, size: 18),
        label: const Text('Confirmar plan de pagos'),
      );
    }
    if (boton == null) return null;

    final tone = SozuTone.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border(top: BorderSide(color: tone.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(top: false, child: boton),
    );
  }

  /// Chip de estatus de la cabecera derivado de la etapa activa, como el
  /// portal (getStageInfo de PropertyAcquisitionDetail): NUNCA el estatus
  /// crudo de disponibilidad de la BD, que puede decir "Pagada completamente"
  /// o "Vendida" aunque la cuenta tenga saldo pendiente.
  Widget _estatusChip(PropiedadDetalle d) {
    final (label, tone) = switch (d.etapaActivaEfectiva) {
      'preventa' => ('En Preventa', BadgeTone.neutral),
      // Ámbar, como el chip "Pago Pendiente" del portal.
      'pago_final' => ('Pago Pendiente', BadgeTone.pending),
      'escrituracion' => ('En Escrituración', BadgeTone.neutral),
      'entrega' => ('Por Entregar', BadgeTone.positive),
      'post_entrega' => ('Entregada', BadgeTone.positive),
      _ => (
          d.estatus,
          d.categoria == 'patrimonio' ? BadgeTone.positive : BadgeTone.neutral,
        ),
    };
    return StatusBadge(label: label, tone: tone);
  }

  Widget _dato(SozuTone tone, String label, String value) {
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, letterSpacing: 0.8, color: tone.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone.textPrimary)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODO PORTAL (web ≥1024): réplica del detalle de propiedad del Portal del
  // Cliente (PropertyAcquisitionDetail.tsx del admin): header fuera de cards
  // ("PROPIEDAD · U-X" + nombre grande + chip de etapa) y grid de 2 columnas
  // (contenido 1fr + lateral 300). Solo capa visual: reutiliza el provider,
  // los widgets (EtapaActualStepper, CronogramaPagos, PaymentMethodBadge,
  // CopropietariosSection) y las acciones existentes (_pagar/_confirmarPlan).
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _portalBody(AsyncValue<PropiedadDetalle> detalle) {
    return detalle.when(
      loading: () => ListView(
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        children: const [
          Skeleton(width: 320, height: 28, radius: 8),
          SizedBox(height: 20),
          Skeleton(height: 320, radius: 24),
          SizedBox(height: 16),
          Skeleton(height: 160, radius: 24),
        ],
      ),
      error: (_, __) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          ErrorCard(
            title: 'No pudimos cargar esta propiedad',
            onRetry: () =>
                ref.invalidate(propiedadDetalleProvider(widget.cuentaId)),
          ),
        ],
      ),
      data: (d) => _portalContenido(d),
    );
  }

  Widget _portalContenido(PropiedadDetalle d) {
    // ── Columna izquierda (mismo orden que el TSX) ──
    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 0 · Forma de pago final elegida (banner verde; se oculta solo si
        // tipoFinanciamiento es null, misma condición que la vista móvil).
        if (d.tipoFinanciamiento != null) ...[
          PaymentMethodBadge(
            portal: true,
            tipoFinanciamiento: d.tipoFinanciamiento,
            solicitud: d.solicitudCredito,
          ),
          const SizedBox(height: 16),
        ],

        // 1 · Imagen de la propiedad (galería del portal; el backend del app
        // expone una sola foto — clic abre el visor a pantalla completa).
        _portalImagen(d),

        // 2 · Productos adicionales
        if (d.productos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _portalProductos(d),
        ],

        // 3 · Etapa actual (stepper compartido, contenedor portal)
        const SizedBox(height: 16),
        EtapaActualStepper(
          portal: true,
          stages: d.stagesEfectivos,
          activa: d.etapaActivaEfectiva,
          saldoPendiente: d.saldoPendienteEfectivo,
        ),

        // 4 · Cronograma de pagos (misma ancla para "Confirmar plan")
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _cronoKey,
          child: CronogramaPagos(portal: true, esquemaPago: d.esquemaPago),
        ),

        // 5 · Documentos
        const SizedBox(height: 16),
        _portalDocumentos(d),

        // 6 · Ficha técnica
        if (d.ficha.numeroPiso != null ||
            d.ficha.planoNivelUrl != null ||
            d.ficha.planoDistribucionUrl != null ||
            d.ficha.regiones.isNotEmpty) ...[
          const SizedBox(height: 16),
          _FichaTecnica(ficha: d.ficha, portal: true),
        ],

        // 7 · Copropietarios (el portal admin no los pinta: van al final)
        if (d.copropietarios.length >= 2) ...[
          const SizedBox(height: 16),
          CopropietariosSection(
            portal: true,
            copropietarios: d.copropietarios,
          ),
        ],

        // 8 · Ubicación con mapa (el portal no trae mapa: cierra la columna)
        if (d.ubicacion != null) ...[
          const SizedBox(height: 16),
          _UbicacionSection(
            portal: true,
            ubicacion: d.ubicacion!,
            proyecto: d.proyecto,
          ),
        ],
      ],
    );

    // ── Columna derecha (lateral 340 del TSX) ──
    final derecha = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _portalPrecioCompra(d),
        const SizedBox(height: 16),
        _portalDatosTecnicos(d),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Propiedad en proceso legal → banner de solo lectura (los CTAs de
          // pago ya se ocultan con la misma condición que en móvil).
          if (d.enDemanda) ...[
            _portalDemandaBanner(),
            const SizedBox(height: 16),
          ],
          _portalHeader(d),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, cons) {
              // Grid 1fr + 300 con gap 24 (md:grid-cols-[1fr_300px] del TSX,
              // igual que Pagos y Productos); si el contenido queda angosto
              // la columna lateral cae debajo (patrón md: del TSX).
              if (cons.maxWidth < kTwoColBreakpoint) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [izquierda, const SizedBox(height: 16), derecha],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: izquierda),
                  const SizedBox(width: 24),
                  SizedBox(width: 300, child: derecha),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Header fuera de cards: "PROPIEDAD · U-X" + nombre + chip + dirección ──
  Widget _portalHeader(PropiedadDetalle d) {
    final direccion = d.ubicacion?.direccion?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPIEDAD · U-${d.unidad}',
          style: portalText(
            size: 10,
            weight: FontWeight.w600,
            color: PortalColors.mutedForeground,
            letterSpacing: 2, // tracking-[0.2em]
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: d.proyecto,
                      style: portalText(
                        size: 28,
                        weight: FontWeight.w700,
                        letterSpacing: -0.7,
                        height: 1.15,
                      ),
                    ),
                    TextSpan(
                      text: ' · U-${d.unidad}',
                      style: portalText(
                        size: 28,
                        color: PortalColors.mutedForeground,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _portalStageChip(d),
            ),
          ],
        ),
        if (direccion != null && direccion.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: PortalColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  direccion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Chip de etapa del header (getStageInfo del portal): derivado de la
  /// etapa activa efectiva, nunca del estatus crudo de la BD.
  Widget _portalStageChip(PropiedadDetalle d) {
    final (label, bg, fg) = switch (d.etapaActivaEfectiva) {
      'preventa' => (
          'En Preventa',
          PortalColors.primarySoft10,
          PortalColors.primary,
        ),
      'pago_final' => (
          'Pago Pendiente',
          PortalColors.warningSoft15,
          PortalColors.warning,
        ),
      'escrituracion' => (
          'En Escrituración',
          PortalColors.primarySoft15,
          PortalColors.primary,
        ),
      'entrega' => (
          'Por Entregar',
          PortalColors.primarySoft15,
          PortalColors.primary,
        ),
      'post_entrega' => (
          'Entregada',
          PortalColors.primarySoft15,
          PortalColors.primary,
        ),
      _ => (d.estatus, PortalColors.muted, PortalColors.mutedForeground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: portalText(size: 11, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  /// Banner "en proceso legal" estilo portal (ámbar, radio 16).
  Widget _portalDemandaBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PortalColors.warningSoft10,
        borderRadius: BorderRadius.circular(kPortalRadiusLg),
        border: Border.all(
          color: PortalColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.gavel_outlined,
            size: 16,
            color: PortalColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Propiedad en proceso legal — modo solo lectura',
              style: portalText(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Imagen principal (PropertyImage del portal): aspect-video con radio de
  /// card; clic abre el visor a pantalla completa (lightbox).
  Widget _portalImagen(PropiedadDetalle d) {
    final url = d.urlImagen;
    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(kPortalRadiusCard),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: SozuNetworkImage(url: url),
      ),
    );
    if (url == null || url.isEmpty) return imagen;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            openMedia(context, url, titulo: '${d.proyecto} · U-${d.unidad}'),
        child: imagen,
      ),
    );
  }

  // ── Productos adicionales (card única con filas, estilo portal) ──
  Widget _portalProductos(PropiedadDetalle d) {
    return PortalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: PortalColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              PortalSectionLabel(
                'Productos adicionales · ${d.productos.length}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < d.productos.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: PortalColors.border),
            _portalProductoRow(d.productos[i]),
          ],
        ],
      ),
    );
  }

  Widget _portalProductoRow(ProductoDetalle p) {
    final (bg, fg) = switch (p.estatus) {
      'Pagado' => (PortalColors.primarySoft10, PortalColors.primary),
      'En curso' => (PortalColors.muted, PortalColors.mutedForeground),
      _ => (PortalColors.warningSoft10, PortalColors.warning),
    };
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => context.push('/productos/${p.id}'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: hovered ? PortalColors.mutedHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: PortalColors.primarySoft10,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: PortalColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    PortalStatusChip(
                      label: p.estatus,
                      background: bg,
                      foreground: fg,
                      small: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMXN(p.monto),
                style: portalText(
                  size: 13,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: PortalColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Documentos (card única con filas, estilo portal) ──
  Widget _portalDocumentos(PropiedadDetalle d) {
    return PortalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: PortalColors.mutedForeground,
              ),
              SizedBox(width: 8),
              PortalSectionLabel('Documentos'),
            ],
          ),
          if (d.documentos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Center(
                child: Text(
                  'Sin documentos para esta propiedad',
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            for (var i = 0; i < d.documentos.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: PortalColors.border),
              _portalDocRow(d.documentos[i]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _portalDocRow(DocumentoItem doc) {
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => openMedia(context, doc.urlFirmada, titulo: doc.nombre),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: hovered ? PortalColors.mutedHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: PortalColors.primarySoft10,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: PortalColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 13, weight: FontWeight.w600),
                    ),
                    Text(
                      '${doc.tipo} · ${formatDate(doc.fecha)}',
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new,
                size: 14,
                color: PortalColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card financiero "PRECIO DE COMPRA" (FinancialSideCard del portal) ──
  Widget _portalPrecioCompra(PropiedadDetalle d) {
    final progreso = (d.avancePagoEfectivo / 100).clamp(0.0, 1.0).toDouble();
    final cta = _portalCta(d);
    return PortalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionLabel('Precio de compra', size: 10),
          const SizedBox(height: 2),
          Text(
            formatMXN(d.montoEfectivo),
            style: portalText(
              size: 26,
              weight: FontWeight.w700,
              tabular: true,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${d.avancePagoEfectivo.round()}% pagado',
                style: portalText(
                  size: 10,
                  color: PortalColors.mutedForeground,
                ),
              ),
              Text(
                '${formatMXN(d.saldoPendienteEfectivo)} restante',
                style: portalText(
                  size: 10,
                  color: PortalColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: PortalColors.muted,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progreso,
                child: Container(color: PortalColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PortalColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PortalSectionLabel('Pagado', size: 10),
                      const SizedBox(height: 2),
                      Text(
                        formatMXN(d.pagadoEfectivo),
                        style: portalText(
                          size: 13,
                          weight: FontWeight.w600,
                          color: PortalColors.primary,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const PortalSectionLabel('Restante', size: 10),
                      const SizedBox(height: 2),
                      Text(
                        formatMXN(d.saldoPendienteEfectivo),
                        style: portalText(
                          size: 13,
                          weight: FontWeight.w600,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (d.entrega.trim().isNotEmpty && d.entrega != '—') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: PortalColors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Entrega: ',
                          style: portalText(
                            size: 11,
                            color: PortalColors.mutedForeground,
                          ),
                        ),
                        TextSpan(
                          text: d.entrega,
                          style: portalText(
                            size: 11,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (cta != null) ...[
            const SizedBox(height: 16),
            cta,
          ],
        ],
      ),
    );
  }

  /// CTA contextual del card financiero (getContextualCTA del portal):
  /// mismas condiciones de visibilidad que la vista móvil (nunca en demanda).
  Widget? _portalCta(PropiedadDetalle d) {
    if (d.enDemanda) return null;
    if (d.etapaActivaEfectiva == 'pago_final' &&
        d.saldoPendienteEfectivo > 0) {
      final esCredito = d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO';
      return _PortalCtaButton(
        label: esCredito
            ? 'Ver crédito hipotecario'
            : 'Pagar ${formatMXN(d.saldoPendienteEfectivo)}',
        icon: esCredito
            ? Icons.account_balance_outlined
            : Icons.payments_outlined,
        background: esCredito ? PortalColors.primary : PortalColors.warning,
        hoverBackground: esCredito ? PortalColors.primaryHover : null,
        onPressed: () => _pagar(context, d),
      );
    }
    if (d.etapaActivaEfectiva == 'preventa' && d.saldoPendienteEfectivo > 0) {
      return _PortalCtaButton(
        label: 'Confirmar plan de pagos',
        icon: Icons.event_available_outlined,
        background: PortalColors.primary,
        hoverBackground: PortalColors.primaryHover,
        onPressed: () => _confirmarPlan(context, d),
      );
    }
    return null;
  }

  // ── Card "DATOS TÉCNICOS" (TechnicalSideCard del portal) ──
  Widget _portalDatosTecnicos(PropiedadDetalle d) {
    final celdas = <(String, String)>[
      ('Proyecto', d.proyecto),
      ('Unidad', 'U-${d.unidad}'),
      ('Tipo', d.tipo),
      ('Área', d.m2Interiores != null ? '${d.m2Interiores} m²' : '—'),
      ('Recámaras', '${d.recamaras}'),
      ('Baños', '${d.banos}'),
      ('Piso', d.numeroPiso != null ? '${d.numeroPiso}' : '—'),
      ('Entrega', d.entrega),
    ];
    return PortalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.apartment_outlined,
                size: 14,
                color: PortalColors.mutedForeground,
              ),
              SizedBox(width: 8),
              PortalSectionLabel('Datos técnicos'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            runSpacing: 14,
            children: [
              for (final (label, valor) in celdas)
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PortalSectionLabel(label, size: 10),
                      const SizedBox(height: 2),
                      Text(
                        valor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(size: 12, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner de propiedad en proceso legal (paso 17, espejo del overlay
/// "En demanda · Modo solo lectura" del portal): informa y acompaña la
/// ocultación de todos los CTAs de pago.
class _DemandaBanner extends StatelessWidget {
  const _DemandaBanner();

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.pendingSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SozuColors.amber500.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_outlined,
              size: 18, color: SozuColors.amber600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Propiedad en proceso legal — modo solo lectura',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tone.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UbicacionSection extends StatelessWidget {
  final PropiedadUbicacion ubicacion;
  final String proyecto;

  /// true en modo portal web: PortalCard con label uppercase y botones del
  /// portal; la vista móvil queda idéntica.
  final bool portal;

  const _UbicacionSection({
    required this.ubicacion,
    required this.proyecto,
    this.portal = false,
  });

  LatLng get _punto => LatLng(ubicacion.latitud, ubicacion.longitud);

  Future<void> _abrirEnGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${ubicacion.latitud},${ubicacion.longitud}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Abre el mapa embebido con GPS + ruta (compartido móvil/portal).
  void _abrirComoLlegar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComoLlegarScreen(
          destinoLat: ubicacion.latitud,
          destinoLng: ubicacion.longitud,
          nombre: proyecto,
          direccion: ubicacion.direccion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final mapa = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: portal ? 260 : 180,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _punto,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sozu.sozuClienteApp',
            ),
            MarkerLayer(
              markers: [
                // Pin con efecto de respiración (halo que crece y
                // se desvanece en loop); alineación center = punta
                // del pin sobre la coordenada.
                Marker(
                  point: _punto,
                  width: PulsingPin.lado,
                  height: PulsingPin.lado,
                  child: const PulsingPin(),
                ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('© OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );

    // ── Modo portal: PortalCard con label uppercase y botones del portal ──
    if (portal) {
      final direccion = ubicacion.direccion?.trim();
      return PortalCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: PortalColors.mutedForeground,
                ),
                SizedBox(width: 8),
                PortalSectionLabel('Ubicación'),
              ],
            ),
            const SizedBox(height: 12),
            mapa,
            if (direccion != null && direccion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                direccion,
                style: portalText(
                  size: 12,
                  color: PortalColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                PortalPrimaryButton(
                  label: 'Cómo llegar',
                  icon: Icons.directions_outlined,
                  onPressed: () => _abrirComoLlegar(context),
                ),
                const SizedBox(width: 10),
                PortalOutlineButton(
                  label: 'Abrir en Maps',
                  icon: Icons.map_outlined,
                  onPressed: _abrirEnGoogleMaps,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(icon: Icons.place_outlined, text: 'Ubicación'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mapa,
              if (ubicacion.direccion != null &&
                  ubicacion.direccion!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  ubicacion.direccion!,
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  // Mapa embebido con GPS + ruta (todas las plataformas; en
                  // web usa la geolocalización del navegador).
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ComoLlegarScreen(
                            destinoLat: ubicacion.latitud,
                            destinoLng: ubicacion.longitud,
                            nombre: proyecto,
                            direccion: ubicacion.direccion,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 18),
                      label: const Text('Cómo llegar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _abrirEnGoogleMaps,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Abrir en Maps'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductoRow extends StatelessWidget {
  final ProductoDetalle p;

  const _ProductoRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final badgeTone = switch (p.estatus) {
      'Pagado' => BadgeTone.positive,
      'En curso' => BadgeTone.neutral,
      _ => BadgeTone.pending,
    };
    return PressableScale(
      onTap: () => context.push('/productos/${p.id}'),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: tone.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 18, color: SozuColors.emerald600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
                  const SizedBox(height: 4),
                  StatusBadge(label: p.estatus, tone: badgeTone),
                ],
              ),
            ),
            Text(formatMXN(p.monto),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: tone.textMuted),
          ],
        ),
      ),
    );
  }
}

class _FichaTecnica extends StatelessWidget {
  final FichaTecnica ficha;

  /// true en modo portal web: PortalCard (radio 24, sin sombra) con el label
  /// uppercase dentro de la card; la vista móvil queda idéntica.
  final bool portal;

  const _FichaTecnica({required this.ficha, this.portal = false});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final contenido = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubicación, nivel y distribución de tu unidad'
                '${ficha.modelo != '—' ? ' · Modelo ${ficha.modelo}' : ''}',
                style: TextStyle(fontSize: 12, color: tone.textSecondary),
              ),
              if (ficha.numeroDepa != null || ficha.numeroPiso != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (ficha.numeroDepa != null) 'Unidad ${ficha.numeroDepa}',
                    if (ficha.numeroPiso != null)
                      'Nivel ${ficha.numeroPiso}${ficha.totalPisos != null ? ' de ${ficha.totalPisos}' : ''}',
                    if (ficha.m2Total != null) '${ficha.m2Total} m²',
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.textPrimary),
                ),
              ],
              // Ubicación en el nivel: mapa interactivo o imagen.
              if (ficha.regiones.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('UBICACIÓN EN EL NIVEL',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                        color: tone.textMuted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tone.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tone.border),
                  ),
                  child: LevelMap(
                      regiones: ficha.regiones, numeroDepa: ficha.numeroDepa),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: SozuColors.emerald500,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text('Tu unidad',
                        style: TextStyle(
                            fontSize: 11, color: tone.textSecondary)),
                  ],
                ),
              ] else if (ficha.planoNivelUrl != null) ...[
                const SizedBox(height: 12),
                _planoImage(context, tone, 'UBICACIÓN EN EL NIVEL',
                    ficha.planoNivelUrl!),
              ],
              if (ficha.planoDistribucionUrl != null) ...[
                const SizedBox(height: 12),
                _planoImage(
                    context, tone, 'DISTRIBUCIÓN', ficha.planoDistribucionUrl!),
              ],
            ],
          );

    if (portal) {
      return PortalCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 14,
                  color: PortalColors.mutedForeground,
                ),
                SizedBox(width: 8),
                PortalSectionLabel('Ficha técnica de tu propiedad'),
              ],
            ),
            const SizedBox(height: 12),
            contenido,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
            icon: Icons.map_outlined, text: 'Ficha técnica de tu propiedad'),
        AppCard(child: contenido),
      ],
    );
  }

  Widget _planoImage(
      BuildContext context, SozuTone tone, String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: tone.textMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => openMedia(context, url, titulo: label),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: tone.surfaceAlt,
              height: 200,
              width: double.infinity,
              child: SozuNetworkImage(
                url: url,
                fit: BoxFit.contain,
                placeholderIcon: Icons.image_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  final DocumentoItem d;

  const _DocRow({required this.d});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return PressableScale(
      onTap: () => openMedia(context, d.urlFirmada, titulo: d.nombre),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: tone.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.description_outlined,
                  size: 18, color: SozuColors.emerald600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
                  Text('${d.tipo} · ${formatDate(d.fecha)}',
                      style:
                          TextStyle(fontSize: 12, color: tone.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 18, color: SozuColors.emerald600),
          ],
        ),
      ),
    );
  }
}

/// CTA de ancho completo del card financiero del portal (botón h-40,
/// rounded-xl, texto 13 semibold blanco): "Pagar $X" (ámbar), "Ver crédito
/// hipotecario" o "Confirmar plan de pagos" (verdes).
class _PortalCtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color? hoverBackground;
  final VoidCallback onPressed;

  const _PortalCtaButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.onPressed,
    this.hoverBackground,
  });

  @override
  Widget build(BuildContext context) {
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered
                ? (hoverBackground ?? background.withValues(alpha: 0.9))
                : background,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: portalText(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
