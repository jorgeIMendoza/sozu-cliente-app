import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/palette.dart';

/// Variantes de botón, por PESO en la jerarquía de la pantalla.
///
/// El nombre describe el papel que juega el botón, no cómo se ve: una pantalla
/// pide "la acción principal" ([primary]) o "una acción destructiva"
/// ([danger]), y el design system decide el color. Si mañana el secundario deja
/// de tener contorno, cambia aquí y no en 40 pantallas.
enum SButtonVariant {
  /// Acción principal de la pantalla. Como máximo una por vista.
  primary,

  /// Acción alterna del mismo peso semántico (Cancelar, Ver detalle).
  secondary,

  /// Acción terciaria: sin caja hasta que el mouse la toca. Barras de
  /// herramientas, acciones de card.
  ghost,

  /// Acción destructiva o irreversible (eliminar, cerrar sesión).
  danger,

  /// Enlace de texto. NO es un tercer botón: ver [SButton.link].
  link,
}

/// Tamaños de botón.
///
/// Solo alto y padding cambian; el texto NO se escala (ver [_SButtonMetrics]).
enum SButtonSize {
  /// 36 px. **Por debajo del mínimo táctil de 44 px**: usarlo SOLO en barras
  /// densas de escritorio (filtros, toolbars de tabla) donde el destino real es
  /// el mouse. Nunca en un formulario ni en una pantalla que se use en el
  /// teléfono.
  sm,

  /// 44 px. El tamaño por defecto y el mínimo táctil de Apple/Material.
  md,

  /// 52 px. Acción principal de un formulario o de una hoja modal.
  lg,
}

/// Botón global del design system.
///
/// ## Por qué existe
///
/// Los botones vivían en `features/auth/components/auth_buttons.dart`, con el
/// color, el alto y el comportamiento cocidos en el `build` de cada uno. Pagos,
/// perfil y el resto necesitan los mismos estados (hover, foco, press, carga) con
/// otro color, y copiar el widget para cambiarle el fondo es cómo nacen tres
/// botones que se ven parecidos y se comportan distinto.
///
/// ## Cerrado a modificación, abierto a extensión
///
/// Este `build` **no tiene un solo `switch` de variante**. Toda la apariencia se
/// resuelve antes, en [_SButtonStyle.resolve], que devuelve un objeto inmutable
/// con colores, alto, padding y tipografía ya decididos; el `build` solo lo
/// pinta. Agregar una variante nueva (`positive`, `warningOutline`…) es agregar
/// un `case` a ese resolver: el árbol de widgets, el manejo de foco, la
/// animación de press y la semántica no se tocan, así que no hay forma de que la
/// variante nueva rompa el comportamiento de las que ya funcionan.
///
/// ## Interacción
///
/// La capa interactiva es un `InkWell` sobre `Material`, no un
/// `GestureDetector`: el gesture detector no es enfocable, así que el botón era
/// inalcanzable con Tab y no respondía a Enter/Espacio - con teclado, el login
/// solo se podía enviar desde el campo de contraseña. `InkWell` trae el
/// `ActivateIntent` mapeado, y de ahí sale gratis el soporte de teclado.
///
/// El hover **oscurece** en lugar de aclarar (o usa el rol `*Hover`, que en
/// oscuro sí aclara): aclarar sobre un color ya claro no se percibe.
///
/// ```dart
/// SButton(label: 'Entrar', onPressed: _enviar, loading: _cargando)
/// SButton.secondary(label: 'Cancelar', onPressed: _cerrar, fullWidth: false)
/// SButton.link(label: '¿Olvidaste tu contraseña?', onPressed: _recuperar)
/// ```
class SButton extends StatefulWidget {
  /// Texto del botón. Obligatorio incluso con iconos: un botón solo de icono es
  /// otro componente (necesita `tooltip` obligatorio y forma cuadrada).
  final String label;

  /// `null` deshabilita el botón. Es la única forma de deshabilitarlo: no hay
  /// prop `disabled` que pueda quedar desincronizada del callback.
  final VoidCallback? onPressed;

  final SButtonVariant variant;
  final SButtonSize size;

  /// Icono a la izquierda del texto.
  final IconData? icon;

  /// Icono a la derecha del texto (chevron, flecha de "continuar").
  final IconData? trailingIcon;

