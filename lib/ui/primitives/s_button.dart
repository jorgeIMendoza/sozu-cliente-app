import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
import 'package:sozu_cliente_app/ui/tokens/palette.dart';

/// Variantes de botón, por PESO en la jerarquía de la pantalla.
///
/// El nombre describe el papel que juega el botón, no cómo se ve.
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

/// Tamaños de botón. Solo cambian alto y padding; el texto NO se escala.
enum SButtonSize {
  /// 36 px. **Por debajo del mínimo táctil de 44 px**: solo en barras densas de
  /// escritorio. Nunca en un formulario ni en una pantalla de teléfono.
  sm,

  /// 44 px. El tamaño por defecto y el mínimo táctil de Apple/Material.
  md,

  /// 56 px. Acción principal de un formulario o de una hoja modal. Empareja
  /// con [STextFieldSize.lg] a proposito: van uno sobre otro.
  lg,
}

/// Botón global del design system.
///
/// Toda la apariencia se resuelve en [_SButtonStyle.resolve]; agregar una
/// variante es agregar un `case` ahí, sin tocar el árbol de widgets ni el manejo
/// de foco, press y semántica.
///
/// La capa interactiva es un `InkWell` sobre `Material`, NO un
/// `GestureDetector`: sin capa de gesto enfocable no hay foco de teclado ni
/// Enter/Espacio.
///
/// ```dart
/// SButton(label: 'Entrar', onPressed: _enviar, loading: _cargando)
/// SButton.secondary(label: 'Cancelar', onPressed: _cerrar, fullWidth: false)
/// SButton.link(label: '¿Olvidaste tu contraseña?', onPressed: _recuperar)
/// ```
class SButton extends StatefulWidget {
  /// Texto del botón. Obligatorio: un botón solo de icono es otro componente.
  final String label;

  /// `null` deshabilita el botón. No hay prop `disabled`.
  final VoidCallback? onPressed;

  final SButtonVariant variant;
  final SButtonSize size;

  /// Icono a la izquierda del texto.
  final IconData? icon;

  /// Icono a la derecha del texto (chevron, flecha de "continuar").
  final IconData? trailingIcon;

  /// Muestra spinner y deshabilita el botón; no hace falta `onPressed: null`.
  final bool loading;

  /// Texto durante la carga ("Entrando…"). `null` conserva [label].
  final String? loadingLabel;

  /// Ancho completo. `true` por defecto (caso dominante: botón de formulario).
  final bool fullWidth;

  /// Override del color base para casos puntuales. Qué es "base" depende de la
  /// variante: el fondo en [SButtonVariant.primary], el borde y el acento en
  /// [SButtonVariant.secondary], el texto en las que no tienen caja.
  final Color? color;

  final String? tooltip;

  /// Para que la pantalla controle el orden de tabulación o dispare el foco.
  final FocusNode? focusNode;

  /// `true` cuando el botón lleva a otra pantalla o abre una URL.
  ///
  /// Cambia SOLO la semántica de accesibilidad (`link` en vez de `button`), no
  /// la apariencia: los lectores de pantalla listan los enlaces aparte y un
  /// destino anunciado como botón no aparece ahí. Eje independiente de
  /// [variant].
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

  /// Enlace de texto: sin caja en ningún estado, y el hover **subraya**.
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

/// Opacidad del botón deshabilitado o en carga. No bajar de 0.4 (contraste).
const double _disabledOpacity = 0.5;

/// Anillo de foco: 2 px de grosor separados 2 px de la caja, por fuera del
/// borde propio de la variante para no alterar el tamaño del botón.
const double _focusRingWidth = 2.0;
const double _focusRingGap = 2.0;

/// Grosor del subrayado del enlace.
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

