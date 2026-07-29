import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Forma del placeholder.
///
/// La forma NO es un detalle estético: un placeholder redondo promete un avatar
/// y uno rectangular promete un bloque de contenido. Si la forma no coincide con
/// lo que llega después, el layout salta al terminar la carga y el usuario ve
/// la interfaz reacomodarse. Por eso la forma es parte de la API y no algo que
/// se improvise con un `ClipOval` en la pantalla.
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
/// **No es `context.s.motion.slow` a propósito**, y la distinción importa: los
/// tokens de movimiento describen *transiciones de estado* (algo pasa de A a B
/// porque el usuario o los datos lo provocaron), y su valor se elige por cuánta
/// superficie se mueve. Un shimmer no transiciona nada: es un loop ambiental que
/// corre mientras no hay noticias del servidor. Mezclarlos tendría una
/// consecuencia concreta y absurda: subir `slow` de 380 a 450 ms para que las
/// hojas modales entren con más peso aceleraría los skeletons a 3 ciclos por
/// segundo.
///
/// 1300 ms es el valor que ya usaba el shimmer del móvil. Es lento a propósito:
/// un barrido rápido se lee como parpadeo nervioso y sugiere que algo va mal,
/// mientras que un barrido largo comunica "esto viene en camino" sin apurar a
/// nadie.
const Duration _shimmerCycle = Duration(milliseconds: 1300);

/// Placeholder de carga global del design system.
///
/// ## Por qué existe
///
/// Había DOS implementaciones del mismo concepto: `Skeleton` (móvil) con un
/// shimmer de gradiente deslizante de 1300 ms, y `PortalSkeletonBox` (web) con
/// un pulso de opacidad de 0.45 a 1 en 1000 ms. En la misma sesión, un usuario
/// que pasa de Inicio a Patrimonio ve dos lenguajes de carga distintos: la app
/// se siente ensamblada de dos productos. Ninguna de las dos respetaba "reducir
/// movimiento" del sistema, y ninguna usaba los roles `skeletonBase` /
/// `skeletonHighlight`, que existían sin consumidor: cada una traía sus hex.
///
/// ## Por qué shimmer y no pulso
///
/// El shimmer gana porque **un pulso de opacidad es ambiguo**. Bajar y subir la
/// opacidad de un bloque gris es exactamente el lenguaje visual de un elemento
/// deshabilitado o de algo que se está desvaneciendo: no dice "espera", dice "no
/// puedes tocar esto". El barrido de luz, en cambio, no significa nada más en
/// una interfaz: es una animación direccional que recorre el bloque, y la
/// dirección implica progreso. Además el shimmer sobrevive mejor a la
/// repetición: al recorrer el bloque de un lado a otro, la mirada tiene algo que
/// seguir y la espera se percibe más corta, mientras que un pulso en el sitio
/// se vuelve un latido molesto a los pocos segundos.
///
/// ## Reducir movimiento
///
/// Cuando el sistema pide reducir movimiento (`context.s.motion` trae
/// `SozuMotion.reduced`), este widget **no anima nada**: pinta el bloque estático
/// con `skeletonBase`. No se ralentiza el shimmer ni se baja su amplitud, se
/// apaga. Honrar la señal a medias sigue siendo movimiento, y quien la activó por
/// vértigo o migraña vestibular no pidió menos movimiento, pidió que no haya. El
/// costo comunicativo es cero en la práctica: una lista de bloques grises en el
/// lugar exacto donde va a aparecer el contenido ya se lee como carga, porque lo
/// que informa es la FORMA del placeholder, no su animación.
///
/// ```dart
/// const SSkeleton(width: 120, height: 100, radius: 12)   // imagen de card
/// const SSkeleton.circle(size: 40)                        // avatar
/// const SSkeleton.text(lines: 3)                          // párrafo
/// ```
class SSkeleton extends StatefulWidget {
  /// Alto de un bloque cuando no se especifica otro.
  ///
  /// 16 px es el alto de un renglón de texto corrido con su aire: es el caso
  /// dominante, así que es el default.
  static const double defaultHeight = 16;

  /// `null` = ocupa el ancho que le dé el padre. Es lo correcto para bloques que
  /// van dentro de una card: el placeholder mide lo que va a medir el contenido.
  final double? width;

  final double height;

  final SSkeletonShape shape;

  /// `null` = radio del token que corresponde a [shape]. Solo se pasa cuando el
  /// contenido que va a llegar tiene un radio propio (la imagen de una card).
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
  ///
  /// Es un constructor y no `shape: circle` + `width` + `height` porque un
  /// círculo con ancho distinto del alto es un óvalo, y un óvalo no es ningún
  /// elemento de esta interfaz. Un solo parámetro hace imposible el error.
  const SSkeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      shape = SSkeletonShape.circle,
      radius = null,
      lines = 1,
      lastLineFactor = 1;

  /// Bloque de [lines] renglones de texto con separación coherente.
  ///
  /// El ÚLTIMO renglón sale más corto (~60%) porque un párrafo real no termina
  /// justo al borde: un bloque de renglones todos del mismo ancho se lee como
  /// una tabla, no como texto cargando.
  ///
  /// Con [width] en `null` los renglones ocupan el ancho del padre, así que el
  /// padre tiene que dar un ancho acotado (una card, un `Expanded`).
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

