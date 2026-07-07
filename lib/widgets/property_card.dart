import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';
import 'fx.dart';
import 'network_image.dart';

/// Tarjeta de propiedad: imagen, proyecto, monto y barra de avance.
class PropertyCardWidget extends StatelessWidget {
  final PropiedadCard item;
  final VoidCallback onTap;

  const PropertyCardWidget({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
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
            // Imagen
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: SozuNetworkImage(url: item.urlImagen),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: StatusBadge(label: item.estatus),
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
                  const SizedBox(height: 8),
                  Text(
                    formatMXN(item.monto),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
