import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_pressable.dart';
import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Pestañas de sección: fila de etiquetas con subrayado en la activa. El
/// cuerpo lo pinta quien la usa.
///
/// WARN: NO uses `TabBarView` con esto. No tiene alto intrínseco, así que obliga a
/// meter un scroll dentro de cada pestaña y la página pierde su scroll único.
class STabs extends StatelessWidget {
  const STabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  /// Etiquetas en orden; el índice identifica la pestaña.
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
      pressScale: false,
      child: AnimatedContainer(
        duration: t.motion.fast,
        curve: t.motion.standard,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        decoration: BoxDecoration(
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
