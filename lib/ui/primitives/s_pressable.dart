import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Firma del constructor puente [SPressable.detector].
typedef SPressStateBuilder =
    Widget Function(BuildContext context, bool hovered, bool pressed);

/// Superficie interactiva GLOBAL: hover, press y foco de teclado sobre
/// cualquier hijo.
///
/// ## Por qué existe
///
/// La app "se siente como un sistema viejo" y una de las causas concretas es
/// medible: casi nada responde al puntero. Una fila de lista que no cambia al
/// pasar el mouse no comunica que se puede tocar, y lo poco que sí responde
/// cambia de color de golpe, que se percibe como un parpadeo del render y no
/// como respuesta al gesto. La diferencia entre una interfaz de 2010 y una de
/// hoy no está en los colores: está en que **todo lo que se puede tocar
/// reacciona antes de tocarlo**.
///
/// Eso no se puede resolver pantalla por pantalla. Hoy hay dos builders del
/// portal ([PortalHoverBuilder], [PortalPressable]) y cinco lugares que repiten
/// a mano `onHover: (h) => setState(() => _hover = h)`, cada uno con su propia
/// duración y su propio criterio de qué cambia al pasar el mouse. Mientras el
/// feedback sea algo que cada widget implementa, va a haber widgets que se
/// olviden de implementarlo.
///
/// ## Qué resuelve y qué NO
///
/// [SPressable] es la capa de *interacción*, no de *apariencia*: no dibuja
/// bordes, no pone padding y no decide el color de la superficie en reposo. Solo
/// añade los estados. Por eso envuelve a cualquier hijo en lugar de tener
/// variantes: quien la usa ya sabe cómo se ve su fila o su card.
///
/// La única excepción es el fondo de hover, que sí pinta, porque es la señal
/// mínima que el 90% de los sitios necesitan. Ojo: **se pinta DETRÁS del hijo**.
/// Si el hijo pinta su propia superficie opaca, tapa el hover; en ese caso el
/// hijo debe quedarse transparente y dejar el fondo a esta primitiva (o pasar el
/// color por [hoverColor] y no pintar nada).
///
/// ## Interacción
///
/// La capa de gesto es un `InkWell` sobre `Material` y no un `GestureDetector`,
/// por lo mismo que en [SButton]: el gesture detector no es enfocable, así que
/// con teclado la fila es inalcanzable con Tab y no responde a Enter ni a
/// Espacio. `InkWell` ya trae mapeado el `ActivateIntent`, y de ahí sale gratis
/// el soporte de teclado y el `hasFocusAction` de accesibilidad.
///
/// ## Reducir movimiento
///
/// No hay ninguna rama `if (reduceMotion)` en este archivo, y es a propósito.
/// Con `SozuMotion.reduced` las duraciones son `Duration.zero` y `pressScale`
/// vuelve a `1.0`, así que el mismo código deja de animar por sí solo: el
/// `AnimatedContainer` salta al color final y la escala del press es 1 en los
/// dos estados. La consecuencia importante es que **el cambio de color de hover
/// sobrevive**: es información (dice "esto se puede tocar"), no decoración. Lo
/// que se apaga es la interpolación y el hundido, que es lo que marea.
///
/// ```dart
/// SPressable(
///   onTap: () => abrirDetalle(id),
///   borderRadius: context.s.radius.cardBorder,
///   hoverLift: true,
///   semanticLabel: 'Departamento 402',
///   child: _contenidoDeLaCard(),
/// )
/// ```
class SPressable extends StatefulWidget {
  /// Contenido de la superficie. Se pinta tal cual: esta primitiva no le agrega
  /// padding ni borde.
  final Widget child;

  /// `null` deshabilita la superficie por completo: sin hover, sin cursor de
  /// mano y sin foco. Es la única forma de deshabilitarla, para que no exista un
  /// flag `disabled` capaz de desincronizarse del callback.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// Radio del fondo de hover, del recorte del ripple y del anillo de foco. Si
  /// es `null` usa `radius.mdBorder`, el radio de fila/control del sistema.
  ///
  /// Debe coincidir con el radio que dibuje el hijo: si el hijo redondea 16 y
  /// aquí quedan 8, el fondo de hover asoma por las esquinas.
  final BorderRadius? borderRadius;

