import 'package:flutter/material.dart';

import '../core/portal_theme.dart';

/// Widgets base del "modo portal" web (réplica del Portal del Cliente de
/// sozu-admin). Reutilizables entre pantallas: cards, pills de filtro, chips
/// de estatus, icon-buttons de tabla, botón primario verde, labels uppercase
/// y filas label/valor (con copiar opcional).
///
/// Solo se usan cuando [isPortalMode] es true; no tocan el tema móvil.

/// TextStyle del portal: system font stack + tamaños exactos del spec.
TextStyle portalText({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = PortalColors.foreground,
  double? letterSpacing,
  double? height,
  bool tabular = false,
  bool mono = false,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFamily: mono ? 'monospace' : null,
    fontFamilyFallback: mono ? null : kPortalFontFallback,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

/// Expone el estado hover para replicar los `hover:` de Tailwind.
class PortalHoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;

  const PortalHoverBuilder({super.key, required this.builder});

  @override
  State<PortalHoverBuilder> createState() => _PortalHoverBuilderState();
}

class _PortalHoverBuilderState extends State<PortalHoverBuilder> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.builder(context, _hover),
    );
  }
}

/// Card del portal: blanca, radio 24 (`rounded-2xl`), borde 1px #E5E7EB,
/// SIN sombra (tokens.md §4).
class PortalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// true para cards con headers/filas de color propio (recorta al radio).
  final bool clip;
  final Color? borderColor;

  const PortalCard({
    super.key,
    required this.child,
    this.padding,
    this.clip = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: PortalColors.surface,
        borderRadius: BorderRadius.circular(kPortalRadiusCard),
        border: Border.all(color: borderColor ?? PortalColors.border),
      ),
      child: child,
    );
  }
}

/// Label uppercase 11px w600 tracking-wider #6B7280 (filtros, thead).
class PortalSectionLabel extends StatelessWidget {
  final String text;
  final double size;

  const PortalSectionLabel(this.text, {super.key, this.size = 11});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: portalText(
        size: size,
        weight: FontWeight.w600,
        color: PortalColors.mutedForeground,
        letterSpacing: size * 0.05, // tracking-wider = 0.05em
      ),
    );
  }
}

/// Pill de filtro: activa verde sólida con texto blanco; inactiva blanca con
/// borde #E5E7EB y hover con borde primary/30.
class PortalPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const PortalPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PortalHoverBuilder(
      builder: (context, hovered) {
        final Color bg = active ? PortalColors.primary : PortalColors.surface;
        final Color fg = active ? Colors.white : PortalColors.mutedForeground;
        final Color border = active
            ? PortalColors.primary
            : hovered
            ? PortalColors.primaryBorder30
            : PortalColors.border;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: portalText(size: 11, weight: FontWeight.w500, color: fg),
            ),
          ),
        );
      },
    );
  }
}

/// Chip de estatus con icono opcional: "Pagado" (verde), "Pendiente"/"Parcial"
/// (ámbar), "Pago Pendiente", etc. [small] = variante del card resumen
/// (10px, px-2 py-0.5, sin icono).
class PortalStatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final bool small;

  const PortalStatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: portalText(
              size: small ? 10 : 11,
              weight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-button de tabla (`p-1.5 rounded-lg`, icono 16): habilitado gris con
/// hover fondo muted + icono verde; deshabilitado al 25%; [loading] pinta un
/// spinner de 16px en su lugar.
class PortalIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  const PortalIconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Tooltip(
      message: tooltip,
      child: PortalHoverBuilder(
        builder: (context, hovered) {
          final Color fg = !enabled
              ? PortalColors.mutedForeground.withValues(alpha: .25)
              : hovered
              ? PortalColors.primary
              : PortalColors.mutedForeground;
          return GestureDetector(
            onTap: enabled ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: enabled && hovered
                    ? PortalColors.muted
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(kPortalRadiusMd),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PortalColors.mutedForeground,
                      ),
                    )
                  : Icon(icon, size: 16, color: fg),
            ),
          );
        },
      ),
    );
  }
}

/// Botón primario verde del portal ("Descargar PDF"): radio 16, padding
/// 14/10, texto 12 w600 blanco, icono 14, sombra sutil; en [loading] muestra
/// spinner + [loadingLabel].
class PortalPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  const PortalPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return PortalHoverBuilder(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: enabled ? onPressed : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: loading ? 0.6 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: enabled && hovered
                    ? PortalColors.primaryHover
                    : PortalColors.primary,
                borderRadius: BorderRadius.circular(kPortalRadiusLg),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000), // shadow-sm
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    loading ? (loadingLabel ?? label) : label,
                    style: portalText(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Botón secundario del portal: blanco con borde, texto 12 w600.
class PortalOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const PortalOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PortalHoverBuilder(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: hovered ? PortalColors.mutedHover : PortalColors.surface,
              borderRadius: BorderRadius.circular(kPortalRadiusLg),
              border: Border.all(
                color: hovered
                    ? PortalColors.primaryBorder30
                    : PortalColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: PortalColors.mutedForeground),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: portalText(
                    size: 12,
                    weight: FontWeight.w600,
                    color: PortalColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fila label/valor 11px del portal (resumen, instrucciones): label muted a
/// la izquierda, valor semibold a la derecha; [onCopy] añade el botón copiar
/// (icono 12 verde, hover fondo muted) como en la fila CLABE.
class PortalInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;
  final VoidCallback? onCopy;

  const PortalInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: portalText(size: 11, color: PortalColors.mutedForeground),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: portalText(
              size: mono ? 12 : 11,
              weight: FontWeight.w600,
              color: valueColor ?? PortalColors.foreground,
              mono: mono,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          PortalHoverBuilder(
            builder: (context, hovered) => GestureDetector(
              onTap: onCopy,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: hovered ? PortalColors.muted : Colors.transparent,
                  borderRadius: BorderRadius.circular(kPortalRadiusSm),
                ),
                child: const Icon(
                  Icons.copy_outlined,
                  size: 12,
                  color: PortalColors.primary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
