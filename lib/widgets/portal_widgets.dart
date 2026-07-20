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

// ---------------------------------------------------------------------------
// Widgets añadidos para las vistas portal de Inicio / Patrimonio / Adquisición
// (réplicas de ClienteInicio, ClientePatrimonio y ClienteEnAdquisicion).
// ---------------------------------------------------------------------------

/// Barra de progreso fina del portal: 3px de alto, pista #F3F4F6 y relleno
/// verde (réplica del `h-[3px] bg-muted` + `bg-primary` de las cards).
class PortalThinProgressBar extends StatelessWidget {
  final double percent; // 0-100
  final double height;

  const PortalThinProgressBar({
    super.key,
    required this.percent,
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    final factor = (percent / 100).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: PortalColors.muted,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: factor,
            child: Container(color: PortalColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de página del portal: h1 26px w700 tracking-tight + subtítulo
/// 13px muted (como ClientePatrimonio / ClienteEnAdquisicion).
class PortalPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PortalPageHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: portalText(size: 26, weight: FontWeight.w700, letterSpacing: -0.65),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: portalText(size: 13, color: PortalColors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

/// Pinta el borde punteado redondeado del portal (`border-dashed`).
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius)),
      );
    const dash = 4.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/// Botón "Ver todas…/Ver N más" del portal: texto 13 w500 verde con borde
/// punteado primary/30 y hover con fondo primary suave.
class PortalDashedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const PortalDashedButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: const _DashedRRectPainter(
            PortalColors.primaryBorder30,
            kPortalRadiusLg,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: hovered ? PortalColors.primarySoft6 : Colors.transparent,
              borderRadius: BorderRadius.circular(kPortalRadiusLg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: portalText(
                    size: 13,
                    weight: FontWeight.w500,
                    color: PortalColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: PortalColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío del portal: card con borde punteado, icono en caja muted,
/// título semibold y mensaje muted centrados.
class PortalEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const PortalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedRRectPainter(PortalColors.border, kPortalRadiusCard),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PortalColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: PortalColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: portalText(size: 15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: portalText(size: 13, color: PortalColors.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Celda KPI del portal: label uppercase 10px tracking-[0.18em] + valor 22px
/// bold tabular (KpiCell de ClientePatrimonio).
class PortalKpiCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const PortalKpiCell({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return PortalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: portalText(
              size: 10,
              weight: FontWeight.w600,
              color: PortalColors.mutedForeground,
              letterSpacing: 1.8, // tracking-[0.18em]
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: portalText(
                size: 22,
                weight: FontWeight.w700,
                color: valueColor ?? PortalColors.foreground,
                tabular: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid responsivo del portal (Wrap con N columnas según el ancho): réplica
/// de los `grid grid-cols-1 lg:grid-cols-2 gap-4` de los listados.
class PortalCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  /// Ancho mínimo por columna antes de bajar el número de columnas.
  final double minItemWidth;
  final int maxCols;

  const PortalCardGrid({
    super.key,
    required this.children,
    this.gap = 16,
    this.minItemWidth = 340,
    this.maxCols = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + gap) / (minItemWidth + gap))
            .floor()
            .clamp(1, maxCols);
        final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final w in children) SizedBox(width: itemW, child: w),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Modales centrados del portal (Perfil: "Ver todo", editar datos, etc.)
// ---------------------------------------------------------------------------

/// Abre [child] como diálogo centrado del portal (max ~[maxWidth] px), en
/// lugar del fullscreen / bottom-sheet del layout móvil. Usar solo cuando
/// [isPortalMode] es true.
Future<T?> showPortalDialog<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 560,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: PortalColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kPortalRadiusLg),
        side: const BorderSide(color: PortalColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: child,
      ),
    ),
  );
}

/// Shell de diálogo del portal: header con título/subtítulo, acciones
/// opcionales (p. ej. "Editar") y botón de cerrar, más cuerpo scrolleable.
/// Réplica de las vistas "Ver todo" de ClientePerfil.tsx en modo portal.
class PortalDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const PortalDialogShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: portalText(size: 16, weight: FontWeight.w700),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(
                          size: 12,
                          color: PortalColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
              const SizedBox(width: 4),
              PortalIconBtn(
                icon: Icons.close,
                tooltip: 'Cerrar',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Container(height: 1, color: PortalColors.border),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Botón full-width de las tarjetas de sección del Perfil en modo portal:
/// primary = verde sólido, secondary = blanco con borde, danger = rojo suave
/// (espejo de los CTAs de SectionCard en ClientePerfil.tsx).
enum PortalBlockButtonStyle { primary, secondary, danger }

class PortalBlockButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final PortalBlockButtonStyle style;
  final IconData? icon;

  const PortalBlockButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PortalBlockButtonStyle.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PortalHoverBuilder(
      builder: (context, hovered) {
        final (Color bg, Color fg, Color? border) = switch (style) {
          PortalBlockButtonStyle.primary => (
            hovered ? PortalColors.primaryHover : PortalColors.primary,
            Colors.white,
            null,
          ),
          PortalBlockButtonStyle.secondary => (
            hovered ? PortalColors.mutedHover : PortalColors.surface,
            PortalColors.foreground,
            hovered ? PortalColors.primaryBorder30 : PortalColors.border,
          ),
          PortalBlockButtonStyle.danger => (
            hovered ? PortalColors.destructiveSoft10 : const Color(0xFFFFF9F9),
            PortalColors.destructive,
            const Color(0xFFFCDADA),
          ),
        };
        return GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(kPortalRadiusSm),
              border: border != null ? Border.all(color: border) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: portalText(size: 13, weight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers genéricos añadidos para Pagos / Productos / Notificaciones (modo
// portal). Solo aditivos: no cambian nada de lo anterior.
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kPortalMesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Fecha corta es-MX como el portal: "15 jul 2026" ('—' si no parsea).
String portalShortDate(String? fecha) {
  final d = DateTime.tryParse(fecha ?? '');
  if (d == null) return '—';
  return '${d.day} ${_kPortalMesesCortos[d.month - 1]} ${d.year}';
}

/// Colores (fondo, texto) del chip de estatus de propiedad — statusStyles del
/// portal (statusTone): vencido/demanda en rojo (destructive), pendiente en
/// ámbar (warning), resto en verde (primary).
(Color, Color) portalEstatusStyle(String estatus) {
  final e = estatus.toLowerCase();
  if (e.contains('vencid') ||
      e.contains('demanda') ||
      e.contains('mora') ||
      e.contains('atras') ||
      e.contains('cancel')) {
    return (PortalColors.destructiveSoft10, PortalColors.destructive);
  }
  if (e.contains('pendiente')) {
    return (PortalColors.warningSoft15, PortalColors.warning);
  }
  return (PortalColors.primarySoft15, PortalColors.primary);
}

/// Color del punto de estatus de la card de propiedad — getPropertyStatus del
/// portal (4 estados por etapa activa): `pago_final` en ámbar; preventa,
/// escrituración, entrega, post-entrega (éxito) y default en verde primario.
/// La paleta del portal no tiene un token `success` distinto, así que éxito
/// colapsa a [PortalColors.primary]; `destructive` queda reservado para
/// estatus vencidos vía [portalEstatusStyle].
Color portalPropiedadDotColor(String? etapaActiva) {
  switch (etapaActiva) {
    case 'pago_final':
      return PortalColors.warning;
    case 'preventa':
    case 'escrituracion':
    case 'entrega':
    case 'post_entrega':
      return PortalColors.primary;
    default:
      return PortalColors.primary;
  }
}

/// Expone hover y "pressed" para replicar `hover:` + `active:scale` del portal.
/// Aditivo: no reemplaza a [PortalHoverBuilder] (que sigue usándose donde no
/// hace falta el estado de presión).
class PortalPressable extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered, bool pressed)
      builder;

  const PortalPressable({super.key, required this.builder});

  @override
  State<PortalPressable> createState() => _PortalPressableState();
}

class _PortalPressableState extends State<PortalPressable> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: widget.builder(context, _hover, _pressed),
      ),
    );
  }
}

/// Bloque de carga del portal con pulso de opacidad (equivalente a
/// `animate-pulse` de Tailwind): caja `bg-muted` que late entre 45% y 100%.
class PortalSkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  const PortalSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.circle = false,
  });

  @override
  State<PortalSkeletonBox> createState() => _PortalSkeletonBoxState();
}

class _PortalSkeletonBoxState extends State<PortalSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: PortalColors.muted,
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.circle ? null : BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton de una card de listado del portal (imagen 120×100 + títulos +
/// métricas + footer): réplica de los SkeletonCard/CardSkeleton de
/// ClientePatrimonio y ClienteEnAdquisicion.
class PortalCardSkeleton extends StatelessWidget {
  const PortalCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalCard(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                PortalSkeletonBox(width: 120, height: 100, radius: 12),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PortalSkeletonBox(width: 170, height: 14),
                      ),
                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PortalSkeletonBox(width: 110, height: 11),
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: PortalSkeletonBox(height: 32)),
                          SizedBox(width: 12),
                          Expanded(child: PortalSkeletonBox(height: 32)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PortalColors.borderSoft)),
            ),
            child: Row(
              children: const [
                PortalSkeletonBox(width: 84, height: 20, radius: 999),
                SizedBox(width: 12),
                PortalSkeletonBox(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton de una celda KPI del portal (label + valor): réplica del pulse de
/// los KpiCell de ClientePatrimonio.
class PortalKpiSkeleton extends StatelessWidget {
  const PortalKpiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PortalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Align(
            alignment: Alignment.centerLeft,
            child: PortalSkeletonBox(width: 90, height: 10),
          ),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PortalSkeletonBox(width: 120, height: 22),
          ),
        ],
      ),
    );
  }
}

/// Buscador del portal: alto 40, radio 16, borde #E5E7EB y focus verde
/// (mismo input de "Buscar propiedad…" de las páginas del portal).
class PortalSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const PortalSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        onChanged: onChanged,
        style: portalText(size: 13),
        cursorColor: PortalColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: portalText(
            size: 13,
            color: PortalColors.mutedForeground.withValues(alpha: .7),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: PortalColors.mutedForeground.withValues(alpha: .7),
          ),
          filled: true,
          fillColor: PortalColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            borderSide: const BorderSide(color: PortalColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            borderSide: const BorderSide(color: PortalColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso del portal (`h-2 bg-muted` + relleno verde): pista
/// #F3F4F6 y relleno primary, redonda; [height] 8px por defecto.
class PortalProgressBar extends StatelessWidget {
  /// 0–100.
  final double percent;
  final double height;

  const PortalProgressBar({
    super.key,
    required this.percent,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final f = (percent / 100).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: PortalColors.muted,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: f,
          child: Container(color: PortalColors.primary),
        ),
      ),
    );
  }
}

