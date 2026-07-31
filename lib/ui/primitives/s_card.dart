import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Variantes de card, por RELACIÓN con el fondo de la página.
///
/// **NO son un interruptor de plataforma.** La app tenía dos cards, `AppCard` en
/// móvil y `PortalCard` en web, y esa era justo la fractura: el responsive lo
/// resuelven los tokens y los breakpoints, no dos componentes.
enum SCardVariant {
  /// Se separa del fondo: borde de 1 px más sombra suave. La card por defecto de
  /// toda la app.
  elevated,

  /// Plana: mismo borde, sin sombra. Para cards ANIDADAS dentro de otra
  /// superficie, donde una segunda sombra ensucia en vez de separar.
  outlined,
}

/// Superficie contenedora del design system: fondo, radio, borde y sombra.
///
/// Toda la apariencia se resuelve en [_SCardStyle.resolve]; agregar una variante
/// es agregar un `case` ahí, sin tocar el árbol de widgets.
///
/// No es interactiva: una card que responde al toque va envuelta en
/// `SPressable`.
///
/// ```dart
/// SCard(child: Text('Hola'))
/// SCard.outlined(padding: EdgeInsets.zero, clip: true, child: tabla)
/// ```
class SCard extends StatelessWidget {
  final Widget child;

  final SCardVariant variant;

  /// `null` = `t.space.md` (16). `EdgeInsets.zero` para contenido a sangre
  /// (headers de color propio, tablas, imágenes).
  final EdgeInsetsGeometry? padding;

  /// Override del color del borde. En [SCardVariant.outlined] reemplaza al borde
  /// por defecto; en [SCardVariant.elevated] agrega uno, que no lleva.
  final Color? borderColor;

  /// Recorta el hijo al radio. Obligatorio si el contenido pinta hasta el filo.
  final bool clip;

  /// Ancho completo del padre. `false` la deja medir su contenido (celda de una
  /// fila, item de grid).
  final bool fullWidth;

  const SCard({
    super.key,
    required this.child,
    this.variant = SCardVariant.elevated,
    this.padding,
    this.borderColor,
    this.clip = false,
    this.fullWidth = true,
  });

  /// Atajo legible de [SCardVariant.outlined].
  const SCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.clip = false,
    this.fullWidth = true,
  }) : variant = SCardVariant.outlined;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final style = _SCardStyle.resolve(
      variant: variant,
      colors: t.color,
      theme: t,
      borderColor: borderColor,
    );

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: padding ?? t.space.allMd,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: style.radius,
        border: style.border,
        boxShadow: style.shadow,
      ),
      child: child,
    );
  }
}

/// Grosor del borde. Igual en las dos variantes: la que no lo pinta es la que no
/// tiene borde, no una con borde más fino.
const double _borderWidth = 1;

/// Apariencia ya resuelta de una card: **el único lugar del archivo que sabe de
/// variantes**. Todos los campos son requeridos, así que una variante nueva no
/// puede olvidarse de uno.
@immutable
class _SCardStyle {
  final Color background;

  /// `null` = sin borde.
  final Border? border;

  final BorderRadius radius;
  final List<BoxShadow> shadow;

  const _SCardStyle({
    required this.background,
    required this.border,
    required this.radius,
    required this.shadow,
  });

  /// Traduce (variante × roles de color) a apariencia concreta.
  ///
  /// [colors] llega aparte de [theme] para poder resolver contra un set fijo
  /// ([SozuColorRoles.light]) sin `BuildContext`.
  factory _SCardStyle.resolve({
    required SCardVariant variant,
    required SozuColorRoles colors,
    required SozuTheme theme,
    Color? borderColor,
  }) {
    final radius = theme.radius.lgBorder;

    switch (variant) {
      // Borde Y sombra. Antes eran dos componentes: `AppCard` (movil) tenia
      // sombra sin borde y `PortalCard` (web) borde sin sombra. La distincion era
      // por plataforma, y el responsive ya lo resuelven los tokens: una sola card
      // lleva las dos cosas, el borde para definirla y la sombra para separarla
      // del fondo.
      case SCardVariant.elevated:
        return _SCardStyle(
          background: colors.surface,
          border: Border.all(
            color: borderColor ?? colors.border,
            width: _borderWidth,
          ),
          radius: radius,
          shadow: theme.shadow.md,
        );

      case SCardVariant.outlined:
        return _SCardStyle(
          background: colors.surface,
          border: Border.all(
            color: borderColor ?? colors.border,
            width: _borderWidth,
          ),
          radius: radius,
          shadow: theme.shadow.flat,
        );
    }
  }
}