  /// Fondo con el puntero encima o con foco de teclado. Si es `null` usa
  /// `color.surfaceAlt`, que es un paso de gris sobre la superficie: se nota sin
  /// leerse como selección.
  final Color? hoverColor;

  /// Hundido al presionar (`motion.pressScale`).
  ///
  /// Es lo que hace que el control se sienta físico en vez de plano, y es la
  /// diferencia más barata entre "una caja que cambia de color" y algo nativo.
  /// Se apaga en superficies que ya se mueven por otro motivo (una fila dentro
  /// de un carrusel que arrastra).
  final bool pressScale;

  /// La sombra sube de `shadow.sm` a `shadow.md` en hover.
  ///
  /// SOLO para cards. En una fila de lista una sombra que aparece se lee como si
  /// la fila se despegara del listado, y además desalinea visualmente su borde
  /// respecto a las filas de arriba y abajo. En una card, en cambio, es la señal
  /// de que el objeto entero es un destino.
  ///
  /// En tema oscuro `shadow.sm` está vacío a propósito (negro sobre negro no se
  /// ve), así que ahí el efecto es aparecer la sombra media, no engordarla.
  final bool hoverLift;

  final String? tooltip;

  /// Etiqueta para el lector de pantalla.
  ///
  /// Si es `null` **no se agrega ningún nodo de semántica** y la aportan los
  /// hijos. Esto es deliberado: un `Semantics(label: '')` envolviendo la fila
  /// crea un nodo sin texto que, al fusionarse, tapa el contenido y el lector
  /// anuncia un control anónimo en lugar de "Departamento 402, 3 recámaras".
  ///
  /// Se pasa una etiqueta cuando el contenido visual no se lee bien en voz alta
  /// (una fila de cifras, un icono suelto); en ese caso los hijos se excluyen
  /// para no anunciar todo dos veces.
  final String? semanticLabel;

  /// `true` cuando la superficie lleva a otra pantalla o abre una URL.
  ///
  /// Cambia SOLO la semántica (`link` en vez de `button`), no la apariencia. Los
  /// lectores de pantalla exponen la lista de enlaces de la pantalla y hay
  /// usuarios que navegan por ella: un destino de navegación anunciado como
  /// botón desaparece de esa lista. Solo aplica si hay [semanticLabel].
  final bool isNavigation;

  /// Para que la pantalla controle el orden de tabulación o dispare el foco.
  final FocusNode? focusNode;

  /// Modo puente: ver [SPressable.detector]. `null` en el uso normal.
  final SPressStateBuilder? stateBuilder;

  const SPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverColor,
    this.pressScale = true,
    this.hoverLift = false,
    this.tooltip,
    this.semanticLabel,
    this.isNavigation = false,
    this.focusNode,
  }) : stateBuilder = null;

  /// Detecta hover y press y se los pasa al hijo, SIN agregar capa de gesto.
  ///
  /// Existe para que los builders legacy del portal ([PortalPressable]) tengan
  /// un solo dueño de la detección en lugar de su propio `MouseRegion` cada uno,
  /// y para el caso suelto de [SHoverBuilder] (un hover sin superficie
  /// presionable alrededor).
  ///
  /// **No usar en código nuevo.** Sin capa de gesto no hay foco de teclado ni
  /// semántica: el hijo tiene que traer su propio `GestureDetector`, que es
  /// justamente el patrón que dejaba las filas del portal inalcanzables con Tab.
  /// El constructor normal ya expone el hover a los hijos vía [SHoverBuilder].
  const SPressable.detector({super.key, required SPressStateBuilder builder})
    : stateBuilder = builder,
      // El hijo real lo produce el builder; este nunca se pinta.
      child = const SizedBox.shrink(),
      onTap = null,
      onLongPress = null,
      borderRadius = null,
      hoverColor = null,
      pressScale = false,
      hoverLift = false,
      tooltip = null,
      semanticLabel = null,
      isNavigation = false,
      focusNode = null;

  @override
  State<SPressable> createState() => _SPressableState();
}

/// Anillo de foco: 2 px de grosor separados 2 px de la caja.
///
/// Mismos valores que [SButton] para que enfocar se vea igual en toda la app.
/// Va por fuera y sin ocupar espacio, así que aparecer no mueve el layout ni
/// pisa el borde propio del hijo.
const double _focusRingWidth = 2.0;
const double _focusRingGap = 2.0;

