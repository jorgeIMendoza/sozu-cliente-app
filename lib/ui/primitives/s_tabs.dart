import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_pressable.dart';
import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Pestañas de sección: fila de etiquetas con subrayado en la activa.
///
/// Sustituye al `TabBar` de Material, que pinta con `colorScheme` y no con los
/// roles de SOZU. Y sobre todo NO trae `TabBarView`: el cuerpo lo pone quien la
/// usa, así que la página conserva UN solo scroll. Un `TabBarView` no tiene alto
/// intrínseco, así que obliga a meter el scroll dentro de cada pestaña y ahí es
/// donde se pierde el desplazamiento de página completa en escritorio.
///
/// En teléfono las pestañas se reparten el ancho; en escritorio se ajustan a su
/// texto y quedan a la izquierda, alineadas con la columna de contenido.
class STabs extends StatelessWidget {
  const STabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  /// Etiquetas, en orden. El índice es la identidad de la pestaña.
  final List<String> tabs;

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final reparteAncho = context.bp.isMobile;

    final items = <Widget>[
      for (var i = 0; i < tabs.length; i++)
        if (reparteAncho)
          Expanded(
            child: _Tab(
              label: tabs[i],
              activa: i == selected,
              onTap: () => onChanged(i),
            ),
          )
        else
          _Tab(
            label: tabs[i],
            activa: i == selected,
            onTap: () => onChanged(i),
          ),
    ];

    return DecoratedBox(
      // La línea corre por debajo de TODA la fila, no solo bajo las pestañas:
      // es lo que las ata al contenido en vez de dejarlas flotando.
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.color.border)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.start, children: items),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.activa, required this.onTap});

  final String label;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    return SPressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: t.radius.smBorder,
      // Sin hundido: una pestaña no es un botón, y el subrayado ya da el
      // acuse del cambio.
      pressScale: false,
      child: AnimatedContainer(
        duration: t.motion.fast,
        curve: t.motion.standard,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        decoration: BoxDecoration(
          // 2 px, no un borde de 1: bajo la línea gris de la fila un pelo más
          // grueso es lo que se lee como "esta es la activa".
          border: Border(
            bottom: BorderSide(
              color: activa ? c.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: t.text.label.copyWith(
            color: activa ? c.primaryHover : c.fgMuted,
            fontWeight: activa ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