  /// Muestra spinner y deshabilita el botón. No hace falta poner también
  /// `onPressed: null`: durante la carga el botón ya no dispara.
  final bool loading;

  /// Texto durante la carga ("Entrando…"). Si es `null` se conserva [label],
  /// que es mejor que un texto genérico tipo "Cargando".
  final String? loadingLabel;

  /// Ancho completo. Por defecto `true` porque el caso dominante es el botón de
  /// formulario; en una fila de acciones se pone `false`.
  final bool fullWidth;

  /// Override del color base para casos puntuales (una acción teñida con el
  /// color de un estado). El resolver decide qué significa "base" en cada
  /// variante: el fondo en [SButtonVariant.primary], el borde y el acento en
  /// [SButtonVariant.secondary], el texto en las que no tienen caja.
  ///
  /// Es una fuga controlada del sistema: si un color se necesita dos veces, es
  /// una variante nueva, no un override repetido.
  final Color? color;

  final String? tooltip;

  /// Para que la pantalla controle el orden de tabulación o dispare el foco
  /// (p. ej. enfocar "Reintentar" al aparecer un error).
  final FocusNode? focusNode;

  /// `true` cuando el botón lleva a otra pantalla o abre una URL.
  ///
  /// Cambia SOLO la semántica de accesibilidad (`link` en vez de `button`), no la
  /// apariencia. Los lectores de pantalla exponen una lista de enlaces de la
  /// pantalla y hay usuarios que navegan por ella: un destino de navegación
  /// anunciado como botón no aparece en esa lista.
  ///
  /// Es un eje aparte de [variant] porque no coinciden: "Cerrar sesión" se ve
  /// como enlace pero es una acción, y "¿Olvidaste tu contraseña?" se ve igual y
  /// sí navega.
  final bool isNavigation;

  const SButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SButtonVariant.primary,
    this.size = SButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = true,
    this.color,
    this.tooltip,
    this.focusNode,
    this.isNavigation = false,
  });

  /// Atajo legible de [SButtonVariant.secondary].
  ///
  /// Los constructores nombrados existen para que el sitio de uso se lea
  /// `SButton.secondary(...)` en vez de `SButton(..., variant: ..., ...)` con la
  /// variante enterrada entre los demás parámetros.
  const SButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = true,
    this.color,
    this.tooltip,
    this.focusNode,
    this.isNavigation = false,
  }) : variant = SButtonVariant.secondary;

  /// Atajo legible de [SButtonVariant.ghost].
  const SButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    // Un ghost a ancho completo se lee como una fila vacía: no tiene caja que
    // justifique el ancho.
    this.fullWidth = false,
    this.color,
    this.tooltip,
    this.focusNode,
    this.isNavigation = false,
  }) : variant = SButtonVariant.ghost;

  /// Atajo legible de [SButtonVariant.danger].
  const SButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = true,
    this.color,
    this.tooltip,
    this.focusNode,
    this.isNavigation = false,
  }) : variant = SButtonVariant.danger;

  /// Enlace de texto: sin caja, y el feedback de hover es el **subrayado**.
  ///
  /// Un enlace dentro de un formulario no debe leerse como un tercer botón
  /// compitiendo con la acción principal, así que no pinta fondo en ningún
  /// estado. Nace con `fullWidth: false` por lo mismo.
  const SButton.link({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = SButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.loadingLabel,
    this.fullWidth = false,
    this.color,
    this.tooltip,
    this.focusNode,
    this.isNavigation = false,
  }) : variant = SButtonVariant.link;

  @override
  State<SButton> createState() => _SButtonState();
}

/// Opacidad del botón deshabilitado o en carga.
///
/// 0.5 y no menos: por debajo de ~0.4 el texto de un botón primario deja de
/// cumplir contraste y el botón se lee como decoración, no como control.
const double _disabledOpacity = 0.5;

/// Anillo de foco: 2 px de grosor separados 2 px de la caja.
///
/// Va SEPARADO y por fuera en lugar de engrosar el borde propio del botón: el
/// borde es parte de la variante (el secundario lo usa para su identidad) y
/// pisarlo hacía que el foco se viera distinto en cada variante. Además,
/// dibujarlo por fuera no cambia el tamaño del botón, así que enfocar no mueve
/// el layout.
const double _focusRingWidth = 2.0;
const double _focusRingGap = 2.0;

