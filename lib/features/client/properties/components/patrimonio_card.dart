import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/network_image.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Tarjeta de propiedad entregada para "Mi patrimonio": muestra métricas de
/// mercado (valor actual y plusvalía) en vez del avance de pago, por eso no
/// reutiliza `PropertyCardWidget`. Los campos null se ocultan, nunca dan $0.
class PatrimonioCard extends StatelessWidget {
  final PropiedadCard item;

  /// Cuenta de mantenimiento asociada a la propiedad (null si no hay cruce).
  final MantenimientoCard? mantenimiento;
  final VoidCallback onTap;

  const PatrimonioCard({
    super.key,
    required this.item,
    this.mantenimiento,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final manto = mantenimiento;
    final mantoPendiente = manto != null && manto.saldoPendiente > 0;
    final tieneValor = item.valorActual != null;
    final tienePlusvalia =
        item.plusvaliaPct != null || item.plusvaliaMonto != null;

    // "Proyecto · U-nombre" (sin duplicar el prefijo si ya viene en el dato).
    final unidad = item.nombre == '-' || item.nombre.startsWith('U-')
        ? item.nombre
        : 'U-${item.nombre}';

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: SozuNeutral.n900.withValues(alpha: 0.08),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con badge "Entregada" (Hero: transición al detalle).
            Stack(
              children: [
                Hero(
                  tag: 'prop-img-${item.id}',
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: SozuNetworkImage(url: item.urlImagen),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: SBadge(label: 'Entregada', tone: SBadgeTone.positive),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: item.proyecto,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: tone.fg,
                                ),
                              ),
                              TextSpan(
                                text: ' · $unidad',
                                style: TextStyle(color: tone.fgMuted),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      if (item.entregadaDesde != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Tuya desde ${formatDate(item.entregadaDesde)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tone.fgSubtle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.ubicacion != null &&
                      item.ubicacion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: tone.fgSubtle,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.ubicacion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: tone.fgSubtle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (tieneValor || tienePlusvalia) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: tone.border),
                          bottom: BorderSide(color: tone.border),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tieneValor)
                            Expanded(
                              child: _Metrica(
                                label: 'VALOR ACTUAL',
                                child: Text(
                                  formatMXN(item.valorActual),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tone.fg,
                                  ),
                                ),
                              ),
                            ),
                          if (tieneValor && tienePlusvalia)
                            Container(
                              width: 1,
                              height: 34,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              color: tone.border,
                            ),
                          if (tienePlusvalia)
                            Expanded(
                              child: _Metrica(
                                label: 'PLUSVALÍA',
                                child: _Plusvalia(
                                  pct: item.plusvaliaPct,
                                  monto: item.plusvaliaMonto,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (manto != null && manto.saldoPendiente > 0)
              _bannerMantenimiento(tone, manto),
            // Footer.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tone.border)),
              ),
              child: Row(
                children: [
                  if (manto != null && !mantoPendiente)
                    const SBadge(
                      label: 'Mantenimiento al día',
                      tone: SBadgeTone.positive,
                    ),
                  const Spacer(),
                  Text(
                    'Ver detalle ›',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tone.primaryHover,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner ámbar de mantenimiento pendiente (quick win sin backend nuevo).
  Widget _bannerMantenimiento(SozuColorRoles tone, MantenimientoCard m) {
    return Container(
      width: double.infinity,
      color: tone.warningSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.build_outlined, size: 14, color: SozuAmber.strong),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // Cuota MENSUAL de mantenimiento (decisión de producto, igual que
              // Degrada al saldo pendiente si el backend no manda cuota.
              item.cuotaMensual > 0
                  ? 'Mantenimiento · ${formatMXN(item.cuotaMensual)} /mes'
                  : 'Mantenimiento pendiente ${formatMXN(m.saldoPendiente)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SozuAmber.strong,
              ),
            ),
          ),
          if (m.proximoPago != null) ...[
            const SizedBox(width: 8),
            Text(
              'Próx. ${formatDate(m.proximoPago)}',
              style: const TextStyle(fontSize: 11, color: SozuAmber.strong),
            ),
          ],
        ],
      ),
    );
  }
}

/// Celda de métrica: label pequeña en mayúsculas + valor.
class _Metrica extends StatelessWidget {
  final String label;
  final Widget child;

  const _Metrica({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: tone.fgSubtle,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// Plusvalía en % (y monto si también llega): verde al alza, rojo a la baja.
class _Plusvalia extends StatelessWidget {
  final double? pct;
  final double? monto;

  const _Plusvalia({this.pct, this.monto});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final positiva = (pct ?? monto ?? 0) >= 0;
    final color = positiva ? tone.positive : tone.danger;
    final principal = pct != null
        ? '${pct! >= 0 ? '+' : ''}${pct!.toStringAsFixed(1)}%'
        : '${monto! >= 0 ? '+' : ''}${formatMXN(monto)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              positiva ? Icons.trending_up : Icons.trending_down,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                principal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (pct != null && monto != null)
          Text(
            '${monto! >= 0 ? '+' : ''}${formatMXN(monto)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color),
          ),
      ],
    );
  }
}