    // hover del mouse y foco de teclado pintan igual.
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
          // El hover y el foco los pinta el AnimatedContainer de arriba; los
          // overlays del InkWell se sumarían al color ya resuelto.
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: style.pressOverlay,
          splashColor: style.splash,
          onHover: (v) => setState(() => _hovered = v),
          onFocusChange: (v) => setState(() => _focused = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          // La etiqueta la declara el Semantics de afuera; sin excluir esto el
          // lector de pantalla anuncia el texto dos veces.
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: style.height),
              child: Padding(padding: style.padding, child: content),
            ),
          ),
        ),
      ),
    );

    // MergeSemantics envuelve al Semantics y NO al revés: al revés quedan dos
    // nodos hermanos y el lector de pantalla anuncia dos controles.
    return MergeSemantics(
      child: Semantics(
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
              scale: _pressed && !disabled ? m.pressScale : 1,
              duration: m.fast,
              curve: m.emphasized,
              // El anillo lo pinta un `CustomPaint`, NO un `Stack`: el Stack se
              // estira al ancho del padre y descentra el área sensible al mouse.
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

/// Anillo de foco dibujado por fuera del botón, sin ocupar espacio ni influir
/// en el layout.
class _FocusRingPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;

  /// 0 = sin anillo, 1 = anillo completo. Se anima por opacidad, no por grosor.
  final double progress;

  const _FocusRingPainter({
    required this.color,
    required this.radius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Medio grosor extra: el trazo se centra en su propio ancho.
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

/// Spinner de carga con su separación ya incluida. Ocupa el lugar del icono
/// izquierdo, no del texto, para que el ancho del botón no salte.
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
/// variantes**. Todos los campos son requeridos, así que una variante nueva no
/// puede olvidarse de un estado.
@immutable
class _SButtonStyle {
  final Color background;

  /// Fondo con el puntero encima o con foco de teclado.
  final Color backgroundHighlight;

  final Color foreground;

  /// Solo cambia en el secundario, que se tiñe de marca junto con el borde.
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

  /// Velo de press del InkWell.
  final Color pressOverlay;

  final Color splash;

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
  /// [colors] llega aparte de [theme] para poder resolver contra un set fijo
  /// ([SozuColorRoles.light]) sin `BuildContext`.
  factory _SButtonStyle.resolve({
    required SButtonVariant variant,
    required SButtonSize size,
    required SozuColorRoles colors,
    required SozuTheme theme,
    Color? colorOverride,
  }) {
    final m = _SButtonMetrics.forSize(size, theme);
    final c = colors;

    final radius = theme.radius.mdBorder;

    switch (variant) {
      case SButtonVariant.primary:
        final base = colorOverride ?? c.primary;
        return _SButtonStyle(
          background: base,
          // Con override no hay rol `*Hover` que consultar y solo queda
          // oscurecer.
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
          // `primarySoftStrong` (10%) y no `primarySoft` (6%): al 6% el hover
          // apenas se distingue del reposo. Mismo criterio que los badges.
          backgroundHighlight: c.primarySoftStrong,
          foreground: colorOverride ?? c.fg,
          foregroundHighlight: accent,
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
          // No existe un rol `dangerHover`: se oscurece a mano.
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
          focusRing: base.withValues(alpha: 0.35),
          underlineOnHover: false,
        );

      case SButtonVariant.link:
        // primaryHover y no primary: el primario no alcanza contraste AA en
        // texto chico sobre superficie clara.
        final fg = colorOverride ?? c.primaryHover;
        return _SButtonStyle(
          background: Colors.transparent,
          backgroundHighlight: Colors.transparent,
          foreground: fg,
          foregroundHighlight: fg,
          border: null,
          borderHighlight: null,
          height: m.height,
          padding: m.linkPadding,
          textStyle: theme.text.body.copyWith(fontWeight: FontWeight.w600),
          radius: theme.radius.smBorder,
          iconSize: m.linkIconSize,
          gap: m.gap,
          pressOverlay: Colors.transparent,
          splash: Colors.transparent,
          focusRing: c.primaryBorder,
          underlineOnHover: true,
        );
    }
  }
}

/// Medidas por tamaño. El TEXTO no cambia con el tamaño: lo que distingue a un
/// `sm` de un `lg` es el aire, no la letra.
@immutable
class _SButtonMetrics {
  final double height;
  final double iconSize;
  final EdgeInsets padding;

  /// El enlace no tiene caja que le dé alto, pero sí debe llegar al mínimo
  /// táctil.
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
    // Padding vertical 0 a propósito: el alto lo fija `height` como minHeight y
    // sumar vertical haría crecer el botón con texto de dos líneas.
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
          // El cuerpo escala con el control: 18 en un boton de 36 px iba
          // apretado. Peso y familia los sigue dando el rol tipografico.
          textStyle: t.text.bodySmall.copyWith(fontWeight: FontWeight.w600),
          gap: t.space.xs,
        );
      case SButtonSize.md:
        return _SButtonMetrics(
          height: 44,
          iconSize: 18,
          padding: h(t.space.md),
          linkPadding: linkPadding,
          linkIconSize: 15,
          textStyle: t.text.label,
          gap: t.space.xs,
        );
      case SButtonSize.lg:
        return _SButtonMetrics(
          height: 56,
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

/// Oscurece un color mezclándole negro al 10%. Solo cuando NO hay un rol
/// `*Hover` disponible: el rol sabe que en tema oscuro el hover aclara.
Color _darken(Color base) => Color.alphaBlend(SozuAlpha.black10, base);