/// Grosor del subrayado del enlace. 1.5 px: a 1 px se ve roto en pantallas sin
/// densidad extra, a 2 px pesa más que la letra que subraya.
const double _underlineThickness = 1.5;

class _SButtonState extends State<SButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _isDisabled => widget.onPressed == null || widget.loading;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final m = t.motion;
    final style = _SButtonStyle.resolve(
      variant: widget.variant,
      size: widget.size,
      colors: t.color,
      theme: t,
      colorOverride: widget.color,
    );

    final disabled = _isDisabled;

    // hover del mouse y foco de teclado pintan igual: los dos significan "este
    // es el control apuntado". Distinguirlos obliga al usuario de teclado a
    // aprender un lenguaje visual aparte.
    final highlighted = (_hovered || _focused) && !disabled;
    final showRing = _focused && !disabled;

    final foreground = highlighted
        ? style.foregroundHighlight
        : style.foreground;
    final visibleLabel = widget.loading
        ? (widget.loadingLabel ?? widget.label)
        : widget.label;

    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          _Spinner(size: style.iconSize, color: foreground, gap: style.gap)
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: style.iconSize, color: foreground),
          SizedBox(width: style.gap),
        ],
        Flexible(
          child: Text(
            visibleLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style.textStyle.copyWith(
              color: foreground,
              decoration: highlighted && style.underlineOnHover
                  ? TextDecoration.underline
                  : null,
              decorationColor: foreground,
              decorationThickness: _underlineThickness,
            ),
          ),
        ),
        if (widget.trailingIcon != null && !widget.loading) ...[
          SizedBox(width: style.gap),
          Icon(widget.trailingIcon, size: style.iconSize, color: foreground),
        ],
      ],
    );

    final box = AnimatedContainer(
      // El hover TRANSICIONA en vez de saltar: un cambio de color instantáneo se
      // percibe como un parpadeo, no como respuesta al puntero.
      duration: m.instant,
      curve: m.standard,
      decoration: BoxDecoration(
        color: highlighted ? style.backgroundHighlight : style.background,
        borderRadius: style.radius,
        border: highlighted
            ? (style.borderHighlight ?? style.border)
            : style.border,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: style.radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : widget.onPressed,
          focusNode: widget.focusNode,
          borderRadius: style.radius,
          // El hover y el foco los pinta el AnimatedContainer de arriba, que sí
          // los anima; los overlays del InkWell aparecerían de golpe encima y se
          // sumarían al color ya resuelto.
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: style.pressOverlay,
          splashColor: style.splash,
          onHover: (v) => setState(() => _hovered = v),
          onFocusChange: (v) => setState(() => _focused = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          // El contenido no aporta semántica: la etiqueta la declara el
          // Semantics de afuera. Si no se excluye, el lector de pantalla
          // anuncia el texto dos veces ("Entrar, botón Entrar") al fusionarse
          // con el nodo del botón.
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: style.height),
              child: Padding(padding: style.padding, child: content),
            ),
          ),
        ),
      ),
    );

    // MergeSemantics envuelve al Semantics y no al revés: así la etiqueta, el
    // estado y la acción de tap del InkWell caen en UN solo nodo. Anidados al
    // revés quedan dos nodos hermanos - uno que dice "botón Entrar" y otro que
    // es el que en realidad se puede activar - y el lector de pantalla los
    // anuncia como dos controles.
    return MergeSemantics(
      child: Semantics(
        // Un destino de navegación se anuncia como ENLACE, no como botón. La
        // distinción no es cosmética: los lectores de pantalla listan los
        // enlaces de una pantalla aparte, y hay usuarios que navegan
        // exclusivamente por esa lista. Un "Volver al inicio de sesión"
        // anunciado como botón desaparece de ahí.
        //
        // Va como parámetro y no atado a `variant: link` porque son ejes
        // distintos: la variante decide cómo SE VE, esto decide qué HACE. "Cerrar
        // sesión" se ve como enlace y es una acción; "¿Olvidaste tu contraseña?"
        // se ve igual y sí navega.
        button: !widget.isNavigation,
        link: widget.isNavigation,
        enabled: !disabled,
        label: visibleLabel,
        child: _maybeTooltip(
          child: AnimatedOpacity(
            duration: m.fast,
            curve: m.standard,
            opacity: disabled ? _disabledOpacity : 1,
            child: AnimatedScale(
              // El hundido al presionar es lo que hace que el botón se sienta
              // físico en vez de plano. Es la diferencia más barata entre "una
              // caja que cambia de color" y un control nativo.
              scale: _pressed && !disabled ? m.pressScale : 1,
              duration: m.fast,
              curve: m.emphasized,
              // El anillo se PINTA por fuera de la caja en vez de ocupar espacio:
              // un `Stack` con el anillo posicionado se estira al ancho que le dé
              // el padre (`constraints.constrain`), así que un botón
              // `fullWidth: false` dentro de una columna de ancho fijo reportaba
              // el tamaño del hueco y no el suyo - y el área sensible al mouse
              // quedaba corrida respecto a su centro. Un `CustomPaint` mide
              // exactamente lo que mide su hijo.
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: showRing ? 1 : 0),
                duration: m.fast,
                curve: m.standard,
                builder: (context, progress, child) => CustomPaint(
                  painter: _FocusRingPainter(
                    color: style.focusRing,
                    radius: style.radius,
                    progress: progress,
                  ),
                  child: child,
                ),
                child: box,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeTooltip({required Widget child}) {
    final tooltip = widget.tooltip;
    if (tooltip == null) return child;
    return Tooltip(message: tooltip, child: child);
  }
}

/// Anillo de foco dibujado por fuera del botón, sin ocupar espacio.
///
/// Es un pintor y no un widget con borde porque el anillo no debe influir en el
/// layout: aparecer y desaparecer no puede mover nada de lugar. El canvas de un
/// `CustomPaint` no está recortado, así que pintar en negativo funciona.
class _FocusRingPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;

  /// 0 = sin anillo, 1 = anillo completo. Animarlo por opacidad (y no por
  /// grosor) evita que el trazo se vea borroso a mitad de la transición.
  final double progress;

  const _FocusRingPainter({
    required this.color,
    required this.radius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // El trazo se centra en su propio grosor: sin el medio grosor, la mitad del
    // anillo cae encima del borde del botón y se ve más delgado de lo pedido.
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
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress || old.color != color || old.radius != radius;
}

/// Spinner de carga con su separación ya incluida.
///
/// Ocupa el lugar del icono izquierdo (no reemplaza al texto) para que el ancho
/// del botón no salte al empezar la carga y la fila de acciones no se recorra.
class _Spinner extends StatelessWidget {
  final double size;
  final Color color;
  final double gap;

  const _Spinner({required this.size, required this.color, required this.gap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: gap),
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(color: color, strokeWidth: 2.2),
      ),
    );
  }
}

/// Apariencia ya resuelta de un botón: **el único lugar del archivo que sabe de
/// variantes**.
///
/// Es lo que permite que [SButton.build] no tenga condicionales de variante.
/// Todo lo que cambia entre un primario y un enlace vive en campos de este
/// objeto, así que una variante nueva no puede olvidarse de un estado: si no
/// llena un campo, no compila.
@immutable
class _SButtonStyle {
  /// Fondo en reposo.
  final Color background;

  /// Fondo con el puntero encima o con foco de teclado.
  final Color backgroundHighlight;

  /// Color de texto e iconos en reposo.
  final Color foreground;

  /// Color de texto e iconos resaltado. En el secundario el contenido se tiñe de
  /// marca junto con el borde; en el resto es igual a [foreground].
  final Color foregroundHighlight;

  final Border? border;

  /// `null` = conserva [border] al resaltar.
  final Border? borderHighlight;

  final double height;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final BorderRadius radius;

  /// Tamaño de icono y del spinner.
  final double iconSize;

  /// Separación entre icono y texto.
  final double gap;

  /// Velo de press del InkWell (aparece bajo el dedo y se queda mientras
  /// presiona).
  final Color pressOverlay;

  /// Onda del ripple.
  final Color splash;

  /// Color del anillo de foco.
  final Color focusRing;

  /// El enlace se subraya al resaltar en lugar de pintar fondo.
  final bool underlineOnHover;

  const _SButtonStyle({
    required this.background,
    required this.backgroundHighlight,
    required this.foreground,
    required this.foregroundHighlight,
    required this.border,
    required this.borderHighlight,
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.radius,
    required this.iconSize,
    required this.gap,
    required this.pressOverlay,
    required this.splash,
    required this.focusRing,
    required this.underlineOnHover,
  });

  /// Traduce (variante × tamaño × roles de color) a apariencia concreta.
  ///
  /// [colors] llega aparte de [theme] aunque el tema ya los contenga: así una
  /// prueba o un preview puede resolver el estilo contra un set de roles fijo
  /// ([SozuColorRoles.light]) sin construir un `BuildContext`.
  factory _SButtonStyle.resolve({
    required SButtonVariant variant,
    required SButtonSize size,
    required SozuColorRoles colors,
    required SozuTheme theme,
    Color? colorOverride,
  }) {
    final m = _SButtonMetrics.forSize(size, theme);
    final c = colors;

    // Radio md (8) y no lg (16): es el que ya usa el acceso en producción, la
    // pantalla que fija el estándar visual. lg es el radio de los inputs.
    final radius = theme.radius.mdBorder;

    switch (variant) {
      case SButtonVariant.primary:
        final base = colorOverride ?? c.primary;
        return _SButtonStyle(
          background: base,
          // Sin override se usa el rol: en claro oscurece y en oscuro ACLARA,
          // porque sobre un fondo oscuro un verde más oscuro se pierde. Con
          // override no hay rol que consultar y solo queda oscurecer.
          backgroundHighlight: colorOverride == null
              ? c.primaryHover
              : _darken(base),
          foreground: c.onPrimary,
          foregroundHighlight: c.onPrimary,
          border: null,
          borderHighlight: null,
          height: m.height,
          padding: m.padding,
          textStyle: m.textStyle,
          radius: radius,
          iconSize: m.iconSize,
          gap: m.gap,
          pressOverlay: SozuAlpha.black12,
          splash: c.onPrimary.withValues(alpha: 0.14),
          focusRing: c.primaryBorder,
          underlineOnHover: false,
        );

      case SButtonVariant.secondary:
        final accent = colorOverride ?? c.primary;
        return _SButtonStyle(
          background: Colors.transparent,
          backgroundHighlight: c.primarySoft,
          foreground: colorOverride ?? c.fg,
          foregroundHighlight: accent,
          // 1.5 px y no 2: junto a un primario plano, un contorno grueso pesa
          // más que el botón que sí es la acción principal.
          border: Border.all(color: colorOverride ?? c.border, width: 1.5),
          borderHighlight: Border.all(color: accent, width: 1.5),
          height: m.height,
          padding: m.padding,
          textStyle: m.textStyle,
          radius: radius,
          iconSize: m.iconSize,
          gap: m.gap,
          pressOverlay: c.primarySoftStrong,
          splash: c.primarySoftStrong,
          focusRing: c.primaryBorder,
          underlineOnHover: false,
        );

      case SButtonVariant.ghost:
        final fg = colorOverride ?? c.fg;
        return _SButtonStyle(
          background: Colors.transparent,
          backgroundHighlight: c.surfaceAlt,
          foreground: fg,
          foregroundHighlight: fg,
          border: null,
          borderHighlight: null,
          height: m.height,
          padding: m.padding,
          textStyle: m.textStyle,
          radius: radius,
          iconSize: m.iconSize,
          gap: m.gap,
          pressOverlay: c.muted,
          splash: c.primarySoftStrong,
          focusRing: c.primaryBorder,
          underlineOnHover: false,
        );

      case SButtonVariant.danger:
        final base = colorOverride ?? c.danger;
        return _SButtonStyle(
          background: base,
          // No existe un rol `dangerHover`, así que aquí sí se oscurece a mano.
          // El día que se agregue el rol, se cambia esta línea y nada más.
          backgroundHighlight: _darken(base),
          foreground: c.onPrimary,
          foregroundHighlight: c.onPrimary,
          border: null,
          borderHighlight: null,
          height: m.height,
          padding: m.padding,
          textStyle: m.textStyle,
          radius: radius,
          iconSize: m.iconSize,
          gap: m.gap,
          pressOverlay: SozuAlpha.black12,
          splash: c.onPrimary.withValues(alpha: 0.14),
          // Un anillo verde alrededor de un botón de borrar manda la señal
          // equivocada: el foco se tiñe del propio color destructivo.
          focusRing: base.withValues(alpha: 0.35),
          underlineOnHover: false,
        );

      case SButtonVariant.link:
        // primaryHover (verde oscuro) y no primary: sobre superficie clara el
        // primario no alcanza contraste AA para texto chico.
        final fg = colorOverride ?? c.primaryHover;
        return _SButtonStyle(
          // Transparente en TODOS los estados: el enlace no debe leerse como un
          // tercer botón. Su feedback es el subrayado.
          background: Colors.transparent,
          backgroundHighlight: Colors.transparent,
          foreground: fg,
          foregroundHighlight: fg,
          border: null,
          borderHighlight: null,
          height: m.height,
          padding: m.linkPadding,
          // Usa la escala de TEXTO CORRIDO, no la de botón: el enlace vive
          // dentro de un párrafo o debajo de un campo y debe pesar como ellos.
          textStyle: theme.text.body.copyWith(fontWeight: FontWeight.w600),
          radius: theme.radius.smBorder,
          iconSize: m.linkIconSize,
          gap: m.gap,
          // Sin velo ni ripple: una onda de material sobre texto suelto vuelve a
          // dibujar la caja que esta variante existe para no tener.
          pressOverlay: Colors.transparent,
          splash: Colors.transparent,
          focusRing: c.primaryBorder,
          underlineOnHover: true,
        );
    }
  }
}

/// Medidas por tamaño.
///
/// El TEXTO no cambia con el tamaño: el único token más chico que `button`
/// (15 px Poppins) es `label` (14 px Inter), y cambiar de familia haría que un
/// botón `sm` se leyera como otro componente. Lo que distingue los tamaños es el
/// aire, no la letra.
@immutable
class _SButtonMetrics {
  final double height;
  final double iconSize;
  final EdgeInsets padding;

  /// El enlace necesita padding vertical propio: no tiene caja que le dé alto,
  /// pero sí tiene que llegar al mínimo táctil.
  final EdgeInsets linkPadding;

  final double linkIconSize;
  final TextStyle textStyle;
  final double gap;

  const _SButtonMetrics({
    required this.height,
    required this.iconSize,
    required this.padding,
    required this.linkPadding,
    required this.linkIconSize,
    required this.textStyle,
    required this.gap,
  });

  factory _SButtonMetrics.forSize(SButtonSize size, SozuTheme t) {
    // El padding vertical es 0 a propósito: el alto lo fija `height` como
    // minHeight y el contenido se centra solo. Sumar padding vertical haría que
    // un texto de dos líneas creciera por encima del alto declarado.
    EdgeInsets h(double value) => EdgeInsets.symmetric(horizontal: value);
    final linkPadding = EdgeInsets.symmetric(
      horizontal: t.space.xxs,
      vertical: t.space.xs,
    );

    switch (size) {
      case SButtonSize.sm:
        return _SButtonMetrics(
          height: 36,
          iconSize: 16,
          padding: h(t.space.sm),
          linkPadding: linkPadding,
          linkIconSize: 14,
          textStyle: t.text.button,
          gap: t.space.xs,
        );
      case SButtonSize.md:
        return _SButtonMetrics(
          height: 44,
          iconSize: 18,
          padding: h(t.space.md),
          linkPadding: linkPadding,
          linkIconSize: 15,
          textStyle: t.text.button,
          gap: t.space.xs,
        );
      case SButtonSize.lg:
        return _SButtonMetrics(
          height: 52,
          iconSize: 20,
          padding: h(t.space.lg),
          linkPadding: linkPadding,
          linkIconSize: 16,
          textStyle: t.text.button,
          gap: t.space.xs,
        );
    }
  }
}

/// Oscurece un color mezclándole negro al 10% encima.
///
/// Se usa cuando NO hay un rol `*Hover` disponible. Con rol se prefiere el rol,
/// porque el rol sabe que en tema oscuro el hover tiene que aclarar.
Color _darken(Color base) => Color.alphaBlend(SozuAlpha.black10, base);
