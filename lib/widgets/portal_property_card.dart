import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/portal_theme.dart';
import '../data/models.dart';
import 'network_image.dart';
import 'portal_widgets.dart';

/// Cards de propiedad del "modo portal" web (réplicas 1:1 de las cards del
/// Portal del Cliente de sozu-admin). NO sustituyen a PropertyCardWidget ni a
/// PatrimonioCard (móvil): solo se usan cuando [isPortalMode] es true.
///
/// - [PortalPropertyCard]     → PropertyCard.tsx (Inicio · "Mis propiedades")
/// - [PortalAcquisitionCard]  → AcquisitionCard de ClienteEnAdquisicion.tsx
/// - [PortalPatrimonyCard]    → PatrimonyCard de ClientePatrimonio.tsx

/// "Proyecto · U-nombre" sin duplicar el prefijo si ya viene en el dato.
String _unidadLabel(PropiedadCard p) =>
    p.nombre == '—' || p.nombre.startsWith('U-') ? p.nombre : 'U-${p.nombre}';

/// Sombra `shadow-sm` que aparece en hover.
const List<BoxShadow> _hoverShadow = [
  BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
];

/// Título "Proyecto · U-x" (14px) + ubicación (11px muted) truncados.
class _CardTitle extends StatelessWidget {
  final PropiedadCard item;

  const _CardTitle({required this.item});

