import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/shared/components/open_media.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/features/client/properties/components/building_diagram.dart';
import 'package:sozu_cliente_app/features/client/properties/components/copropietarios_section.dart';
import 'package:sozu_cliente_app/features/client/properties/components/credito_hipotecario_drawer.dart';
import 'package:sozu_cliente_app/features/client/properties/components/cronograma_pagos.dart';
import 'package:sozu_cliente_app/features/client/properties/components/etapa_actual_stepper.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/features/client/properties/components/payment_method_badge.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';
import 'package:sozu_cliente_app/features/client/properties/components/pulsing_pin.dart';
import 'package:sozu_cliente_app/widgets/whatsapp_icon.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/como_llegar_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/screens/pago_final_screen.dart';
import 'package:sozu_cliente_app/features/client/properties/services/escrituracion.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Pestañas del detalle en modo portal.
enum _DetailTab { pagos, obra, docs, ficha }

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

  /// Pestaña activa del detalle en modo portal (default "Pagos").
  _DetailTab _portalTab = _DetailTab.pagos;

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final detalle = ref.watch(propertyDetailProvider(widget.cuentaId));

    // Modo portal (web ≥1024): el shell (sidebar + topbar) ya envuelve la
    // pantalla; sin AppBar propio ni CTA sticky (patrón de estado_cuenta).
    if (isPortalMode(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          // Cruce skeleton -> datos del cuerpo completo: superficie de pantalla
          // entera, el único caso que se puede permitir `slow`.
          duration: context.s.motion.slow,
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
      // CTA sticky de pago solo en pantallas angostas.
      bottomNavigationBar: _stickyCta(context, detalle.valueOrNull),
      // Fade suave entre skeleton → datos (sin salto al cargar).
      body: AnimatedSwitcher(
        duration: context.s.motion.slow,
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
    SozuColorRoles tone,
    AsyncValue<PropiedadDetalle> detalle,
  ) {
    return detalle.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SSkeleton(height: 180, radius: 16),
          SizedBox(height: 16),
          SSkeleton(width: 200, height: 20),
          SizedBox(height: 16),
          SSkeleton(height: 120, radius: 16),
        ],
      ),
      error: (_, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SErrorState(
            title: 'No pudimos cargar esta propiedad',
            onRetry: () =>
                ref.invalidate(propertyDetailProvider(widget.cuentaId)),
          ),
        ],
      ),
      data: (d) => ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Hero (transición compartida con la imagen de la tarjeta). Si el
          // backend manda galería, se reemplaza por un carrusel (mismo alto).
          if (d.galeria.isEmpty)
            Hero(
              tag: 'prop-img-${widget.cuentaId}',
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: SNetworkImage(url: d.urlImagen),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _GaleriaCarrusel(
                fotos: _galeriaItems(d),
                titulo: '${d.proyecto} · U-${d.unidad}',
                radius: 16,
                height: 200,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Propiedad en proceso legal → modo solo lectura:
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
                          Text(
                            d.proyecto.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: tone.primaryHover,
                            ),
                          ),
                          Text(
                            d.nombre,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: tone.fg,
                            ),
                          ),
                          Text(
                            '${d.modelo} · ${d.tipo}',
                            style: TextStyle(fontSize: 14, color: tone.fgMuted),
                          ),
                        ],
                      ),
                    ),
                    _estatusChip(d),
                  ],
                ),
                const SizedBox(height: 16),

                // Método de pago final elegido; el badge
                // no renderiza nada si tipoFinanciamiento es null.
                if (d.tipoFinanciamiento != null) ...[
                  PaymentMethodBadge(
                    tipoFinanciamiento: d.tipoFinanciamiento,
                    solicitud: d.solicitudCredito,
                  ),
                  const SizedBox(height: 12),
                ],

                // Avance
                SCard(
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
                              color: tone.fg,
                            ),
                          ),
                          Text(
                            '${formatMXN(d.pagadoEfectivo)} de ${formatMXN(d.montoEfectivo)}',
                            style: TextStyle(fontSize: 12, color: tone.fgMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SProgressBar(
                        thickness: SProgressBarThickness.thick,
                        percent: d.avancePagoEfectivo,
                      ),
                      if (d.saldoPendienteEfectivo > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Saldo pendiente: ${formatMXN(d.saldoPendienteEfectivo)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: tone.warningFg,
                            ),
                          ),
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
                      size: 18,
                    ),
                    label: Text(
                      d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO'
                          ? 'Ver crédito hipotecario'
                          : 'Pagar ${formatMXN(d.saldoPendienteEfectivo)}',
                    ),
                  ),
                ],

                // CTA de preventa: botón secundario que lleva a pagar el
                // siguiente acuerdo pendiente, o al cronograma si no hay.
                if (!d.enDemanda &&
                    d.etapaActivaEfectiva == 'preventa' &&
                    d.saldoPendienteEfectivo > 0) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _confirmarPlan(context, d),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Confirmar plan de pagos'),
                  ),
                ],

                // Datos técnicos
                const SSectionLabel.heading(
                  icon: Icons.construction_outlined,
                  text: 'Datos técnicos',
                ),
                SCard(
                  child: Wrap(
                    runSpacing: 12,
                    children: [
                      _dato(tone, 'PROYECTO', d.proyecto),
                      _dato(tone, 'UNIDAD', 'U-${d.unidad}'),
                      _dato(tone, 'TIPO', d.tipo),
                      _dato(
                        tone,
                        'ÁREA',
                        d.m2Interiores != null ? '${d.m2Interiores} m²' : '-',
                      ),
                      _dato(tone, 'RECÁMARAS', '${d.recamaras}'),
                      _dato(tone, 'BAÑOS', '${d.banos}'),
                      _dato(
                        tone,
                        'PISO',
                        d.numeroPiso != null ? '${d.numeroPiso}' : '-',
                      ),
                      _dato(tone, 'ENTREGA', d.entrega),
                    ],
                  ),
                ),

                // Productos adicionales
                if (d.productos.isNotEmpty) ...[
                  SSectionLabel.heading(
                    icon: Icons.inventory_2_outlined,
                    text: 'Productos adicionales · ${d.productos.length}',
                  ),
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

                // Pestañas (Pagos · Avance de obra · Documentos · Ficha),
                // igual que el modo portal: en vez de apilar todas las
                // secciones verticalmente, el resto del detalle (cronograma,
                // avance de obra, documentos y ficha/ubicación/copropietarios)
                // vive dentro de su pestaña.
                const SizedBox(height: 16),
                _portalTabBar(),
                const SizedBox(height: 16),
                _mobileTabContent(context, tone, d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Contenido de la pestaña activa en modo MÓVIL (mismo mapeo canónico de las
  /// 4 pestañas que `_portalTabContent`, pero con las variantes móviles de cada
  /// sección: sin `portal: true`).
  Widget _mobileTabContent(
    BuildContext context,
    SozuColorRoles tone,
    PropiedadDetalle d,
  ) {
    switch (_portalTab) {
      // Pagos → cronograma (misma ancla para "Confirmar plan de pagos").
      case _DetailTab.pagos:
        return KeyedSubtree(
          key: _cronoKey,
          child: CronogramaPagos(esquemaPago: d.esquemaPago),
        );

      // Avance de obra → video (si hay) + card de datos del backend; si aún no
      // hay datos ni video, empty state discreto (misma lógica que el portal).
      case _DetailTab.obra:
        final videoUrl = d.videoObraUrl?.trim();
        final tieneVideo = videoUrl != null && videoUrl.isNotEmpty;
        final secciones = <Widget>[
          if (tieneVideo) _portalVideoObra(videoUrl),
          if (d.avanceObra != null)
            _portalAvanceObra(d.avanceObra!)
          else if (!tieneVideo)
            _portalAvanceObraVacio(),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < secciones.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              secciones[i],
            ],
          ],
        );

      // Documentos → misma lista de documentos que ya usa la vista móvil.
      case _DetailTab.docs:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SSectionLabel.heading(
              icon: Icons.description_outlined,
              text: 'Documentos',
            ),
            if (d.documentos.isEmpty)
              const SEmptyState.card(
                icon: Icons.folder_open_outlined,
                title: 'Sin documentos para esta propiedad',
              )
            else
              for (final doc in d.documentos) ...[
                _DocRow(d: doc),
                const SizedBox(height: 10),
              ],
          ],
        );

      // Ficha técnica → ficha + ubicación (si hay coordenadas) + copropietarios
      // (el widget se oculta solo si la cuenta no tiene copropiedad), variantes
      // móviles con las mismas condiciones de visibilidad que hoy.
      case _DetailTab.ficha:
        final tieneFicha =
            d.ficha.numeroPiso != null ||
            d.ficha.planoNivelUrl != null ||
            d.ficha.planoDistribucionUrl != null ||
            d.ficha.regiones.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tieneFicha) _FichaTecnica(ficha: d.ficha),
            if (d.ubicacion != null)
              _UbicacionSection(ubicacion: d.ubicacion!, proyecto: d.proyecto),
            CopropietariosSection(copropietarios: d.copropietarios),
          ],
        );
    }
  }

  /// Routing del botón Pagar: primera vez en el último pago → "Pago final";
  /// crédito hipotecario ya elegido → estatus del crédito; si no →
  /// instrucciones STP del siguiente acuerdo pendiente.
  void _pagar(BuildContext context, PropiedadDetalle d) {
    final pendientes = d.esquemaPago.where((e) => !e.pagoCompletado).toList();
    final siguiente = pendientes.firstOrNull;
    final esUltimoPago = pendientes.length == 1;
    if ((esUltimoPago && d.tipoFinanciamiento == null) ||
        d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO') {
      // Modo portal (web ancho): panel lateral derecho (drawer) estilo
      // PagoFinalSheet, en vez de la pantalla completa. En móvil/angosto se
      // conserva la pantalla completa.
      if (isPortalMode(context)) {
        showCreditoHipotecarioDrawer(
          context,
          cuentaId: widget.cuentaId,
          unidad: d.unidad,
          proyecto: d.proyecto,
          saldo: d.saldoPendienteEfectivo,
          acuerdoId: siguiente?.id,
          tipoFinanciamiento: d.tipoFinanciamiento,
          solicitud: d.solicitudCredito,
          agente: d.agente,
          onRecursosPropios: (acuerdoId) {
            if (acuerdoId != null) context.push('/pagar?id=$acuerdoId');
          },
        );
        return;
      }
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
    final siguiente = d.esquemaPago.where((e) => !e.pagoCompletado).firstOrNull;
    if (siguiente != null) {
      context.push('/pagar?id=${siguiente.id}');
    } else if (_cronoKey.currentContext != null) {
      Scrollable.ensureVisible(
        _cronoKey.currentContext!,
        // Recorre distancia (scroll hasta la sección), de ahí `emphasized`:
        // frena largo y se lee como que la página se acomoda, no como un salto.
        duration: context.s.motion.slow,
        curve: context.s.motion.emphasized,
      );
    }
  }

  /// Barra sticky inferior con el CTA principal, solo en pantallas angostas.
  /// Null si no aplica: pantalla ancha, sin datos, en demanda o etapa sin CTA.
  Widget? _stickyCta(BuildContext context, PropiedadDetalle? d) {
    if (d == null || d.enDemanda) return null;
    if (MediaQuery.of(context).size.width >= 700) return null;

    Widget? boton;
    if (d.etapaActivaEfectiva == 'pago_final' && d.saldoPendienteEfectivo > 0) {
      final esCredito = d.tipoFinanciamiento == 'CREDITO_HIPOTECARIO';
      boton = FilledButton.icon(
        onPressed: () => _pagar(context, d),
        icon: Icon(
          esCredito ? Icons.account_balance_outlined : Icons.payments_outlined,
          size: 18,
        ),
        label: Text(
          esCredito
              ? 'Ver crédito hipotecario'
              : 'Pagar ${formatMXN(d.saldoPendienteEfectivo)}',
        ),
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

    final tone = context.s.color;
    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border(top: BorderSide(color: tone.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(top: false, child: boton),
    );
  }

  /// Chip de estatus de la cabecera, derivado de la etapa activa y NUNCA del
  /// estatus crudo de disponibilidad: ese puede decir "Pagada completamente"
  /// o "Vendida" aunque la cuenta tenga saldo pendiente.
  Widget _estatusChip(PropiedadDetalle d) {
    final (label, tone) = switch (d.etapaActivaEfectiva) {
      'preventa' => ('En Preventa', SBadgeTone.neutral),
      // Ámbar, como el chip "Pago Pendiente".
      'pago_final' => ('Pago Pendiente', SBadgeTone.pending),
      'escrituracion' => ('En Escrituración', SBadgeTone.neutral),
      'entrega' => ('Por Entregar', SBadgeTone.positive),
      'post_entrega' => ('Entregada', SBadgeTone.positive),
      _ => (
        d.estatus,
        d.categoria == 'patrimonio' ? SBadgeTone.positive : SBadgeTone.neutral,
      ),
    };
    return SBadge(label: label, tone: tone);
  }

  Widget _dato(SozuColorRoles tone, String label, String value) {
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: tone.fgSubtle,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tone.fg,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODO PORTAL (web ≥1024): header fuera de cards y grid de 2 columnas
  // (contenido 1fr + lateral 300). Solo capa visual: reutiliza el provider,
  // los mismos componentes y las acciones de la vista móvil.
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _portalBody(AsyncValue<PropiedadDetalle> detalle) {
    return detalle.when(
      loading: () => ListView(
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        children: const [
          SSkeleton(width: 320, height: 28, radius: 8),
          SizedBox(height: 20),
          SSkeleton(height: 320, radius: 24),
          SizedBox(height: 16),
          SSkeleton(height: 160, radius: 24),
        ],
      ),
      error: (_, __) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          SErrorState(
            title: 'No pudimos cargar esta propiedad',
            onRetry: () =>
                ref.invalidate(propertyDetailProvider(widget.cuentaId)),
          ),
        ],
      ),
      data: (d) => _portalContenido(d),
    );
  }

  Widget _portalContenido(PropiedadDetalle d) {
    // ── Columna izquierda ──
    // Parte fija + barra de pestañas + contenido de la pestaña activa. El
    // resto de secciones vive dentro de su pestaña, no se duplica en el scroll.
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

        // 1 · Imagen de la propiedad; clic abre el visor a pantalla completa.
        _portalImagen(d),

        // 2 · Productos adicionales
        if (d.productos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _portalProductos(d),
        ],

        // 3 · Etapa actual (stepper compartido con "Ahora estás aquí")
        const SizedBox(height: 16),
        EtapaActualStepper(
          portal: true,
          stages: d.stagesEfectivos,
          activa: d.etapaActivaEfectiva,
          saldoPendiente: d.saldoPendienteEfectivo,
        ),

        // 4 · Barra de pestañas (Pagos · Avance de obra · Documentos · Ficha)
        const SizedBox(height: 16),
        _portalTabBar(),

        // 5 · Contenido de la pestaña activa
        const SizedBox(height: 16),
        _portalTabContent(d),
      ],
    );

    // ── Columna derecha (lateral 340 del TSX) ──
    final derecha = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Agente comercial (card nueva del backend; DEGRADACIÓN: se oculta si
        // el campo llega null/ausente). El portal la pinta primero en el lateral.
        if (d.agente != null) ...[
          _portalAgente(d.agente!, d),
          const SizedBox(height: 16),
        ],
        _portalPrecioCompra(d),
        const SizedBox(height: 16),
        _portalDatosTecnicos(d),
      ],
    );

    // Cuerpo: header + grid de 2 columnas.
    final cuerpo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Propiedad en proceso legal: copia
          // de solo lectura + contenido en escala de grises. Los CTAs de pago
          // ya se ocultan con la misma condición.
          if (d.enDemanda) ...[
            _portalDemandaPill(),
            const SizedBox(height: 16),
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
              child: cuerpo,
            ),
          ] else
            cuerpo,
        ],
      ),
    );
  }

  // ── Barra de pestañas ──
  // Fondo muted, pill activa con fondo card + sombra, icono + label.
  Widget _portalTabBar() {
    const tabs = <(_DetailTab, String, IconData)>[
      (_DetailTab.pagos, 'Pagos', Icons.credit_card_outlined),
      (_DetailTab.obra, 'Avance de obra', Icons.apartment_outlined),
      (_DetailTab.docs, 'Documentos', Icons.description_outlined),
      (_DetailTab.ficha, 'Ficha técnica', Icons.layers_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PortalColors.muted,
        borderRadius: BorderRadius.circular(kPortalRadiusLg),
      ),
      child: Row(
        children: [
          for (final (id, label, icon) in tabs)
            Expanded(child: _portalTabButton(id, label, icon)),
        ],
      ),
    );
  }

  Widget _portalTabButton(_DetailTab id, String label, IconData icon) {
    final active = _portalTab == id;
    return SHoverBuilder(
      builder: (context, hovered) {
        final Color fg = active
            ? PortalColors.foreground
            : hovered
            ? PortalColors.foreground
            : PortalColors.mutedForeground;
        return GestureDetector(
          onTap: () => setState(() => _portalTab = id),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            // tab: cambia fondo y sombra en el sitio -> `fast` + `standard`.
            duration: context.s.motion.fast,
            curve: context.s.motion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? PortalColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(kPortalRadiusMd),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x0D000000), // shadow-sm
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ]
                  : null,
            ),
            // FittedBox evita desbordes cuando la columna queda angosta
            // La tabla scrollea horizontal si no cabe.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    style: portalText(
                      size: 12,
                      weight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Contenido de la pestaña activa (cada sección vive solo aquí).
  Widget _portalTabContent(PropiedadDetalle d) {
    switch (_portalTab) {
      // Pagos → cronograma (misma ancla para "Confirmar plan de pagos").
      case _DetailTab.pagos:
        return KeyedSubtree(
          key: _cronoKey,
          child: CronogramaPagos(portal: true, esquemaPago: d.esquemaPago),
        );

      // Avance de obra → tarjeta de video (si hay) + card de datos del
      // backend; si aún no hay datos ni video, empty state discreto dentro de
      // la pestaña (no se inventa nada).
      case _DetailTab.obra:
        final videoUrl = d.videoObraUrl?.trim();
        final tieneVideo = videoUrl != null && videoUrl.isNotEmpty;
        final secciones = <Widget>[
          if (tieneVideo) _portalVideoObra(videoUrl),
          if (d.avanceObra != null)
            _portalAvanceObra(d.avanceObra!)
          else if (!tieneVideo)
            _portalAvanceObraVacio(),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < secciones.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              secciones[i],
            ],
          ],
        );

      // Documentos → sección de documentos de la propiedad.
      case _DetailTab.docs:
        return _portalDocumentos(d);

      // Ficha técnica → ficha (¿dónde está tu unidad? + distribución),
      // ubicación/mapa y copropietarios.
      case _DetailTab.ficha:
        final tieneFicha =
            d.ficha.numeroPiso != null ||
            d.ficha.planoNivelUrl != null ||
            d.ficha.planoDistribucionUrl != null ||
            d.ficha.regiones.isNotEmpty;
        final tieneAlgo =
            tieneFicha || d.ubicacion != null || d.copropietarios.length >= 2;
        if (!tieneAlgo) {
          return _portalTabVacio(
            'La ficha técnica de tu unidad aún no está disponible.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tieneFicha) _FichaTecnica(ficha: d.ficha, portal: true),
            if (d.ubicacion != null) ...[
              if (tieneFicha) const SizedBox(height: 16),
              _UbicacionSection(
                portal: true,
                ubicacion: d.ubicacion!,
                proyecto: d.proyecto,
              ),
            ],
            if (d.copropietarios.length >= 2) ...[
              const SizedBox(height: 16),
              CopropietariosSection(
                portal: true,
                copropietarios: d.copropietarios,
              ),
            ],
          ],
        );
    }
  }

  /// Empty state discreto de la pestaña Avance de obra (mientras el desarrollo
  /// no reporte datos): card con el label de sección + mensaje muted, NO una
  /// card de avance fabricada.
  Widget _portalAvanceObraVacio() {
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSectionLabel(
            icon: Icons.engineering_outlined,
            text: 'Avance de obra',
          ),
          const SizedBox(height: 14),
          Text(
            'El avance de obra se mostrará cuando el desarrollo lo reporte.',
            style: portalText(
              size: 12,
              height: 1.45,
              color: PortalColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state genérico discreto para una pestaña sin datos.
  Widget _portalTabVacio(String mensaje) {
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Text(
        mensaje,
        style: portalText(
          size: 12,
          height: 1.45,
          color: PortalColors.mutedForeground,
        ),
      ),
    );
  }

  /// Matriz de saturación 0 (grayscale) para el overlay de "en demanda".
  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Pill "En demanda · Modo solo lectura".
  Widget _portalDemandaPill() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFACC15), // yellow-400
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFEAB308)), // yellow-500
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Color(0xFF422006), // yellow-950
            ),
            const SizedBox(width: 8),
            Text(
              'En demanda · Modo solo lectura',
              style: portalText(
                size: 13,
                weight: FontWeight.w600,
                color: const Color(0xFF422006),
              ),
            ),
          ],
        ),
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

  /// Chip de etapa del header: derivado de la
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

  /// Imagen principal en aspect-video; clic abre el visor a pantalla completa.
  /// Si el backend manda galería se convierte en carrusel.
  Widget _portalImagen(PropiedadDetalle d) {
    if (d.galeria.isNotEmpty) {
      return _GaleriaCarrusel(
        fotos: _galeriaItems(d),
        titulo: '${d.proyecto} · U-${d.unidad}',
        radius: kPortalRadiusCard,
        aspectRatio: 16 / 9,
      );
    }
    final url = d.urlImagen;
    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(kPortalRadiusCard),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: SNetworkImage(url: url),
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

  /// Construye la lista de slides de la galería: antepone la portada
  /// (`urlImagen`) como primer slide si aún no está incluida y deduplica por
  /// URL, respetando el orden que envía el backend.
  List<({String url, String categoria})> _galeriaItems(PropiedadDetalle d) {
    final items = <({String url, String categoria})>[];
    final seen = <String>{};
    void push(String? url, String cat) {
      final u = url?.trim();
      if (u != null && u.isNotEmpty && seen.add(u)) {
        items.add((url: u, categoria: cat));
      }
    }

    push(d.urlImagen, 'proyecto');
    for (final f in d.galeria) {
      push(f.url, f.categoria);
    }
    return items;
  }

  // ── Productos adicionales (card única con filas) ──
  Widget _portalProductos(PropiedadDetalle d) {
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SSectionLabel(
            icon: Icons.inventory_2_outlined,
            text: 'Productos adicionales · ${d.productos.length}',
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
    // Chip de estatus (bg/fg) + punto de color por estatus.
    final (bg, fg, dot) = switch (p.estatus) {
      'Pagado' => (
        PortalColors.primarySoft10,
        PortalColors.primary,
        PortalColors.primary,
      ),
      'En curso' => (
        PortalColors.primarySoft10,
        PortalColors.primary,
        PortalColors.primary,
      ),
      _ => (
        PortalColors.warningSoft10,
        PortalColors.warning,
        PortalColors.warning,
      ),
    };
    // El backend ya entrega avance y monto; el pendiente se deriva.
    final paidPct = p.avance.clamp(0, 100).toDouble();
    final pendiente = (p.monto * (1 - paidPct / 100))
        .clamp(0, p.monto)
        .toDouble();

    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => context.push('/productos/${p.id}'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: hovered ? PortalColors.mutedHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: portalText(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Chip de estatus con punto de color por estatus.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
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
                                decoration: BoxDecoration(
                                  color: dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                p.estatus,
                                style: portalText(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (p.monto > 0) ...[
                      const SizedBox(height: 8),
                      // Barra de avance + porcentaje pagado.
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 6,
                                color: PortalColors.muted,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (paidPct / 100).clamp(0.0, 1.0),
                                  child: Container(color: PortalColors.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${paidPct.round()}%',
                            style: portalText(
                              size: 10,
                              color: PortalColors.mutedForeground,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Monto total + saldo pendiente derivado.
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatMXN(p.monto),
                            style: portalText(
                              size: 11,
                              weight: FontWeight.w700,
                              tabular: true,
                            ),
                          ),
                          if (pendiente > 0)
                            TextSpan(
                              text: ' · ${formatMXN(pendiente)} pendiente',
                              style: portalText(
                                size: 10,
                                color: PortalColors.mutedForeground,
                                tabular: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: PortalColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Documentos (card única con filas) ──
  Widget _portalDocumentos(PropiedadDetalle d) {
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSectionLabel(
            icon: Icons.description_outlined,
            text: 'Documentos',
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
    return SHoverBuilder(
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

  // ── Card financiero "PRECIO DE COMPRA" ──
  Widget _portalPrecioCompra(PropiedadDetalle d) {
    final progreso = (d.avancePagoEfectivo / 100).clamp(0.0, 1.0).toDouble();
    final cta = _portalCta(d);
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSectionLabel.inline(text: 'Precio de compra'),
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
                      const SSectionLabel.inline(text: 'Pagado'),
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
                      const SSectionLabel.inline(text: 'Restante'),
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
          ..._portalDesgloseEscrituracion(d),
          if (d.entrega.trim().isNotEmpty && d.entrega != '-') ...[
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
                          style: portalText(size: 11, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (cta != null) ...[const SizedBox(height: 16), cta],
        ],
      ),
    );
  }

  /// "Desglose a escrituración": el valor que se escritura (departamento más
  /// estacionamiento y bodega) y, aparte, los complementos que no entran a la
  /// escritura. Devuelve vacío si la propiedad no tiene complementos.
  List<Widget> _portalDesgloseEscrituracion(PropiedadDetalle d) {
    if (d.productos.isEmpty) return const [];
    final e = Escrituracion.de(d);

    Widget badge(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: PortalColors.primarySoft10,
        border: Border.all(color: PortalColors.primaryBorder30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: portalText(
          size: 10,
          weight: FontWeight.w600,
          color: PortalColors.primary,
        ),
      ),
    );

    Widget subLabel(String prefijo, double monto) => Text(
      '$prefijo ${formatMXN(monto)}',
      style: portalText(
        size: 10,
        color: PortalColors.mutedForeground,
        tabular: true,
      ),
    );

    Widget listaLabel(double monto) => subLabel('Lista', monto);

    Widget montoGrande(double monto, {bool bold = false}) => Text(
      formatMXN(monto),
      style: portalText(
        size: 13,
        weight: bold ? FontWeight.w700 : FontWeight.w600,
        tabular: true,
        height: 1.2,
      ),
    );

    Widget row({
      required String concepto,
      required Widget right,
      required bool first,
      bool conceptoBold = false,
      Color? background,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: background,
          border: first
              ? null
              : const Border(top: BorderSide(color: PortalColors.borderSoft)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                concepto,
                style: portalText(
                  size: 12,
                  weight: conceptoBold ? FontWeight.w600 : FontWeight.w400,
                  color: conceptoBold
                      ? PortalColors.foreground
                      : PortalColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            right,
          ],
        ),
      );
    }

    Widget complementoRow(ProductoDetalle p, {required bool first}) {
      final restante = Escrituracion.restanteDe(p);
      final incluido = p.monto <= 0.01;
      final pagado = !incluido && restante <= 0.01;
      final Widget right;
      if (incluido) {
        right = badge('Incluido');
      } else if (pagado) {
        right = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            badge('Pagado'),
            const SizedBox(height: 2),
            listaLabel(p.monto),
          ],
        );
      } else {
        right = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [montoGrande(restante), listaLabel(p.monto)],
        );
      }
      return row(first: first, concepto: p.nombre, right: right);
    }

    final rows = <Widget>[
      // Departamento
      row(
        first: true,
        concepto: 'Departamento',
        right: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            montoGrande(e.restanteDepartamento),
            listaLabel(e.precioDepartamento),
          ],
        ),
      ),
      // Estacionamiento y bodega: los únicos complementos que se escrituran.
      for (final p in e.escriturables) complementoRow(p, first: false),
      // Total: el valor que se escritura, que es lo que se cubre con recursos
      // propios o con crédito. El saldo va abajo, chico.
      row(
        first: false,
        concepto: 'Total a pagar para escriturar',
        conceptoBold: true,
        background: PortalColors.primary.withValues(alpha: .04),
        right: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            montoGrande(e.precioTotal, bold: true),
            subLabel('Restante', e.restanteTotal),
          ],
        ),
      ),
      if (e.noEscriturables.isNotEmpty) ...[
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: PortalColors.borderSoft)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'No entra a la escritura - se paga aparte',
            style: portalText(
              size: 10,
              weight: FontWeight.w600,
              color: PortalColors.mutedForeground,
            ),
          ),
        ),
        for (var i = 0; i < e.noEscriturables.length; i++)
          complementoRow(e.noEscriturables[i], first: i == 0),
      ],
    ];

    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.only(bottom: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: PortalColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SSectionLabel.inline(text: 'Desglose a escrituración'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: PortalColors.mutedSoft30,
                border: Border.all(color: PortalColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(children: rows),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El "Total a pagar para escriturar" es el valor que se escritura: '
              'el departamento más el estacionamiento y la bodega que se hayan '
              'comprado. Es lo que se cubre con recursos propios o con crédito. '
              'En cada renglón el monto grande es lo que falta pagar y "Lista" '
              'el precio total; cada complemento se paga en su propia cuenta.',
              style: portalText(
                size: 10,
                color: PortalColors.mutedForeground,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// CTA contextual del card financiero:
  /// mismas condiciones de visibilidad que la vista móvil (nunca en demanda).
  Widget? _portalCta(PropiedadDetalle d) {
    if (d.enDemanda) return null;
    if (d.etapaActivaEfectiva == 'pago_final' && d.saldoPendienteEfectivo > 0) {
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

  // ── Card "DATOS TÉCNICOS" ──
  Widget _portalDatosTecnicos(PropiedadDetalle d) {
    final celdas = <(String, String)>[
      ('Proyecto', d.proyecto),
      ('Unidad', 'U-${d.unidad}'),
      ('Tipo', d.tipo),
      ('Área', d.m2Interiores != null ? '${d.m2Interiores} m²' : '-'),
      ('Recámaras', '${d.recamaras}'),
      ('Baños', '${d.banos}'),
      ('Piso', d.numeroPiso != null ? '${d.numeroPiso}' : '-'),
      ('Entrega', d.entrega),
    ];
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSectionLabel(
            icon: Icons.apartment_outlined,
            text: 'Datos técnicos',
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
                      SSectionLabel.inline(text: label),
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

  // ── Card "TU AGENTE COMERCIAL" ────────────────────────────────────────────
  // Card nueva: lee AgenteComercial del modelo. Cada botón de contacto solo
  // aparece si el dato correspondiente viene del backend (degradación fina).
  Widget _portalAgente(AgenteComercial a, PropiedadDetalle d) {
    final asunto = '${d.proyecto} U-${d.unidad}';
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSectionLabel(
            icon: Icons.person_outline,
            text: 'Tu agente comercial',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: PortalColors.primarySoft10,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials(a.nombre),
                  style: portalText(
                    size: 15,
                    weight: FontWeight.w700,
                    color: PortalColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 13, weight: FontWeight.w600),
                    ),
                    Text(
                      a.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                    if ((a.tiempoRespuesta ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '● ${a.tiempoRespuesta!.trim()}',
                          style: portalText(
                            size: 10,
                            weight: FontWeight.w500,
                            color: PortalColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if ((a.whatsapp ?? '').trim().isNotEmpty) ...[
                Expanded(
                  child: _portalAgenteBtn(
                    icon: Icons.chat_outlined,
                    leading: const WhatsAppIcon(size: 15, color: Colors.white),
                    label: 'WA',
                    filled: true,
                    onTap: () => _abrirUrlExterna(
                      'https://wa.me/${a.whatsapp!.trim()}'
                      '?text=${Uri.encodeComponent('Hola ${a.nombre.split(' ').first}, tengo una pregunta sobre mi propiedad $asunto.')}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if ((a.telefono ?? '').trim().isNotEmpty) ...[
                Expanded(
                  child: _portalAgenteBtn(
                    icon: Icons.phone_outlined,
                    label: 'Tel',
                    onTap: () => _abrirUrlExterna(
                      'tel:${a.telefono!.replaceAll(RegExp(r'\s'), '')}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if ((a.email ?? '').trim().isNotEmpty)
                Expanded(
                  child: _portalAgenteBtn(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    onTap: () => _abrirUrlExterna(
                      'mailto:${a.email!.trim()}'
                      '?subject=${Uri.encodeComponent('Sobre $asunto')}',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirUrlExterna(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _portalAgenteBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,

    /// Widget de ícono a la izquierda que reemplaza a [icon] (p. ej. el logo
    /// de WhatsApp dibujado con CustomPaint en el botón "WhatsApp").
    Widget? leading,
  }) {
    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? (hovered ? PortalColors.primaryHover : PortalColors.primary)
                : (hovered ? PortalColors.mutedHover : PortalColors.surface),
            borderRadius: BorderRadius.circular(kPortalRadiusMd),
            border: filled ? null : Border.all(color: PortalColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading ??
                  Icon(
                    icon,
                    size: 14,
                    color: filled ? Colors.white : PortalColors.foreground,
                  ),
              const SizedBox(width: 6),
              Text(
                label,
                style: portalText(
                  size: 11,
                  weight: FontWeight.w600,
                  color: filled ? Colors.white : PortalColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Última actualización del avance: el backend manda una fecha ISO; la
  // formateamos a DD/MM/YYYY. Si ya viniera formateada (no parseable como
  // fecha), se muestra tal cual.
  String _fmtUltimaActualizacion(String raw) {
    final d = DateTime.tryParse(raw);
    return d != null ? formatDate(d) : raw;
  }

  /// Extrae el id de YouTube de una URL embed/watch/short (para derivar el
  /// thumbnail). null si no reconoce el formato.
  String? _youtubeId(String url) {
    for (final re in [
      RegExp(r'youtube\.com/embed/([\w-]{6,})'),
      RegExp(r'youtu\.be/([\w-]{6,})'),
      RegExp(r'[?&]v=([\w-]{6,})'),
      RegExp(r'youtube\.com/shorts/([\w-]{6,})'),
    ]) {
      final m = re.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // ── Card "RECORRIDO DEL AVANCE" (video embebido del ConstructionProgress
  // del portal). Thumbnail de YouTube + botón de play; al tocar abre el video
  // externamente. Se muestra solo si el backend manda `video_obra_url`.
  Widget _portalVideoObra(String url) {
    final id = _youtubeId(url);
    final thumb = id != null
        ? 'https://img.youtube.com/vi/$id/hqdefault.jpg'
        : null;
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSectionLabel(
            icon: Icons.play_circle_outline,
            text: 'Recorrido del avance',
          ),
          const SizedBox(height: 14),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _abrirUrlExterna(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kPortalRadiusCard),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumb != null)
                        SNetworkImage(
                          url: thumb,
                          placeholderIcon: Icons.videocam_outlined,
                        )
                      else
                        Container(color: Colors.black),
                      // Velo oscuro para resaltar el botón de play.
                      Container(color: Colors.black26),
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card "AVANCE DE OBRA" (sin video) ─────────────────────────────────────
  // Card nueva: lee AvanceObra del modelo (% global + hitos + entrega
  // estimada). Se muestra solo cuando el objeto viene del backend.
  Widget _portalAvanceObra(AvanceObra o) {
    final currentIdx = o.hitos.indexWhere((h) => !h.completado);
    return SCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SSectionLabel(
            icon: Icons.engineering_outlined,
            text: o.estatus ?? 'Avance de obra',
          ),
          if ((o.ultimaActualizacion ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: PortalColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Última actualización · ',
                          style: portalText(
                            size: 11,
                            color: PortalColors.mutedForeground,
                          ),
                        ),
                        TextSpan(
                          text: _fmtUltimaActualizacion(
                            o.ultimaActualizacion!.trim(),
                          ),
                          style: portalText(size: 11, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (o.avanceGlobal > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Avance global',
                  style: portalText(
                    size: 12,
                    weight: FontWeight.w500,
                    color: PortalColors.mutedForeground,
                  ),
                ),
                Text(
                  '${o.avanceGlobal.round()}%',
                  style: portalText(
                    size: 18,
                    weight: FontWeight.w700,
                    color: PortalColors.primary,
                    tabular: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SProgressBar(percent: o.avanceGlobal),
          ],
          if (o.hitos.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < o.hitos.length; i++)
              _portalHitoRow(o.hitos[i], actual: i == currentIdx),
          ],
          if ((o.entregaEstimada ?? '').trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: PortalColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Entrega estimada · ${portalShortDate(o.entregaEstimada)}',
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _portalHitoRow(HitoObra h, {required bool actual}) {
    final Widget marca;
    if (h.completado) {
      marca = const Icon(
        Icons.check_circle,
        size: 16,
        color: PortalColors.primary,
      );
    } else if (actual) {
      marca = Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: PortalColors.primary, width: 2),
        ),
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: PortalColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      );
    } else {
      marca = const Icon(
        Icons.circle_outlined,
        size: 16,
        color: PortalColors.mutedForeground,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: actual
          ? BoxDecoration(
              color: PortalColors.primarySoft6,
              borderRadius: BorderRadius.circular(kPortalRadiusMd),
              border: Border.all(color: PortalColors.primaryBorder30),
            )
          : null,
      child: Row(
        children: [
          marca,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              h.fase,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: portalText(
                size: 12,
                weight: actual ? FontWeight.w600 : FontWeight.w400,
                color: h.completado
                    ? PortalColors.foreground
                    : actual
                    ? PortalColors.primary
                    : PortalColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${h.pct}%',
            style: portalText(
              size: 11,
              weight: actual ? FontWeight.w600 : FontWeight.w400,
              color: actual
                  ? PortalColors.primary
                  : PortalColors.mutedForeground,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta legible para el badge de categoría de la galería; si la categoría
/// no está mapeada, capitaliza el valor crudo del backend.
String _galeriaCatLabel(String cat) {
  const mapa = <String, String>{
    'proyecto': 'Proyecto',
    'render': 'Render',
    'fachada': 'Fachada',
    'interior': 'Interior',
    'exterior': 'Exterior',
    'obra': 'Obra',
    'amenidad': 'Amenidades',
    'amenidades': 'Amenidades',
    'nivel': 'Plano de nivel',
    'depto': 'Plano del depto',
    'modelo': 'Modelo',
    'galeria': 'Galería',
    'otro': 'Imagen',
  };
  final key = cat.trim().toLowerCase();
  if (mapa.containsKey(key)) return mapa[key]!;
  if (key.isEmpty) return 'Imagen';
  return key[0].toUpperCase() + key.substring(1);
}

/// Carrusel de la imagen principal: badge de categoría, flechas, swipe, dots y
/// miniaturas; clic abre el visor a pantalla completa. Sirve tanto en móvil
/// (alto fijo) como en portal (aspect-ratio).
class _GaleriaCarrusel extends StatefulWidget {
  final List<({String url, String categoria})> fotos;
  final String titulo;

  /// Radio de las esquinas de la imagen grande.
  final double radius;

  /// Alto fijo (móvil). Si es null se usa [aspectRatio].
  final double? height;

  /// Relación de aspecto (portal). Ignorado si [height] no es null.
  final double? aspectRatio;

  const _GaleriaCarrusel({
    required this.fotos,
    required this.titulo,
    this.radius = 0,
    this.height,
    this.aspectRatio,
  });

  @override
  State<_GaleriaCarrusel> createState() => _GaleriaCarruselState();
}

class _GaleriaCarruselState extends State<_GaleriaCarrusel> {
  final PageController _pc = PageController();
  int _idx = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    final target = i.clamp(0, widget.fotos.length - 1);
    _pc.animateToPage(
      target,
      // Cambio de foto del carrusel: entrada/salida de un elemento -> `normal`,
      // con la curva estándar (easeInOut arrancaba lento y se sentía retardo).
      duration: context.s.motion.normal,
      curve: context.s.motion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotos = widget.fotos;
    final safeIdx = _idx.clamp(0, fotos.length - 1);
    final actual = fotos[safeIdx];
    final varias = fotos.length > 1;

    Widget flecha({required bool prev}) {
      final habilitado = prev ? safeIdx > 0 : safeIdx < fotos.length - 1;
      return Opacity(
        opacity: habilitado ? 1 : 0.3,
        child: GestureDetector(
          onTap: habilitado ? () => _goTo(safeIdx + (prev ? -1 : 1)) : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(
              prev ? Icons.chevron_left : Icons.chevron_right,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        // Imagen grande + swipe (el tap abre el visor).
        GestureDetector(
          onTap: () => openMedia(context, actual.url, titulo: widget.titulo),
          child: PageView.builder(
            controller: _pc,
            itemCount: fotos.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => SNetworkImage(url: fotos[i].url),
          ),
        ),

        // Badge de categoría (arriba-izquierda).
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _galeriaCatLabel(actual.categoria),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),

        if (varias) ...[
          // Flechas prev/next centradas verticalmente.
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(child: flecha(prev: true)),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(child: flecha(prev: false)),
          ),
          // Dots (abajo-centro).
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < fotos.length; i++)
                    AnimatedContainer(
                      // El puntito activo se estira: superficie mínima -> `fast`.
                      // La curva sí es `emphasized`: el ancho pasa de 6 a 18 px
                      // (el triple), y eso es recorrido, no cambio de estado.
                      duration: context.s.motion.fast,
                      curve: context.s.motion.emphasized,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == safeIdx ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == safeIdx
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: widget.height != null
          ? SizedBox(
              height: widget.height,
              width: double.infinity,
              child: stack,
            )
          : AspectRatio(
              aspectRatio: widget.aspectRatio ?? 16 / 9,
              child: stack,
            ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          imagen,
          if (varias) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final activa = i == safeIdx;
                  return GestureDetector(
                    onTap: () => _goTo(i),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activa
                              ? PortalColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Opacity(
                        opacity: activa ? 1 : 0.6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SNetworkImage(url: fotos[i].url),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner de propiedad en proceso legal: informa y acompaña la ocultación de
/// todos los CTAs de pago.
class _DemandaBanner extends StatelessWidget {
  const _DemandaBanner();

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.warningSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SozuAmber.base.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_outlined, size: 18, color: SozuAmber.strong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Propiedad en proceso legal - modo solo lectura',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tone.fg,
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

  /// true en modo portal web: card con label uppercase y botones compactos; la
  /// vista móvil queda idéntica.
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
    final tone = context.s.color;
    final mapa = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: portal ? 170 : 140,
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

    // ── Modo portal: card con label uppercase y botones compactos ──
    if (portal) {
      final direccion = ubicacion.direccion?.trim();
      return SCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SSectionLabel(icon: Icons.place_outlined, text: 'Ubicación'),
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
                SButton(
                  label: 'Cómo llegar',
                  icon: Icons.directions_outlined,
                  size: SButtonSize.sm,
                  fullWidth: false,
                  onPressed: () => _abrirComoLlegar(context),
                ),
                const SizedBox(width: 10),
                SButton.secondary(
                  label: 'Abrir en Maps',
                  icon: Icons.map_outlined,
                  size: SButtonSize.sm,
                  fullWidth: false,
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
        const SSectionLabel.heading(
          icon: Icons.place_outlined,
          text: 'Ubicación',
        ),
        SCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mapa,
              if (ubicacion.direccion != null &&
                  ubicacion.direccion!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  ubicacion.direccion!,
                  style: TextStyle(fontSize: 13, color: tone.fgMuted),
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
    final tone = context.s.color;
    final badgeTone = switch (p.estatus) {
      'Pagado' => SBadgeTone.positive,
      'En curso' => SBadgeTone.neutral,
      _ => SBadgeTone.pending,
    };
    return PressableScale(
      onTap: () => context.push('/productos/${p.id}'),
      child: SCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: SozuBrand.green600,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SBadge(label: p.estatus, tone: badgeTone),
                ],
              ),
            ),
            Text(
              formatMXN(p.monto),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tone.fg,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: tone.fgSubtle),
          ],
        ),
      ),
    );
  }
}

class _FichaTecnica extends StatelessWidget {
  final FichaTecnica ficha;

  /// true en modo portal web: card con el label uppercase dentro; la vista
  /// móvil queda idéntica.
  final bool portal;

  const _FichaTecnica({required this.ficha, this.portal = false});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ubicación, nivel y distribución de tu unidad'
          '${ficha.modelo != '-' ? ' · Modelo ${ficha.modelo}' : ''}',
          style: TextStyle(fontSize: 12, color: tone.fgMuted),
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
              color: tone.fg,
            ),
          ),
        ],
        // ¿Dónde está tu unidad? - diagrama del edificio con la planta del
        // nivel (LevelMap) consolidada en su columna derecha.
        if (ficha.numeroPiso != null) ...[
          const SizedBox(height: 16),
          BuildingDiagram(
            numeroPiso: ficha.numeroPiso!,
            totalPisos: ficha.totalPisos,
            unidad: ficha.numeroDepa ?? '${ficha.numeroPiso}',
            regiones: ficha.regiones,
            numeroDepa: ficha.numeroDepa,
          ),
        ],
        if (ficha.regiones.isEmpty && ficha.planoNivelUrl != null) ...[
          const SizedBox(height: 12),
          _planoImage(
            context,
            tone,
            'UBICACIÓN EN EL NIVEL',
            ficha.planoNivelUrl!,
          ),
        ],
        if (ficha.planoDistribucionUrl != null) ...[
          const SizedBox(height: 12),
          _planoImage(
            context,
            tone,
            'DISTRIBUCIÓN',
            ficha.planoDistribucionUrl!,
            height: 360,
          ),
        ],
      ],
    );

    if (portal) {
      return SCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SSectionLabel(
              icon: Icons.map_outlined,
              text: 'Ficha técnica de tu propiedad',
            ),
            const SizedBox(height: 12),
            contenido,
            // Chip de m² + disclaimers "±3%" (el SVG del edificio
            // no se replica). Solo en modo portal.
            if (ficha.m2Total != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: PortalColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: PortalColors.border),
                  ),
                  child: Text(
                    '${ficha.m2Total!.toStringAsFixed(2)} m²',
                    style: portalText(
                      size: 11.5,
                      weight: FontWeight.w500,
                      tabular: true,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Las dimensiones son referenciales y pueden variar ±3% en obra.',
              style: portalText(
                size: 11,
                height: 1.45,
                color: PortalColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las descripciones son ilustrativas, pueden variar en marca por '
              'cuestión de disponibilidad en modelos e inventarios; siempre y '
              'cuando sean de calidad equivalente.',
              style: portalText(
                size: 11,
                height: 1.45,
                color: PortalColors.mutedForeground,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SSectionLabel.heading(
          icon: Icons.map_outlined,
          text: 'Ficha técnica de tu propiedad',
        ),
        SCard(child: contenido),
      ],
    );
  }

  Widget _planoImage(
    BuildContext context,
    SozuColorRoles tone,
    String label,
    String url, {
    double height = 200,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: tone.fgSubtle,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => openMedia(context, url, titulo: label),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: tone.surfaceAlt,
              height: height,
              width: double.infinity,
              child: SNetworkImage(
                url: url,
                fit: BoxFit.contain,
                placeholderIcon: Icons.image_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.zoom_in, size: 14, color: tone.fgSubtle),
            const SizedBox(width: 4),
            Text(
              'Toca para ampliar',
              style: TextStyle(fontSize: 11, color: tone.fgSubtle),
            ),
          ],
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
    final tone = context.s.color;
    return PressableScale(
      onTap: () => openMedia(context, d.urlFirmada, titulo: d.nombre),
      child: SCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 18,
                color: SozuBrand.green600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    '${d.tipo} · ${formatDate(d.fecha)}',
                    style: TextStyle(fontSize: 12, color: tone.fgMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18, color: SozuBrand.green600),
          ],
        ),
      ),
    );
  }
}

/// CTA de ancho completo del card financiero (botón h-40,
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
    return SHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          // hover del botón: solo color de fondo -> `fast` + `standard`.
          duration: context.s.motion.fast,
          curve: context.s.motion.standard,
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