class _SPressableState extends State<SPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _disabled => widget.onTap == null;

  @override
  Widget build(BuildContext context) {
    final builder = widget.stateBuilder;
    if (builder != null) return _buildDetector(builder);

    final t = context.s;
    final m = t.motion;
    final c = t.color;
    final radius = widget.borderRadius ?? t.radius.mdBorder;
    final disabled = _disabled;

    // hover del mouse y foco de teclado pintan igual: los dos significan "este
    // es el elemento apuntado". Distinguirlos obligaría a quien navega con
    // teclado a aprender un lenguaje visual aparte.
    final highlighted = (_hovered || _focused) && !disabled;
    final showRing = _focused && !disabled;

    // El hijo solo se excluye de la semántica cuando hay etiqueta propia que lo
    // sustituya. Sin etiqueta, excluirlo dejaría la superficie muda.
    final content = widget.semanticLabel == null
        ? widget.child
        : ExcludeSemantics(child: widget.child);

    final box = AnimatedContainer(
      // El hover TRANSICIONA en vez de saltar. Un cambio instantáneo de color se
      // percibe como parpadeo del render, y es exactamente lo que se lee como
      // "sistema viejo". Con movimiento reducido `instant` es cero y esto salta,
      // que es lo pedido: se pierde la transición, no la información.
      duration: m.instant,
      curve: m.standard,
      decoration: BoxDecoration(
        color: highlighted
            ? (widget.hoverColor ?? c.surfaceAlt)
            : Colors.transparent,
        borderRadius: radius,
        // `null` y no `[]` cuando no hay lift: así una card que ya trae su propia
        // sombra en el hijo no recibe una lista vacía que la pise.
        boxShadow: widget.hoverLift
            ? (highlighted ? t.shadow.md : t.shadow.sm)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          focusNode: widget.focusNode,
          borderRadius: radius,
          // Explícito aunque sea el default del InkWell: la mano es parte del
          // contrato de esta primitiva, y `clickable` ya vuelve al cursor normal
          // cuando `onTap` es null.
          mouseCursor: WidgetStateMouseCursor.clickable,
          // El hover y el foco los pinta el AnimatedContainer de arriba, que sí
          // los anima. Los overlays del InkWell aparecerían de golpe encima y se
          // sumarían al color ya resuelto.
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          // El velo de press sí se deja: en pantalla táctil no hay hover, y con
          // movimiento reducido tampoco hay hundido, así que sin esto un toque
          // no confirmaría nada.
          highlightColor: c.muted,
          splashColor: c.primarySoftStrong,
          onHover: (v) => setState(() => _hovered = v),
          onFocusChange: (v) => setState(() => _focused = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          // Los hijos que quieran pintarse distinto en hover leen de aquí
          // (SHoverBuilder) en lugar de montar su propio MouseRegion, que
          // además se dispararía por separado al pasar entre subwidgets.
          child: _SPressableScope(
            hovered: highlighted,
            pressed: _pressed && !disabled,
            child: content,
          ),
        ),
      ),
    );

    final interactive = AnimatedScale(
      // Con `SozuMotion.reduced` este factor es 1.0, así que el hundido
      // desaparece sin necesidad de preguntar por la preferencia aquí.
      scale: _pressed && widget.pressScale && !disabled ? m.pressScale : 1,
      duration: m.fast,
      curve: m.emphasized,
      // El anillo se PINTA por fuera en vez de ocupar espacio: un borde real
      // cambiaría el tamaño al enfocar y movería la fila siguiente.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: showRing ? 1 : 0),
        duration: m.fast,
        curve: m.standard,
        builder: (context, progress, child) => CustomPaint(
          painter: _RingPainter(
            color: c.primaryBorder,
            radius: radius,
            progress: progress,
          ),
          child: child,
        ),
        child: box,
      ),
    );

    final tooltip = widget.tooltip;
    final withTooltip = tooltip == null
        ? interactive
        : Tooltip(message: tooltip, child: interactive);

    final label = widget.semanticLabel;
    if (label == null) {
      // Sin etiqueta NO se envuelve en Semantics. Un nodo con label vacío se
      // fusiona con los hijos y el lector de pantalla anuncia un control sin
      // nombre en lugar del contenido de la fila.
      return withTooltip;
    }

    // MergeSemantics envuelve al Semantics y no al revés: así etiqueta, estado y
    // acción de tap caen en UN solo nodo. Anidados al revés quedan dos nodos
    // hermanos y el lector los anuncia como dos controles.
    return MergeSemantics(
      child: Semantics(
        button: !widget.isNavigation,
        link: widget.isNavigation,
        enabled: !disabled,
        label: label,
        child: withTooltip,
      ),
    );
  }

  /// Modo puente de [SPressable.detector]: solo detección.
  ///
  /// `MouseRegion` + `Listener` y no `InkWell` porque aquí no hay capa de gesto
  /// propia: el gesto lo trae el hijo, así que no existe nadie que reporte
  /// `onHighlightChanged`. Es la implementación literal que tenían los builders
  /// del portal, ahora en un solo lugar.
  Widget _buildDetector(SPressStateBuilder builder) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      // El press se cancela al salir: si el puntero se va con el botón
      // apretado nadie va a mandar el `up`, y el hijo se quedaría hundido.
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: builder(context, _hovered, _pressed),
      ),
    );
  }
}