  @override
  Widget build(BuildContext context) {
    final ubicacion = item.ubicacion?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: item.proyecto,
                style: portalText(size: 14, weight: FontWeight.w600),
              ),
              TextSpan(
                text: ' · ${_unidadLabel(item)}',
                style: portalText(
                  size: 14,
                  color: PortalColors.mutedForeground,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (ubicacion != null && ubicacion.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            ubicacion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: portalText(size: 11, color: PortalColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

/// Celda de métrica de la card: label 10px uppercase + valor.
class _MetricCell extends StatelessWidget {
  final String label;
  final Widget value;
  final bool first;

  const _MetricCell({
    required this.label,
    required this.value,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: first ? 0 : 8, right: 8),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(
                left: BorderSide(color: PortalColors.borderSoft),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: portalText(
              size: 10,
              color: PortalColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }
}

/// Valor de plusvalía verde con icono de tendencia (13-14px w600).
class _PlusvaliaText extends StatelessWidget {
  final double? pct;
  final double? monto;
  final double size;

  const _PlusvaliaText({this.pct, this.monto, this.size = 13});

  @override
  Widget build(BuildContext context) {
    if (pct == null && monto == null) {
      return Text(
        '—',
        style: portalText(size: size, color: PortalColors.mutedForeground),
      );
    }
    final v = pct ?? monto!;
    final sube = v >= 0;
    final color = sube ? PortalColors.primary : PortalColors.destructive;
    final texto = pct != null
        ? '${sube ? '+' : ''}${pct!.toStringAsFixed(1)}%'
        : '${sube ? '+' : ''}${formatMXN(monto)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(sube ? Icons.trending_up : Icons.trending_down,
            size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: portalText(
              size: size,
              weight: FontWeight.w600,
              color: color,
              tabular: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Ver detalle" verde con chevron (subrayado en hover, como el portal).
class _VerDetalle extends StatelessWidget {
  final bool hovered;
  final bool arrow;

  const _VerDetalle({required this.hovered, this.arrow = false});

  @override
  Widget build(BuildContext context) {
    final style = portalText(
      size: 12,
      weight: FontWeight.w500,
      color: PortalColors.primary,
    ).copyWith(
      decoration: hovered ? TextDecoration.underline : TextDecoration.none,
      decorationColor: PortalColors.primary,
    );
    if (arrow) return Text('Ver detalle →', style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Ver detalle', style: style),
        const Icon(Icons.chevron_right, size: 14, color: PortalColors.primary),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PortalPropertyCard — PropertyCard.tsx (Inicio · Mis propiedades)
// ---------------------------------------------------------------------------

class PortalPropertyCard extends StatelessWidget {
  final PropiedadCard item;
  final VoidCallback onTap;

  const PortalPropertyCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valor = (item.valorActual != null && item.valorActual! > 0)
        ? item.valorActual!
        : item.monto;
    final dotColor = portalPropiedadDotColor(item.etapaActiva);

    return PortalPressable(
      builder: (context, hovered, pressed) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transformAlignment: Alignment.center,
          transform: pressed
              ? Matrix4.diagonal3Values(0.985, 0.985, 1)
              : Matrix4.identity(),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            border: Border.all(
              color: hovered ? PortalColors.borderSoft : PortalColors.border,
            ),
            boxShadow: hovered ? _hoverShadow : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail 112×96 rounded-lg
              ClipRRect(
                borderRadius: BorderRadius.circular(kPortalRadiusMd),
                child: SizedBox(
                  width: 112,
                  height: 96,
                  child: SozuNetworkImage(url: item.urlImagen),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: título + estatus con punto de color
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _CardTitle(item: item)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.estatusDerivado,
                                style: portalText(
                                  size: 10,
                                  weight: FontWeight.w500,
                                  color: PortalColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Grid de 3 métricas con divisores finos y borde y
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: PortalColors.borderSoft),
                          bottom: BorderSide(color: PortalColors.borderSoft),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _MetricCell(
                                first: true,
                                label: 'Valor',
                                value: Text(
                                  formatMXN(valor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: portalText(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    tabular: true,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _MetricCell(
                                label: 'Plusvalía',
                                value: _PlusvaliaText(
                                  pct: item.plusvaliaPct,
                                  monto: item.plusvaliaMonto,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _MetricCell(
                                label: 'Pagado',
                                value: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.avancePago.round()}%',
                                      style: portalText(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        tabular: true,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    PortalThinProgressBar(
                                      percent: item.avancePago,
                                      height: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Footer: Ver detalle + Pagar si hay pago pendiente
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _VerDetalle(hovered: hovered, arrow: true),
                        if (item.pagoPendiente)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.credit_card_outlined,
                                size: 12,
                                color: PortalColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pagar',
                                style: portalText(
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: PortalColors.warning,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PortalAcquisitionCard — AcquisitionCard de ClienteEnAdquisicion.tsx
// ---------------------------------------------------------------------------

/// Sombra `shadow-lg shadow-black/[0.06]` que aparece en hover en las cards de
/// adquisición (más marcada que `_hoverShadow`).
const List<BoxShadow> _hoverShadowLg = [
  BoxShadow(
    color: Color(0x0F000000),
    offset: Offset(0, 10),
    blurRadius: 15,
    spreadRadius: -3,
  ),
  BoxShadow(
    color: Color(0x0F000000),
    offset: Offset(0, 4),
    blurRadius: 6,
    spreadRadius: -4,
  ),
];

/// Punto de color del badge de estatus sobre la imagen (statusDot del portal):
/// `pago_final` en ámbar, resto en verde primario.
Color _acqStatusDotColor(String? etapaActiva) =>
    portalPropiedadDotColor(etapaActiva);

class PortalAcquisitionCard extends StatelessWidget {
  final PropiedadCard item;
  final VoidCallback onTap;

  const PortalAcquisitionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final paidPct = item.avancePago.round();
    final ubicacion = item.ubicacion?.trim();
    final tieneSaldo = item.saldoPendiente > 0;

    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transformAlignment: Alignment.center,
          transform: hovered
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusCard),
            border: Border.all(color: PortalColors.border),
            boxShadow: hovered ? _hoverShadowLg : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero: imagen h-44 con degradado, estatus y título encima ──
              SizedBox(
                height: 176,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SozuNetworkImage(url: item.urlImagen),
                    // Degradado negro inferior para legibilidad del título.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 128,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xE6000000),
                              Color(0x8C000000),
                              Color(0x00000000),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Estatus: pill blanco sólido + punto de color (top-right).
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _acqStatusDotColor(item.etapaActiva),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.estatusDerivado,
                              style: portalText(
                                size: 10,
                                weight: FontWeight.w700,
                                color: const Color(0xFF171717),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Título + ubicación sobre la imagen (abajo).
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: item.proyecto,
                                  style: portalText(
                                    size: 17,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.15,
                                  ).copyWith(shadows: const [
                                    Shadow(
                                      color: Color(0x99000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ]),
                                ),
                                TextSpan(
                                  text: ' · ${_unidadLabel(item)}',
                                  style: portalText(
                                    size: 17,
                                    weight: FontWeight.w500,
                                    color: const Color(0xD9FFFFFF),
                                    height: 1.15,
                                  ).copyWith(shadows: const [
                                    Shadow(
                                      color: Color(0x99000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ubicacion != null && ubicacion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 12,
                                  color: Color(0xE6FFFFFF),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    ubicacion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: portalText(
                                      size: 11,
                                      color: const Color(0xE6FFFFFF),
                                    ).copyWith(shadows: const [
                                      Shadow(
                                        color: Color(0xB3000000),
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Cuerpo: avance de pago ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AVANCE DE PAGO',
                          style: portalText(
                            size: 11,
                            weight: FontWeight.w500,
                            color: PortalColors.mutedForeground,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$paidPct',
                                style: portalText(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  tabular: true,
                                  height: 1.0,
                                ),
                              ),
                              TextSpan(
                                text: '%',
                                style: portalText(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: PortalColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    PortalProgressBar(percent: item.avancePago, height: 6),
                  ],
                ),
              ),
              // ── Footer: próximo pago / docs + Ver detalle ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: PortalColors.mutedSoft20,
                  border: Border(
                    top: BorderSide(color: PortalColors.borderSoft),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (tieneSaldo)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.credit_card_outlined,
                                  size: 14,
                                  color: PortalColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatMXN(item.saldoPendiente),
                                  style: portalText(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    tabular: true,
                                  ),
                                ),
                                if (item.proximaFecha != null)
                                  Text(
                                    ' · ${formatDate(item.proximaFecha)}',
                                    style: portalText(
                                      size: 11,
                                      color: PortalColors.mutedForeground,
                                    ),
                                  ),
                              ],
                            )
                          else if (item.proximaFecha != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: PortalColors.mutedForeground,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatDate(item.proximaFecha),
                                  style: portalText(
                                    size: 11,
                                    color: PortalColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          if (item.docsPendientes > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  size: 14,
                                  color: PortalColors.mutedForeground,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${item.docsPendientes} '
                                  'doc${item.docsPendientes > 1 ? 's' : ''}',
                                  style: portalText(
                                    size: 11,
                                    color: PortalColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _VerDetalle(hovered: hovered),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PortalPatrimonyCard — PatrimonyCard de ClientePatrimonio.tsx
// ---------------------------------------------------------------------------

class PortalPatrimonyCard extends StatelessWidget {
  final PropiedadCard item;

  /// Cuenta de mantenimiento asociada (null si no hay cruce).
  final MantenimientoCard? mantenimiento;
  final VoidCallback onTap;

  const PortalPatrimonyCard({
    super.key,
    required this.item,
    this.mantenimiento,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final manto = mantenimiento;
    final mantoPendiente = manto != null && manto.saldoPendiente > 0;
    final valor = (item.valorActual != null && item.valorActual! > 0)
        ? item.valorActual!
        : item.monto;
    final ubicacion = item.ubicacion?.trim();

    return PortalPressable(
      builder: (context, hovered, pressed) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transformAlignment: Alignment.center,
          // hover:-translate-y-0.5 del portal (la card se levanta 2px).
          transform: hovered
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusCard),
            border: Border.all(color: PortalColors.border),
            // hover:shadow-lg del portal.
            boxShadow: hovered
                ? const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      offset: Offset(0, 8),
                      blurRadius: 24,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero: imagen full-width (h-44), degradado y overlays ──
              SizedBox(
                height: 176,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SozuNetworkImage(url: item.urlImagen),
                    // Degradado inferior para legibilidad del título.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 128,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xE6000000), // black/90
                              Color(0x8C000000), // black/55
                              Color(0x00000000), // transparent
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Badge "Entregada": pill blanco + punto verde (top-right).
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              offset: Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: PortalColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Entregada',
                              style: portalText(
                                size: 10,
                                weight: FontWeight.w700,
                                color: const Color(0xFF171717), // neutral-900
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Pill "Tuya desde …" (top-left, solo si hay fecha).
                    if (item.entregadaDesde != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x8C000000), // black/55
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Tuya desde ${formatDate(item.entregadaDesde)}',
                            style: portalText(
                              size: 10,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Título "Proyecto · U-x" + ubicación sobre la imagen.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: item.proyecto,
                                    style: portalText(
                                      size: 17,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' · ${_unidadLabel(item)}',
                                    style: portalText(
                                      size: 17,
                                      weight: FontWeight.w500,
                                      color:
                                          Colors.white.withValues(alpha: .85),
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ubicacion != null && ubicacion.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: .9),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      ubicacion,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: portalText(
                                        size: 11,
                                        color:
                                            Colors.white.withValues(alpha: .9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Cuerpo: Valor actual / Plusvalía en dos cajas muted ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _PatrimonioMetricBox(
                          label: 'Valor actual',
                          child: Text(
                            formatMXN(valor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: portalText(
                              size: 16,
                              weight: FontWeight.w700,
                              tabular: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PatrimonioMetricBox(
                          label: 'Plusvalía',
                          child: _PlusvaliaText(
                            pct: item.plusvaliaPct,
                            monto: item.plusvaliaMonto,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Footer: chip de mantenimiento + Ver detalle ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: PortalColors.mutedSoft20,
                  border: Border(
                    top: BorderSide(color: PortalColors.borderSoft),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Chip de mantenimiento SIEMPRE visible: por defecto
                    // "Al día" (success) cuando no hay registro o está al
                    // corriente; "Pago próximo" (warning) si hay saldo.
                    mantoPendiente
                        ? const PortalStatusChip(
                            small: true,
                            label: 'Pago próximo',
                            icon: Icons.calendar_today_outlined,
                            background: PortalColors.warningSoft15,
                            foreground: PortalColors.warning,
                          )
                        : const PortalStatusChip(
                            small: true,
                            label: 'Al día',
                            icon: Icons.check_circle_outline,
                            background: PortalColors.primarySoft15,
                            foreground: PortalColors.primary,
                          ),
                    _VerDetalle(hovered: hovered),
                  ],
                ),
              ),
              // ── Banner ámbar de mantenimiento pendiente ──
              if (mantoPendiente)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: PortalColors.warningSoft10,
                    border: Border(
                      top: BorderSide(
                        color: PortalColors.warning.withValues(alpha: .3),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Mantenimiento pendiente · '
                          '${formatMXN(manto.saldoPendiente)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: portalText(
                            size: 12,
                            weight: FontWeight.w500,
                            color: PortalColors.warning,
                          ),
                        ),
                      ),
                      Text(
                        'Pagar →',
                        style: portalText(
                          size: 12,
                          weight: FontWeight.w600,
                          color: PortalColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja de métrica de la PortalPatrimonyCard: fondo muted suave, radio 12,
/// label 10px uppercase + valor (réplica de los `bg-muted/40 rounded-xl p-3`
/// de PatrimonyCard.tsx del portal).
class _PatrimonioMetricBox extends StatelessWidget {
  final String label;
  final Widget child;

  const _PatrimonioMetricBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PortalColors.muted.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: portalText(
              size: 10,
              color: PortalColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}
