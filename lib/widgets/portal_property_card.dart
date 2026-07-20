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

const List<String> _etapas = [
  'preventa',
  'pago_final',
  'escrituracion',
  'entrega',
];
const List<String> _etapasCortas = ['Preventa', 'Pago', 'Escritura', 'Entrega'];

class PortalAcquisitionCard extends StatelessWidget {
  final PropiedadCard item;
  final VoidCallback onTap;

  const PortalAcquisitionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  int get _currentIdx {
    if (item.etapaActiva == 'post_entrega') return _etapas.length;
    return _etapas.indexOf(item.etapaActiva ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipFg) = portalEstatusStyle(item.estatusDerivado);
    final idx = _currentIdx;

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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusCard),
            border: Border.all(
              color: hovered ? PortalColors.borderSoft : PortalColors.border,
            ),
            boxShadow: hovered ? _hoverShadow : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen 120×100 rounded-xl
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 120,
                        height: 100,
                        child: SozuNetworkImage(url: item.urlImagen),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _CardTitle(item: item)),
                                const SizedBox(width: 8),
                                PortalStatusChip(
                                  small: true,
                                  label: item.estatusDerivado,
                                  background: chipBg,
                                  foreground: chipFg,
                                ),
                              ],
                            ),
                            // Pagado + barra 3px
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Pagado',
                                      style: portalText(
                                        size: 11,
                                        color: PortalColors.mutedForeground,
                                      ),
                                    ),
                                    Text(
                                      '${item.avancePago.round()}%',
                                      style: portalText(
                                        size: 11,
                                        weight: FontWeight.w500,
                                        tabular: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                PortalThinProgressBar(
                                  percent: item.avancePago,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Mini-stepper de etapas (4 segmentos de 3px + labels 9px)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < _etapas.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: idx == i
                                    ? PortalColors.primary
                                    : idx > i
                                        ? PortalColors.primary
                                            .withValues(alpha: .6)
                                        : PortalColors.muted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _etapasCortas.length; i++)
                          Text(
                            _etapasCortas[i].toUpperCase(),
                            style: portalText(
                              size: 9,
                              weight: FontWeight.w500,
                              letterSpacing: 0.4,
                              color: idx == i
                                  ? PortalColors.primary
                                  : idx > i
                                      ? PortalColors.foreground
                                          .withValues(alpha: .7)
                                      : PortalColors.mutedForeground
                                          .withValues(alpha: .6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Footer: próximo pago / docs / plusvalía + Ver detalle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: PortalColors.borderSoft),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.saldoPendiente > 0)
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
                                    weight: FontWeight.w500,
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
                                  size: 13,
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
                          if ((item.plusvaliaPct ?? 0) > 0)
                            _PlusvaliaText(pct: item.plusvaliaPct, size: 11),
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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusCard),
            border: Border.all(
              color: hovered ? PortalColors.borderSoft : PortalColors.border,
            ),
            boxShadow: hovered ? _hoverShadow : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen 120×100 con badge check de entregada
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 120,
                            height: 100,
                            child: SozuNetworkImage(url: item.urlImagen),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: PortalColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _CardTitle(item: item)),
                              if (item.entregadaDesde != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Tuya desde '
                                  '${formatDate(item.entregadaDesde)}',
                                  style: portalText(
                                    size: 10,
                                    weight: FontWeight.w500,
                                    color: PortalColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Valor actual · Plusvalía (2 columnas con divisor)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: PortalColors.borderSoft),
                                bottom:
                                    BorderSide(color: PortalColors.borderSoft),
                              ),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _MetricCell(
                                      first: true,
                                      label: 'Valor actual',
                                      value: Text(
                                        formatMXN(valor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: portalText(
                                          size: 14,
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
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Footer: chip de mantenimiento + Ver detalle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
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
                          if (mantoPendiente && manto.proximoPago != null)
                            Text(
                              'Próx. ${formatMXN(manto.saldoPendiente)} · '
                              '${formatDate(manto.proximoPago)}',
                              style: portalText(
                                size: 11,
                                color: PortalColors.mutedForeground,
                              ),
                            ),
                          Text(
                            '· Uso propio',
                            style: portalText(
                              size: 11,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _VerDetalle(hovered: hovered),
                  ],
                ),
              ),
              // Banner ámbar de mantenimiento pendiente
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
