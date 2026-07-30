import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Retardo entre un elemento y el siguiente.
const Duration _defaultStep = Duration(milliseconds: 40);

/// Techo del retardo acumulado. Sin él una lista larga tarda segundos en
/// terminar de aparecer (50 filas x 40 ms = 2 s).
const Duration _defaultMaxDelay = Duration(milliseconds: 320);

/// Distancia vertical que recorre un elemento al entrar. No se lee del token de
/// espaciado: es recorrido de movimiento, no aire entre cosas.
const double _defaultOffset = 12.0;

/// Un elemento que entra desvaneciéndose y subiendo unos píxeles.
///
/// La animación corre UNA sola vez: el disparo vive en `didChangeDependencies`
/// detrás de una bandera, así que un rebuild no la reinicia y cambiar [delay] u
/// [offset] en caliente no re-dispara nada.
///
/// Con movimiento reducido (`context.s.motion.normal` en `Duration.zero`)
/// devuelve al hijo tal cual, sin capas intermedias.
///
/// ```dart
/// SFadeInUp(child: ResumenCard(...))
/// SFadeInUp(delay: SStaggered.delayForIndex(i), child: ClientTile(...))
/// ```
class SFadeInUp extends StatefulWidget {
  final Widget child;

  /// Cuánto espera antes de empezar. Para escalonar ver
  /// [SStaggered.delayForIndex].
  final Duration delay;

  final double offset;

  const SFadeInUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = _defaultOffset,
  });

  @override
  State<SFadeInUp> createState() => _SFadeInUpState();
}

class _SFadeInUpState extends State<SFadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Progreso ya pasado por la curva de entrada.
  late Animation<double> _entry;

  /// La entrada ya se disparó (o se resolvió como "sin animación"). Impide que
  /// un rebuild vuelva a arrancarla.
  bool _started = false;

  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final motion = context.s.motion;
    _controller.duration = motion.normal;
    _entry = _controller.drive(CurveTween(curve: motion.enter));

    if (_started) return;
    _started = true;

    // Reduced motion: el elemento nace en su estado final, y se marca igual como
    // iniciada para que apagar el ajuste en caliente no anime lo ya visible.
    if (motion.normal == Duration.zero) {
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }

    _timer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin capas intermedias cuando no hay movimiento que aplicar.
    if (context.s.motion.normal == Duration.zero) return widget.child;

    return FadeTransition(
      opacity: _entry,
      // El `child` va por fuera del builder: el subárbol se construye una vez y
      // cada frame solo recalcula el `Transform`.
      child: AnimatedBuilder(
        animation: _entry,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _entry.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Aplica retardo incremental a una lista de hijos.
///
/// No impone scroll: solo ENVUELVE los hijos. El contenedor se pasa por
/// [builder]; sin él se usa una [Column].
///
/// ```dart
/// // Bloques de una pantalla:
/// SStaggered(children: [ResumenCard(...), PagosCard(...), DocsCard(...)])
///
/// // Otro contenedor:
/// SStaggered(
///   children: chips,
///   builder: (context, kids) => Wrap(spacing: 8, children: kids),
/// )
/// ```
///
/// Para un `ListView.builder` no hay lista de hijos sino un índice: ahí se usa
/// [delayForIndex] directamente.
///
/// ```dart
/// itemBuilder: (context, i) => SFadeInUp(
///   delay: SStaggered.delayForIndex(i),
///   child: ClientTile(...),
/// )
/// ```
class SStaggered extends StatelessWidget {
  final List<Widget> children;

  /// Retardo que se suma por cada posición.
  final Duration step;

  /// Techo del retardo acumulado: sin él una lista larga tarda segundos en
  /// terminar de aparecer.
  final Duration maxDelay;

  /// Píxeles que sube cada hijo al entrar.
  final double offset;

  /// Contenedor de los hijos ya envueltos. `null` = [Column].
  final Widget Function(BuildContext context, List<Widget> children)? builder;

  const SStaggered({
    super.key,
    required this.children,
    this.step = _defaultStep,
    this.maxDelay = _defaultMaxDelay,
    this.offset = _defaultOffset,
    this.builder,
  });

  /// Retardo que le toca al elemento [index], saturado en [maxDelay]. El índice
  /// 0 no espera.
  static Duration delayForIndex(
    int index, {
    Duration step = _defaultStep,
    Duration maxDelay = _defaultMaxDelay,
  }) {
    if (index <= 0) return Duration.zero;
    final delay = step * index;
    return delay > maxDelay ? maxDelay : delay;
  }

  @override
  Widget build(BuildContext context) {
    final wrapped = <Widget>[
      for (var i = 0; i < children.length; i++)
        SFadeInUp(
          delay: delayForIndex(i, step: step, maxDelay: maxDelay),
          offset: offset,
          child: children[i],
        ),
    ];

    final container = builder;
    if (container != null) return container(context, wrapped);

    return Column(
      mainAxisSize: MainAxisSize.min,
      // stretch y no el center por defecto: estos hijos son bloques de página
      // (cards, filas) y deben ocupar todo el ancho.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: wrapped,
    );
  }
}
