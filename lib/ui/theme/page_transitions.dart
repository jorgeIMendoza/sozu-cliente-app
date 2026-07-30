import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Escala con la que nace una pantalla en escritorio/tablet: 2% de recorrido, el
/// mínimo que se lee como "el contenido se asentó" sin leerse como zoom.
const double _escalaEntrada = 0.98;

/// Fracción del ancho que recorre una pantalla al entrar en móvil: 6% (~23 px en
/// un teléfono de 390 px), suficiente para leer la dirección del apilado.
const double _deslizamientoMovil = 0.06;

/// Opacidad a la que queda la pantalla que se va atrás.
///
/// Sin esto las dos páginas se superponen a opacidad completa a mitad del
/// recorrido y se ve sucio. No baja a 0 porque la que entra no tapa todo
/// mientras recorre, y la franja destapada se leería como un destello.
const double _opacidadPaginaSaliente = 0.6;

/// Duración de la transición de página. Con "reducir animaciones" activo
/// devuelve [Duration.zero], porque el cero ya viene del token.
Duration sozuPageTransitionDuration(BuildContext context) =>
    context.s.motion.normal;

/// Constructor de transición de página del design system.
///
/// En móvil desliza (hay pila de navegación real); en escritorio solo opacidad +
/// escala, porque la sidebar no se movió y nada "vino de un lado". El corte es
/// [SozuBreakpoint.isMobile] y no `kIsWeb`: lo que decide es el espacio.
///
/// Con "reducir animaciones" devuelve el hijo pelón, sin [FadeTransition] ni
/// `Transform`: duración cero no basta, la capa de composición se seguiría
/// creando por pantalla.
Widget sozuPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final motion = context.s.motion;

  // Señal de "reducir movimiento" del sistema: el token ya viene anulado.
  if (motion.normal == Duration.zero) return child;

  final entrada = CurvedAnimation(parent: animation, curve: motion.enter);
  final salida = CurvedAnimation(
    parent: secondaryAnimation,
    curve: motion.exit,
  );

  final contenido = context.bp.isMobile
      ? SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(_deslizamientoMovil, 0),
            end: Offset.zero,
          ).animate(entrada),
          child: child,
        )
      : ScaleTransition(
          scale: Tween<double>(begin: _escalaEntrada, end: 1).animate(entrada),
          child: child,
        );

  // Dos capas de opacidad porque se multiplican y entrada y salida son
  // independientes: una página puede estar entrando mientras la de abajo se
  // atenúa. En cada caso una de las dos capas es un no-op.
  return FadeTransition(
    opacity: Tween<double>(
      begin: 1,
      end: _opacidadPaginaSaliente,
    ).animate(salida),
    child: FadeTransition(opacity: entrada, child: contenido),
  );
}
