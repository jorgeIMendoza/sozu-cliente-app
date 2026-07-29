import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Escala con la que nace una pantalla en escritorio/tablet.
///
/// 0.98 son 2% de recorrido: en un área de contenido de 1000 px son 20 px
/// repartidos en los cuatro bordes, es decir 10 px por lado. Es el mínimo que el
/// ojo lee como "el contenido se asentó" y no alcanza a leerse como zoom. Por
/// debajo de ~0.99 el movimiento desaparece; por encima de ~0.95 la pantalla
/// parece venir desde el fondo, que es un gesto de modal, no de navegación.
///
/// No sale de [SozuMotion.pressScale] (0.975) aunque el número sea parecido: ese
/// token es el hundido del dedo sobre un control de 48 px, y si mañana se ajusta
/// el feedback del press no hay razón para que cambie cómo entra una pantalla.
const double _escalaEntrada = 0.98;

/// Fracción del ancho que recorre una pantalla al entrar en móvil.
///
/// 6% del ancho: en un teléfono de 390 px son ~23 px. Suficiente para leer la
/// dirección (viene de la derecha, o sea que se apiló encima) y corto para que la
/// pantalla no se sienta arrastrada. Un deslizamiento del 100% al estilo iOS
/// necesita 380-450 ms para no verse brusco; con 6% alcanza [SozuMotion.normal].
const double _deslizamientoMovil = 0.06;

/// Opacidad a la que queda la pantalla que se va atrás.
///
/// **Sin esto la transición se ve sucia.** A mitad del recorrido la pantalla que
/// entra ya va en ~0.87 de opacidad (la curva de entrada desacelera), y si la de
/// abajo sigue en 1.0 el ojo ve dos pantallas superpuestas: dos textos, dos
/// tarjetas, dos totales distintos en el mismo pixel. Atenuar la de abajo hace
/// que solo una compita por la atención.
///
/// No baja a 0 a propósito: la que entra NO tapa todo durante el recorrido (en
/// escritorio la escala 0.98 deja un borde alrededor, en móvil el 6% destapa una
/// franja). Con la de abajo en 0 esa franja mostraría el color del scaffold y se
/// leería como un destello.
const double _opacidadPaginaSaliente = 0.6;

/// Duración de la transición de página según el contexto.
///
/// Sale de [SozuMotion.normal] (240 ms) y no de [SozuMotion.slow] (380 ms) pese a
/// que el docstring del token reserve `slow` para "superficie completa": estas
/// pantallas son secundarias dentro del shell del portal, donde la sidebar y la
/// topbar NO se mueven. Lo que se anima es el área de contenido, no la pantalla,
/// y 380 ms para eso se sienten pesados. Reemplaza a los 280 ms cocidos que había
/// antes, que era el mismo orden de magnitud elegido a ojo.
///
/// Con "reducir animaciones" activo devuelve [Duration.zero] sin preguntar nada:
/// `context.s.motion` ya trae [SozuMotion.reduced], así que el cero viene del
/// token y no de un `if` que alguien pueda olvidar.
Duration sozuPageTransitionDuration(BuildContext context) =>
    context.s.motion.normal;

/// Constructor de transición de página del design system.
///
/// ## Por qué la transición depende del formato de pantalla
///
/// Antes las 15 rutas entraban con el mismo deslizamiento horizontal. En un
/// teléfono eso es correcto: hay una pila de navegación real, la pantalla se
/// apiló encima de la anterior y existe un gesto de retroceso que la devuelve
/// hacia la derecha. El movimiento cuenta esa historia.
///
/// En escritorio la misma animación miente. El usuario hizo clic en un ítem de la
/// sidebar, que sigue ahí, quieta, a la izquierda: nada "vino de un lado". Un
/// deslizamiento horizontal sugiere una dirección que no ocurrió, y el ojo lo
/// registra como que la interfaz se sacude al navegar. Ahí el movimiento correcto
/// es el mínimo que confirme que el contenido cambió: opacidad más una escala de
/// 2% que hace que el contenido "se asiente" en su lugar, sin insinuar de dónde
/// vino.
///
/// El corte es [SozuBreakpoint.isMobile], no `kIsWeb`: una tablet en horizontal y
/// una ventana de Chrome ancha se comportan igual porque tienen el mismo espacio,
/// que es lo que decide el layout (ver `breakpoints.dart`).
///
/// ## La segunda animación no es decorativa
///
/// `secondaryAnimation` es la que corre cuando ESTA página deja de ser la de
/// arriba. Se usa para atenuarla hasta [_opacidadPaginaSaliente]: sin eso las dos
/// páginas se superponen a opacidad completa a mitad del recorrido y se ve sucio
/// (ver el docstring de esa constante). Se le aplica [SozuMotion.exit], que
/// ACELERA: lo que se va no debe retener la atención. La entrada, en cambio, usa
/// [SozuMotion.enter], que desacelera y se asienta.
///
/// ## Reducir animaciones
///
/// Devuelve el hijo pelón: ni [FadeTransition] ni `Transform` en el árbol. No
/// basta con duración cero -un `FadeTransition` con opacidad 1 sigue creando una
/// capa de composición y un `RepaintBoundary` implícito por pantalla, y quien
/// pidió que nada se mueva no tiene por qué pagar eso.
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

  // Dos capas de opacidad y no una: se multiplican, y cada una la maneja una
  // animación distinta (entrada y salida son independientes -una página puede
  // estar entrando mientras la de abajo se atenúa). Para la página que entra la
  // capa externa es un no-op (secondaryAnimation está en 0, opacidad 1); para la
  // que se queda atrás lo es la interna (animation ya está en 1).
  return FadeTransition(
    opacity: Tween<double>(
      begin: 1,
      end: _opacidadPaginaSaliente,
    ).animate(salida),
    child: FadeTransition(opacity: entrada, child: contenido),
  );
}
