import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Etiqueta de grupo dentro de una lista: texto en mayúsculas, opcionalmente con
/// icono. Separa secciones sin gastar el peso visual de un título.
///
/// Usa el token `overline`, que existe justo para esto (11 px / w600 /
/// tracking 0.4). Antes cada pantalla lo reinventaba con
/// `TextStyle(fontSize: 12, fontWeight: w700, letterSpacing: 0.6)`.
class SSectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;

  /// Contenido a la derecha (contador, acción).
  final Widget? trailing;

  const SSectionLabel({
    super.key,
    required this.text,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Padding(
      padding: EdgeInsets.only(top: t.space.xxs, bottom: t.space.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: t.color.fgSubtle),
            SizedBox(width: t.space.xxs + 2),
          ],
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: t.text.overline.copyWith(color: t.color.fgSubtle),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