  // El controlador se crea SIEMPRE, incluso con movimiento reducido, aunque
  // entonces nunca corra. Con `late final` inicializado en la declaración, un
  // skeleton que nunca animó lo construiría por primera vez dentro de
  // `dispose()` (la primera lectura de la variable), y ahí `SingleTickerProvider`
  // ya no puede buscar el `TickerMode` porque el elemento está desactivado: el
  // widget revienta al desmontarse, justo en el caso de accesibilidad.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _shimmerCycle);
  }

  // El controlador arranca en `didChangeDependencies` y no en `initState`
  // porque la decisión depende de los tokens, que son un InheritedWidget:
  // leerlos en `initState` no registra la dependencia y el widget se quedaría
  // pegado al valor inicial si el usuario activa "reducir movimiento" con la app
  // abierta.
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
      // `stop` y además `reset`: si se apaga a mitad del barrido, el bloque
      // quedaría congelado con la banda brillante cruzada, que se ve como un
      // gradiente decorativo y no como un placeholder.
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reducir movimiento se detecta por el token, no por `MediaQuery`: así este
  /// widget respeta también los temas que fuerzan movimiento reducido sin que el
  /// sistema operativo lo pida (previews, golden tests).
  bool _shouldAnimate(BuildContext context) =>
      context.s.motion.instant != Duration.zero;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // No se llama `_sync` aquí: arrancar o detener el ticker es un efecto, y los
    // efectos no van dentro de un `build`. Los cambios de tokens llegan por
    // `didChangeDependencies`, que es exactamente el lugar para eso.
    final animate = _animating;

    if (!animate) return _content(t, null);

    return AnimatedBuilder(
      animation: _controller,
      // Un solo AnimatedBuilder en la raíz y no uno por renglón: así los
      // renglones de un párrafo barren en fase y el bloque se lee como una
      // superficie, no como tres animaciones vecinas.
      builder: (context, _) => _content(t, _controller.value),
    );
  }

  /// [progress] `null` = sin animación (movimiento reducido).
  Widget _content(SozuTheme t, double? progress) {
    if (widget.shape != SSkeletonShape.text) {
      return _block(t, progress, width: widget.width);
    }

    // Separación entre renglones: `xs` (8) sobre bloques de 16 da un ritmo
    // parecido al del texto real. `crossAxisAlignment.stretch` es lo que permite
    // que un renglón sin ancho explícito llene la card.
    final gap = t.space.xs;
    final rows = <Widget>[];
    for (var i = 0; i < widget.lines; i++) {
      // La separación va ANTES de cada renglón salvo el primero, en vez de
      // después de cada uno: así `lines: 1` no arrastra un hueco al final que
      // desalinearía el bloque respecto a lo que viene debajo.
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

    return widget.width == null
        ? column
        : SizedBox(width: widget.width, child: column);
  }

  /// Un bloque pintado. [progress] `null` deja el relleno plano.
  Widget _block(SozuTheme t, double? progress, {double? width}) {
    final c = t.color;
    final circle = widget.shape == SSkeletonShape.circle;

    return Container(
      // En un renglón de texto el ancho lo fija el padre (`stretch` o el
      // `FractionallySizedBox` del último renglón).
      width: widget.shape == SSkeletonShape.text ? null : width,
      height: widget.height,
      decoration: BoxDecoration(
        // Con movimiento reducido el relleno es `skeletonBase` plano: es el
        // extremo oscuro del gradiente, o sea el estado en el que el bloque pasa
        // la mayor parte del ciclo. Usar el highlight dejaría un bloque casi
        // blanco que desaparece contra la superficie de la card.
        color: progress == null ? c.skeletonBase : null,
        gradient: progress == null
            ? null
            : LinearGradient(
                colors: [c.skeletonBase, c.skeletonHighlight, c.skeletonBase],
                // La banda brillante ocupa el cuarto central y se difumina hacia
                // los extremos: con stops en 0/0.5/1 el brillo llega al borde y
                // el bloque parpadea en las orillas al reciclar el ciclo.
                stops: const [0.25, 0.5, 0.75],
                transform: _SlideGradient(progress),
              ),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(_radius(t)),
      ),
    );
  }

  /// Radio por forma. Un renglón de texto usa el radio chico porque a 16 px de
  /// alto el radio de card lo convertiría en una pastilla, y una pastilla ya
  /// significa "chip" en esta interfaz.
  double _radius(SozuTheme t) =>
      widget.radius ??
      switch (widget.shape) {
        SSkeletonShape.text => t.radius.sm,
        SSkeletonShape.box || SSkeletonShape.circle => t.radius.md,
      };
}

/// Desliza el gradiente de izquierda a derecha (t: 0-1).
///
/// El recorrido es de 3 anchos empezando 1.5 anchos fuera del bloque: el brillo
/// entra por completo desde afuera y sale por completo, así que no hay un frame
/// en el que aparezca o desaparezca a media banda.
@immutable
class _SlideGradient extends GradientTransform {
  final double t;

  const _SlideGradient(this.t);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);

  // Sin `==` dos gradientes en el mismo punto del barrido nunca serían iguales
  // (la comparación caería en identidad), así que `BoxDecoration ==` diría
  // "cambió" en cada frame incluso cuando no cambió nada.
  @override
  bool operator ==(Object other) => other is _SlideGradient && other.t == t;

  @override
  int get hashCode => t.hashCode;
}
