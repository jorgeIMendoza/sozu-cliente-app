import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';
import 'fx.dart';
import 'network_image.dart';

/// Tarjeta de propiedad: imagen, proyecto, ubicación, métricas (valor
/// estimado / plusvalía / avance de pago), chips informativos y CTA de pago.
/// Los campos nuevos del backend son opcionales: si vienen null se ocultan.
class PropertyCardWidget extends StatelessWidget {
  final PropiedadCard item;
  final VoidCallback onTap;

  const PropertyCardWidget({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);

    final ubicacion = item.ubicacion?.trim();
    final tieneUbicacion = ubicacion != null && ubicacion.isNotEmpty;
    final tieneValor = item.valorActual != null && item.valorActual! > 0;
    final tienePlusvalia = item.plusvaliaPct != null;
    final chips = <Widget>[
      if (item.proximaFecha != null)
        StatusBadge(
          label: 'Próx. pago ${formatDate(item.proximaFecha)}',
          tone: BadgeTone.pending,
        ),
      if (item.docsPendientes > 0)
        StatusBadge(
          label: item.docsPendientes == 1
              ? '1 doc pendiente'
              : '${item.docsPendientes} docs pendientes',
        ),
    ];

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: SozuColors.slate900.withValues(alpha: 0.08),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen (Hero: transición compartida con el detalle)
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
                Positioned(
                  top: 8,
                  right: 8,
                  child: _estatusBadge(item),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.proyecto.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: tone.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tone.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        item.modelo,
                        style: TextStyle(fontSize: 12, color: tone.textMuted),
                      ),
                    ],
                  ),
                  if (tieneUbicacion) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 13, color: tone.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ubicacion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 11, color: tone.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatMXN(item.monto),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),

                  // Métricas: valor estimado y plusvalía (solo si el backend
                  // las manda) junto al avance de pago existente.
                  if (tieneValor || tienePlusvalia) ...[
                    const SizedBox(height: 12),
                    Divider(color: tone.border, height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        if (tieneValor)
                          _Metric(
                            label: 'Valor estimado',
                            child: Text(
                              formatMXNCompact(item.valorActual),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tone.textPrimary,
                              ),
                            ),
                          ),
                        if (tienePlusvalia)
                          _Metric(
                            label: 'Plusvalía',
                            child: _PlusvaliaValue(pct: item.plusvaliaPct!),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Avance de pago',
                        style: TextStyle(fontSize: 11, color: tone.textMuted),
                      ),
                      Text(
                        '${item.avancePago}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tone.positive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SozuProgressBar(percent: item.avancePago),

                  // Chips informativos (próximo pago / docs pendientes).
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: chips),
                  ],

                  // Footer: Ver detalle + CTA Pagar cuando hay pago pendiente.
                  const SizedBox(height: 12),
                  Divider(color: tone.border, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ver detalle →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tone.primaryDark,
                          ),
                        ),
                      ),
                      if (item.pagoPendiente)
                        FilledButton(
                          onPressed: () =>
                              context.push('/propiedad/${item.id}'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Pagar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge de estatus con la etiqueta derivada de la etapa activa
  /// (PropiedadCard.estatusDerivado), mismo mapeo que el chip del detalle.
  Widget _estatusBadge(PropiedadCard item) {
    final tone = switch (item.etapaActiva) {
      'pago_final' => BadgeTone.pending,
      'entrega' || 'post_entrega' => BadgeTone.positive,
      _ => BadgeTone.neutral,
    };
    return StatusBadge(label: item.estatusDerivado, tone: tone);
  }
}

/// Métrica compacta con etiqueta pequeña arriba y valor abajo.
class _Metric extends StatelessWidget {
  final String label;
  final Widget child;

  const _Metric({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: tone.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

/// Valor de plusvalía con icono de tendencia; verde si sube, rojo si baja.
class _PlusvaliaValue extends StatelessWidget {
  final double pct;

  const _PlusvaliaValue({required this.pct});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final sube = pct >= 0;
    final color = sube ? tone.positive : tone.negative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          sube ? Icons.trending_up : Icons.trending_down,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          '${sube ? '+' : ''}${pct.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