/// Expone el hover al hijo cuando el hijo necesita SABER que está apuntado para
/// pintarse distinto: teñir un icono, revelar un chevron, subrayar un título.
///
/// Dentro de un [SPressable] lee el estado de esa superficie, así que el hijo se
/// enciende cuando el puntero está en cualquier parte de la fila y no solo
/// encima del icono. Suelto (sin [SPressable] arriba) detecta su propio hover,
/// que es el caso de un elemento que reacciona al puntero pero no se toca.
///
/// ```dart
/// SPressable(
///   onTap: abrir,
///   child: SHoverBuilder(
///     builder: (context, hovered) => Icon(
///       Icons.chevron_right,
///       color: hovered ? context.s.color.fg : context.s.color.fgSubtle,
///     ),
///   ),
/// )
/// ```
class SHoverBuilder extends StatelessWidget {
  const SHoverBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool isHovered) builder;

  @override
  Widget build(BuildContext context) {
    final scope = _SPressableScope.maybeOf(context);
    // Si hay una superficie arriba se reusa SU estado: montar otro MouseRegion
    // dentro daría dos fuentes de verdad que se desincronizan al mover el
    // puntero entre subwidgets (entra al icono = sale de la fila).
    if (scope != null) return builder(context, scope.hovered);
    return SPressable.detector(
      builder: (context, hovered, _) => builder(context, hovered),
    );
  }
}

/// Estado de interacción de la superficie, visible para todo su subárbol.
class _SPressableScope extends InheritedWidget {
  final bool hovered;
  final bool pressed;

  const _SPressableScope({
    required this.hovered,
    required this.pressed,
    required super.child,
  });

  static _SPressableScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SPressableScope>();

  @override
  bool updateShouldNotify(_SPressableScope old) =>
      old.hovered != hovered || old.pressed != pressed;
}

/// Anillo de foco dibujado por fuera de la superficie, sin ocupar espacio.
///
/// Duplica al pintor de [SButton] a propósito: compartirlo obligaría a exportar
/// un detalle interno del botón, y son 30 líneas contra un acoplamiento entre
/// dos primitivas que deben poder evolucionar por separado. Si aparece un
/// tercero, ahí sí se extrae a `ui/tokens/` o a un `ui/internal/`.
class _RingPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;

  /// 0 = sin anillo, 1 = anillo completo. Se anima por opacidad y no por grosor
  /// para que el trazo no se vea borroso a mitad de la transición.
  final double progress;

  const _RingPainter({
    required this.color,
    required this.radius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // El trazo se centra en su propio grosor: sin el medio grosor, la mitad del
    // anillo cae encima del borde del hijo y se ve más delgado de lo pedido.
    final outset = _focusRingGap + _focusRingWidth / 2;
    final rect = Rect.fromLTWH(
      -outset,
      -outset,
      size.width + outset * 2,
      size.height + outset * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _focusRingWidth
      ..color = color.withValues(alpha: color.a * progress.clamp(0, 1));

    canvas.drawRRect(
      radius.add(BorderRadius.circular(outset)).resolve(null).toRRect(rect),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.radius != radius;
}
