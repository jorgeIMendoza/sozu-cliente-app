import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/radii.dart' show lerpDouble;

/// Escala de movimiento: duraciones, curvas y el factor de hundido al presionar.
///
/// **Este token es nuevo: antes no existía escala de movimiento.** Cada
/// animación de la app traía su propio `Duration(milliseconds: 200)` o `300`
/// elegido a ojo, así que dos elementos que entran juntos no llegan juntos y la
/// interfaz se siente hecha por manos distintas. El movimiento es parte de la
/// identidad tanto como el color: si no está tokenizado, no es consistente.
///
/// ### Por qué exactamente cuatro duraciones
///
/// El rango útil es mucho más estrecho de lo que parece. Por debajo de unos
/// 100 ms el ojo no alcanza a percibir la transición: ve el estado final y la
/// animación solo gasta frames. Por encima de unos 400 ms el usuario ya está
/// esperando a la interfaz, y esa espera se lee como lentitud del sistema, no
/// como elegancia. Es decir: todo lo que sirve vive entre ~90 y ~400 ms.
///
/// Dentro de esa ventana, dos duraciones solo se distinguen si una es del orden
/// de 1.5x la otra. De ahí salen cuatro pasos (90 / 150 / 240 / 380, cada uno
/// ~1.6x el anterior) y no seis: un quinto valor intermedio sería
/// indistinguible de su vecino y solo daría a quien escribe la pantalla una
/// decisión más que tomar sin criterio para tomarla.
///
/// La regla al elegir: **cuanta más superficie se mueve, más lento**. Un cambio
/// de color ocupa cero área ([instant]); una pantalla completa ocupa todo
/// ([slow]).
///
/// ### Por qué las curvas no son `Curves.easeInOut`
///
/// `easeInOut` arranca despacio, y arrancar despacio después de un toque se
/// siente como retardo de entrada. [standard] es casi vertical al inicio y
/// frena al final: el movimiento responde de inmediato y se asienta. Son las
/// mismas curvas de Material 3, elegidas para no reinventar algo que ya está
/// medido.
///
/// ### Accesibilidad
///
/// La variante [reduced] no es un lujo: existe para respetar la señal de
/// "reducir movimiento" del sistema operativo. Ver
/// `SozuAdaptiveTokens` en `lib/ui/theme/sozu_theme.dart`.
///
/// Uso: `AnimatedContainer(duration: context.s.motion.fast, curve: context.s.motion.standard, ...)`
@immutable
class SozuMotion {
  /// 90 ms - cambio de color en hover. No se percibe como transición y no debe:
  /// solo quita el corte seco del cambio instantáneo.
  final Duration instant;

  /// 150 ms - press, foco, toggles. El límite superior de lo que todavía se
  /// siente como respuesta directa al dedo y no como animación.
  final Duration fast;

  /// 240 ms - entrada y salida de elementos, expandir/colapsar. Alcanza para
  /// que el ojo siga de dónde salió la cosa.
  final Duration normal;

  /// 380 ms - transiciones de pantalla y hojas modales. Es lo único que mueve
  /// superficie completa, y por eso lo único que puede permitirse tardar.
  final Duration slow;

  /// Curva por defecto de todo lo que cambia de estado sin cambiar de lugar.
  /// Sale acelerada y desacelera al final (`Cubic(0.2, 0.0, 0.0, 1.0)`).
  final Curve standard;

  /// Para movimiento que recorre distancia (hojas, paneles laterales): frena
  /// más largo, lo que da la sensación de peso sin agregar milisegundos.
  final Curve emphasized;

  /// Entrada de algo que antes no estaba. Desacelera: aparece rápido y se
  /// acomoda.
  final Curve enter;

  /// Salida de algo que se va. Acelera: se despide sin retener la atención en
  /// un elemento que ya no importa.
  final Curve exit;

  /// Escala al presionar. 0.975 son 2.5%: en un target de 48 px es poco más de
  /// 1 px de recorrido, suficiente para confirmar el toque e insuficiente para
  /// parecer que el botón se cae dentro de la pantalla.
  final double pressScale;

  const SozuMotion({
    required this.instant,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.standard,
    required this.emphasized,
    required this.enter,
    required this.exit,
    required this.pressScale,
  });

  /// Escala completa. Es la que aplica salvo que el sistema pida lo contrario.
  static const SozuMotion full = SozuMotion(
    instant: Duration(milliseconds: 90),
    fast: Duration(milliseconds: 150),
    normal: Duration(milliseconds: 240),
    slow: Duration(milliseconds: 380),
    standard: Cubic(0.2, 0.0, 0.0, 1.0),
    emphasized: Cubic(0.05, 0.7, 0.1, 1.0),
    enter: Curves.easeOutCubic,
    exit: Curves.easeInCubic,
    pressScale: 0.975,
  );

  /// Todo en cero: nada se mueve, todo salta al estado final.
  ///
  /// No se "acortan" las duraciones a la mitad, se anulan. Media animación
  /// sigue siendo movimiento, y el punto es que no haya. `pressScale` vuelve a
  /// 1.0 por lo mismo: el hundido es movimiento, y el feedback del press ya lo
  /// da el cambio de color, que sí sobrevive.
  ///
  /// Las curvas quedan en `Curves.linear` porque con `Duration.zero` la curva
  /// no se evalúa; dejarlas es solo para que nada reciba `null`.
  static const SozuMotion reduced = SozuMotion(
    instant: Duration.zero,
    fast: Duration.zero,
    normal: Duration.zero,
    slow: Duration.zero,
    standard: Curves.linear,
    emphasized: Curves.linear,
    enter: Curves.linear,
    exit: Curves.linear,
    pressScale: 1.0,
  );

  /// Interpola duraciones y [pressScale].
  ///
  /// Las curvas son discretas: no existe "media curva" con sentido visual, así
  /// que saltan a la mitad de la transición, igual que la densidad en
  /// `SozuTheme.lerp`.
  static SozuMotion lerp(SozuMotion a, SozuMotion b, double t) => SozuMotion(
    instant: _lerpDuration(a.instant, b.instant, t),
    fast: _lerpDuration(a.fast, b.fast, t),
    normal: _lerpDuration(a.normal, b.normal, t),
    slow: _lerpDuration(a.slow, b.slow, t),
    standard: t < 0.5 ? a.standard : b.standard,
    emphasized: t < 0.5 ? a.emphasized : b.emphasized,
    enter: t < 0.5 ? a.enter : b.enter,
    exit: t < 0.5 ? a.exit : b.exit,
    pressScale: lerpDouble(a.pressScale, b.pressScale, t),
  );

  @override
  bool operator ==(Object other) =>
      other is SozuMotion &&
      other.instant == instant &&
      other.fast == fast &&
      other.normal == normal &&
      other.slow == slow &&
      other.standard == standard &&
      other.emphasized == emphasized &&
      other.enter == enter &&
      other.exit == exit &&
      other.pressScale == pressScale;

  @override
  int get hashCode => Object.hash(
    instant,
    fast,
    normal,
    slow,
    standard,
    emphasized,
    enter,
    exit,
    pressScale,
  );
}

/// Se interpola en microsegundos, no en milisegundos: a 90 ms el redondeo a
/// milisegundo entero perdería casi 1% del valor en cada paso intermedio.
Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
  microseconds: lerpDouble(
    a.inMicroseconds.toDouble(),
    b.inMicroseconds.toDouble(),
    t,
  ).round(),
);
