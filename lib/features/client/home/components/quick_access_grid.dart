import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Un acceso del grid: icono, etiqueta y destino. [badge] solo cuando hay algo
/// que avisar: una pastilla siempre visible deja de leerse.
@immutable
class QuickAccessItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  /// Destaca el acceso con el tinte de marca. Reservado a UNO: si todos
  /// resaltan, ninguno lo hace.
  final bool featured;

  const QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.featured = false,
  });
}

/// Grid de accesos rápidos del inicio: 4 columnas en móvil, 8 en escritorio.
/// Va primero para que lo que el cliente viene a hacer quede sin scroll.
class QuickAccessGrid extends StatelessWidget {
  final List<QuickAccessItem> items;

  const QuickAccessGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // 4 columnas en móvil (dos filas de 4) y 8 en escritorio (una sola fila).
    // En tablet caben 8 pero quedan angostas: se mantienen 4.
    final columnas = context.responsive(mobile: 4, tablet: 4, desktop: 8);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.md,
      ),
      // Sin borde: el panel ya se separa del fondo por su superficie, y una
      // línea alrededor de ocho cuadros pintados es una retícula de más.
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: t.radius.lgBorder,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Reparto exacto: un Wrap con anchos fijos deja hueco variable.
          final ancho = c.maxWidth / columnas;
          return Wrap(
            runSpacing: t.space.md,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: ancho,
                  child: SFadeInUp(
                    delay: SStaggered.delayForIndex(i),
                    child: _QuickAccessTile(item: items[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final QuickAccessItem item;

  const _QuickAccessTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final icono = item.featured ? c.primaryHover : c.fg;

    return SPressable(
      onTap: item.onTap,
      borderRadius: t.radius.lgBorder,
      semanticLabel: item.label,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.xxs,
          vertical: t.space.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El badge desborda la esquina del cuadro del icono, por eso el
            // Stack no recorta.
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Contorno de medio píxel en vez de cuadro relleno: ocho
                // rellenos juntos pesan más que los iconos que enmarcan.
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.featured ? c.primarySoft : null,
                    borderRadius: t.radius.lgBorder,
                    border: Border.all(
                      color: item.featured ? c.primaryBorder : c.borderSoft,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(item.icon, size: 24, color: icono),
                ),
                if (item.badge != null)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: _Badge(text: item.badge!),
                  ),
              ],
            ),
            SizedBox(height: t.space.xxs),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.text.caption.copyWith(color: c.fg, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastilla de aviso sobre el icono. Ámbar y no rojo: avisa, no alarma.
class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xxs, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color.warning,
        borderRadius: t.radius.fullBorder,
        border: Border.all(color: t.color.surface, width: 2),
      ),
      child: Text(
        text,
        style: t.text.overline.copyWith(
          color: t.color.onPrimary,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
