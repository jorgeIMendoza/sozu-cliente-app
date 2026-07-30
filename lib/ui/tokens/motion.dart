import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/radii.dart' show lerpDouble;

/// Escala de movimiento: duraciones, curvas y el factor de hundido al presionar.
///
/// Regla al elegir duración: cuanta más superficie se mueve, más lento. Un
/// cambio de color usa [instant]; una pantalla completa, [slow].
///
/// La variante [reduced] respeta la señal de "reducir movimiento" del sistema
/// operativo; la aplica `SozuAdaptiveTokens` en `lib/ui/theme/sozu_theme.dart`.
///
/// Uso: `AnimatedContainer(duration: context.s.motion.fast, curve: context.s.motion.standard, ...)`
@immutable
class SozuMotion {
  /// 90 ms - cambio de color en hover.
  final Duration instant;

  /// 150 ms - press, foco, toggles.
  final Duration fast;

  /// 240 ms - entrada y salida de elementos, expandir/colapsar.
  final Duration normal;

  /// 380 ms - transiciones de pantalla y hojas modales.
  final Duration slow;

  /// Curva por defecto de lo que cambia de estado sin cambiar de lugar
  /// (`Cubic(0.2, 0.0, 0.0, 1.0)`).
  final Curve standard;

  /// Para movimiento que recorre distancia: hojas, paneles laterales.
  final Curve emphasized;

  /// Entrada de algo que antes no estaba. Desacelera.
  final Curve enter;

  /// Salida de algo que se va. Acelera.
  final Curve exit;

  /// Escala al presionar (0.975).
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

  /// Escala completa. Aplica salvo que el sistema pida reducir movimiento.
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

  /// Todo en cero: nada se mueve, todo salta al estado final. [pressScale]
  /// vuelve a 1.0 y las curvas quedan en `Curves.linear` (no se evalúan).
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

  /// Interpola duraciones y [pressScale]. Las curvas son discretas: saltan a la
  /// mitad de la transición.
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

/// Interpola en microsegundos: redondear a milisegundo entero pierde precisión
/// en duraciones cortas.
Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
  microseconds: lerpDouble(
    a.inMicroseconds.toDouble(),
    b.inMicroseconds.toDouble(),
    t,
  ).round(),
);
