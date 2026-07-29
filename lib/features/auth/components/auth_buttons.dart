import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Botón primario del acceso.
///
/// Color plano, sin degradado ni glow: el degradado con resplandor verde es lo
/// que abarataba la pantalla; los accesos que se ven caros usan un rectángulo de
/// color sólido.
///
/// La capa interactiva es un `InkWell` sobre `Material`, no un
/// `GestureDetector`: el gesture detector no es enfocable, así que el botón era
/// inalcanzable con Tab y no respondía a Enter/Espacio — con teclado el login
/// solo se podía enviar desde el campo de contraseña.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final isDisabled = onPressed == null || loading;

    final content = loading
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: c.onPrimary,
                  strokeWidth: 2.2,
                ),
              ),
              SizedBox(width: t.space.xs),
              Text(loadingLabel ?? label),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: c.onPrimary),
                SizedBox(width: t.space.xs),
              ],
              Text(label),
            ],
          );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: loading ? (loadingLabel ?? label) : label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.5 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: t.radius.mdBorder,
            color: c.primary,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: t.radius.mdBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: t.radius.mdBorder,
              // El hover OSCURECE, no aclara: aclarar sobre un color ya claro
              // se pierde.
              hoverColor: Colors.black.withValues(alpha: 0.10),
              focusColor: Colors.black.withValues(alpha: 0.16),
              splashColor: c.onPrimary.withValues(alpha: 0.14),
              child: SizedBox(
                height: 52,
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: t.text.button.copyWith(color: c.onPrimary),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario con contorno: borde de 1.5 px que se tiñe de verde en hover
/// o foco de teclado. Usado para la entrada biométrica.
///
/// 1.5 px y no 2: junto a un botón primario plano, un contorno grueso pesa más
/// que el botón que sí es la acción principal.
class AuthOutlineButton extends StatefulWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;

  @override
  State<AuthOutlineButton> createState() => _AuthOutlineButtonState();
}

class _AuthOutlineButtonState extends State<AuthOutlineButton> {
  /// hover del mouse o foco de teclado — los dos pintan igual.
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final isDisabled = widget.onPressed == null || widget.loading;
    final isActive = _isHighlighted && !isDisabled;
    final contentColor = isActive ? c.primary : c.fg;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: t.radius.mdBorder,
            border: Border.all(
              color: isActive ? c.primary : c.border,
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: t.radius.mdBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isDisabled ? null : widget.onPressed,
              borderRadius: t.radius.mdBorder,
              onHover: (v) => setState(() => _isHighlighted = v),
              onFocusChange: (v) => setState(() => _isHighlighted = v),
              hoverColor: c.primarySoft,
              splashColor: c.primarySoftStrong,
              child: SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      IconTheme.merge(
                        data: IconThemeData(color: contentColor, size: 20),
                        child: widget.icon!,
                      ),
                      SizedBox(width: t.space.xs),
                    ],
                    Text(
                      widget.label,
                      style: t.text.button.copyWith(color: contentColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Enlace de texto del acceso.
///
/// El feedback de hover es el **subrayado**, no un fondo: un enlace dentro de un
/// formulario no debe leerse como un tercer botón compitiendo con la acción
/// principal.
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // primaryHover (verde oscuro), no primary: sobre superficie clara el
    // primario no alcanza contraste AA para texto chico.
    final linkColor = t.color.primaryHover;

    return _HoverUnderline(
      onPressed: onPressed,
      builder: (isHovered) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: linkColor),
            SizedBox(width: t.space.xxs + 2),
          ],
          Text(
            label,
            style: t.text.body.copyWith(
              fontWeight: FontWeight.w600,
              color: linkColor,
              decoration: isHovered ? TextDecoration.underline : null,
              decorationColor: linkColor,
              decorationThickness: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Envoltura de enlace: cursor de mano, subrayado en hover y área táctil de
/// 44 px, SIN el overlay ni el fondo de un `TextButton`.
///
/// Se usa `MouseRegion` + `GestureDetector` en lugar de `TextButton` con
/// `overlayColor: transparent` porque el botón también aporta ripple, elevación
/// de estado y padding propio que habría que neutralizar uno por uno; sale más
/// limpio no partir de un botón.
class _HoverUnderline extends StatefulWidget {
  const _HoverUnderline({required this.onPressed, required this.builder});

  final VoidCallback onPressed;
  final Widget Function(bool isHovered) builder;

  @override
  State<_HoverUnderline> createState() => _HoverUnderlineState();
}

class _HoverUnderlineState extends State<_HoverUnderline> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      button: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            // 44 px de alto mínimo: el enlace es un destino táctil real, no solo
            // texto (medía ~26 px y fallaba el mínimo de Apple/Material).
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.s.space.xxs,
                vertical: context.s.space.xs,
              ),
              child: Align(
                alignment: Alignment.center,
                child: widget.builder(_isHovered),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
