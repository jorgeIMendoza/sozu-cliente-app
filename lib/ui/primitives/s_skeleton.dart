import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Forma del placeholder. Debe coincidir con la del contenido que va a llegar,
/// o el layout salta al terminar la carga.
enum SSkeletonShape {
  /// Bloque rectangular: imágenes, cards, celdas, chips.
  box,

  /// Círculo: avatares, iconos, badges redondos.
  circle,

  /// Renglones de texto: títulos, párrafos, etiquetas.
  text,
}

/// Duración de un ciclo completo del shimmer.
///
/// NO es un token de movimiento: los tokens describen transiciones de estado y
/// esto es un loop ambiental que corre mientras no hay noticias del servidor.
const Duration _shimmerCycle = Duration(milliseconds: 1300);

/// Placeholder de carga global del design system.
///
/// Con movimiento reducido (`context.s.motion` en `SozuMotion.reduced`) no anima
/// nada: pinta el bloque estático con `skeletonBase`.
///
/// ```dart
/// const SSkeleton(width: 120, height: 100, radius: 12)   // imagen de card
/// const SSkeleton.circle(size: 40)                        // avatar
/// const SSkeleton.text(lines: 3)                          // párrafo
/// ```
class SSkeleton extends StatefulWidget {
  /// Alto de un bloque cuando no se especifica otro (un renglón de texto).
  static const double defaultHeight = 16;

  /// `null` = ocupa el ancho que le dé el padre.
  final double? width;

  final double height;

  final SSkeletonShape shape;

  /// `null` = radio del token que corresponde a [shape].
  final double? radius;

  /// Renglones de [SSkeletonShape.text]. Se ignora en las demás formas.
  final int lines;

  /// Ancho del último renglón como fracción del resto. Ver [SSkeleton.text].
  final double lastLineFactor;

  const SSkeleton({
    super.key,
    this.width,
    this.height = defaultHeight,
    this.shape = SSkeletonShape.box,
    this.radius,
  }) : lines = 1,
       lastLineFactor = 1;

  /// Círculo de [size] x [size]. Avatares, iconos.
  const SSkeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      shape = SSkeletonShape.circle,
      radius = null,
      lines = 1,
      lastLineFactor = 1;

  /// Bloque de [lines] renglones de texto; el último sale más corto (~60%).
  ///
  /// Con [width] en `null` el padre tiene que dar un ancho acotado (una card,
  /// un `Expanded`).
  ///
  /// [width] controla el ancho de los RENGLONES, no el espacio que se reserva:
  /// con constraints tight del padre el widget ocupa lo que le dan (Flutter no
  /// permite medir menos) y pinta los renglones al ancho pedido.
  const SSkeleton.text({
    super.key,
    this.lines = 3,
    this.width,
    this.lastLineFactor = 0.6,
  }) : assert(lines >= 1, 'un bloque de texto tiene al menos un renglón'),
       assert(
         lastLineFactor > 0 && lastLineFactor <= 1,
         'el último renglón mide entre algo y todo el ancho',
       ),
       height = defaultHeight,
       shape = SSkeletonShape.text,
       radius = null;

  @override
  State<SSkeleton> createState() => _SSkeletonState();
}

class _SSkeletonState extends State<SSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Última decisión de animar, para no reiniciar el ciclo en cada rebuild.
  bool _animating = false;

  // Se crea aquí y no con `late final` en la declaración: un skeleton que nunca
  // animó lo construiría dentro de `dispose()` y revienta al desmontarse.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _shimmerCycle);
  }

  // Arranca aquí y no en `initState`: los tokens son un InheritedWidget y
  // leerlos en `initState` no registra la dependencia.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(_shouldAnimate(context));
  }

  void _sync(bool animate) {
    if (animate == _animating) return;
    _animating = animate;
    if (animate) {
      _controller.repeat();
    } else {
      // `reset` además de `stop`: si no, el bloque queda congelado con la banda
      // brillante cruzada.
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Se detecta por el token y no por `MediaQuery`, para respetar también los
  /// temas que fuerzan movimiento reducido (previews, golden tests).
  bool _shouldAnimate(BuildContext context) =>
      context.s.motion.instant != Duration.zero;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // No se llama `_sync` aquí: arrancar o detener el ticker es un efecto y no
    // va dentro de un `build`.
    final animate = _animating;

    if (!animate) return _content(t, null);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _content(t, _controller.value),
    );
  }

  /// [progress] `null` = sin animación (movimiento reducido).
  Widget _content(SozuTheme t, double? progress) {
    if (widget.shape != SSkeletonShape.text) {
      return _block(t, progress, width: widget.width);
    }

    final gap = t.space.xs;
    final rows = <Widget>[];
    for (var i = 0; i < widget.lines; i++) {
      // La separación va antes de cada renglón salvo el primero, para que
      // `lines: 1` no arrastre un hueco al final.
      if (i > 0) rows.add(SizedBox(height: gap));
      final isLast = i == widget.lines - 1 && widget.lines > 1;
      final row = _block(t, progress, width: widget.width);
      rows.add(
        isLast
            ? FractionallySizedBox(
                widthFactor: widget.lastLineFactor,
                alignment: AlignmentDirectional.centerStart,
                child: row,
              )
            : row,
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );

    // El Align es lo que hace efectivo el `width`: un `SizedBox` solo NO puede
    // encogerse por debajo de una constraint tight del padre, y el caso comun es
    // justo ese (una card o un `Expanded` dan ancho fijo). Align afloja las
    // constraints del hijo, asi que el SizedBox si aplica su ancho.
    return widget.width == null
        ? column
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(width: widget.width, child: column),
          );
  }

  /// Un bloque pintado. [progress] `null` deja el relleno plano.
  Widget _block(SozuTheme t, double? progress, {double? width}) {
    final c = t.color;
    final circle = widget.shape == SSkeletonShape.circle;

    return Container(
      // En un renglón de texto el ancho lo fija el padre: la columna ya viene
      // envuelta en un SizedBox con `widget.width`, y ponerlo tambien aqui lo
      // aplicaria dos veces.
      width: widget.shape == SSkeletonShape.text ? null : width,
      height: widget.height,
      decoration: BoxDecoration(
        color: progress == null ? c.skeletonBase : null,
        gradient: progress == null
            ? null
            : LinearGradient(
                colors: [c.skeletonBase, c.skeletonHighlight, c.skeletonBase],
                // La banda brillante ocupa el cuarto central; con stops en
                // 0/0.5/1 el bloque parpadea en las orillas al reciclar.
                stops: const [0.25, 0.5, 0.75],
                transform: _SlideGradient(progress),
              ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(_radius(t)),
      ),
    );
  }

  /// Radio por forma; un renglón de texto usa el radio chico.
  double _radius(SozuTheme t) =>
      widget.radius ??
      switch (widget.shape) {
        SSkeletonShape.text => t.radius.sm,
        SSkeletonShape.box || SSkeletonShape.circle => t.radius.md,
      };
}

/// Desliza el gradiente de izquierda a derecha (t: 0-1), entrando y saliendo
/// por completo del bloque.
@immutable
class _SlideGradient extends GradientTransform {
  final double t;

  const _SlideGradient(this.t);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);

  // Sin `==`, `BoxDecoration ==` caería en identidad y diría "cambió" en cada
  // frame.
  @override
  bool operator ==(Object other) => other is _SlideGradient && other.t == t;

  @override
  int get hashCode => t.hashCode;
}
