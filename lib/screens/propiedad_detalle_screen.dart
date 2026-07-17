import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/open_media.dart';
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

  const _UbicacionSection({required this.ubicacion, required this.proyecto});

  LatLng get _punto => LatLng(ubicacion.latitud, ubicacion.longitud);

  Future<void> _abrirEnGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${ubicacion.latitud},${ubicacion.longitud}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(icon: Icons.place_outlined, text: 'Ubicación'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 180,
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
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
              ),
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

  const _FichaTecnica({required this.ficha});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
            icon: Icons.map_outlined, text: 'Ficha técnica de tu propiedad'),
        AppCard(
          child: Column(
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
          ),
        ),
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
