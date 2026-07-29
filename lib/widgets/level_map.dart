import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

/// Mapa del nivel dibujado desde `regiones` (polígonos), resaltando la unidad
/// del cliente con un pulso animado (glow). Port de LevelMap.tsx.
///
/// A diferencia del original (cuadrado), respeta el aspecto real del bounding
/// box de las regiones — por eso se ve horizontal como en el portal — y es
/// compacto para caber en la columna "UBICACIÓN EN EL NIVEL" del
/// [BuildingDiagram]. Un icono de expandir abre la planta a mayor tamaño en un
/// diálogo.
class LevelMap extends StatelessWidget {
  final List<RegionNivel> regiones;
  final String? numeroDepa;

  /// Muestra el icono de expandir (arriba-derecha). Se oculta dentro del propio
  /// diálogo ampliado.
  final bool showExpand;

  const LevelMap({
    super.key,
    required this.regiones,
    required this.numeroDepa,
    this.showExpand = true,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final bounds = _Bounds.of(regiones);
    final target = numeroDepa == null ? null : _norm(numeroDepa!);

    return Stack(
      children: [
        _BreathingMap(regiones: regiones, target: target, bounds: bounds),
        if (showExpand)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: tone.surface.withValues(alpha: 0.82),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openDialog(context, bounds, target),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(Icons.open_in_full,
                      size: 15, color: tone.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openDialog(BuildContext context, _Bounds bounds, String? target) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final tone = SozuTone.of(ctx);
        final media = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: tone.surface,
          insetPadding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Planta del nivel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tone.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, color: tone.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 640,
                    maxHeight: media.height * 0.6,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tone.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tone.border),
                    ),
                    child: _BreathingMap(
                      regiones: regiones,
                      target: target,
                      bounds: bounds,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: SozuColors.emerald500,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Tu unidad',
                        style:
                            TextStyle(fontSize: 12, color: tone.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lienzo con la animación de "respiración" de la unidad. Se reutiliza tanto en
/// la versión compacta (columna del diagrama) como en el diálogo ampliado.
class _BreathingMap extends StatefulWidget {
  final List<RegionNivel> regiones;
  final String? target;
  final _Bounds bounds;

  const _BreathingMap({
    required this.regiones,
    required this.target,
    required this.bounds,
  });

  @override
  State<_BreathingMap> createState() => _BreathingMapState();
}

class _BreathingMapState extends State<_BreathingMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.bounds.ratio,
      child: CustomPaint(
        painter: _LevelPainter(
          regiones: widget.regiones,
          target: widget.target,
          bounds: widget.bounds,
          pulse: _c,
        ),
      ),
    );
  }
}

String _norm(String v) {
  final r = v.replaceFirst(RegExp(r'^0+'), '');
  return r.isEmpty ? '0' : r;
}

/// Bounding box (en coordenadas de los polígonos) de todas las regiones, con su
/// relación de aspecto ancho/alto para dibujar el mapa horizontal.
class _Bounds {
  final double minX;
  final double minY;
  final double w;
  final double h;

  const _Bounds(this.minX, this.minY, this.w, this.h);

  /// Ratio ancho/alto, acotado para evitar extremos poco legibles.
  double get ratio => (w / h).clamp(0.6, 3.2);

  factory _Bounds.of(List<RegionNivel> regiones) {
    double minX = double.infinity,
        minY = double.infinity,
        maxX = -double.infinity,
        maxY = -double.infinity;
    for (final r in regiones) {
      for (final p in r.polygon) {
        if (p.length < 2) continue;
        final x = p[0], y = p[1];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (minX.isInfinite) return const _Bounds(0, 0, 100, 100);
    final w = maxX - minX;
    final h = maxY - minY;
    return _Bounds(minX, minY, w <= 0 ? 1 : w, h <= 0 ? 1 : h);
  }
}

class _LevelPainter extends CustomPainter {
  final List<RegionNivel> regiones;
  final String? target;
  final _Bounds bounds;
  final Animation<double> pulse;

  _LevelPainter({
    required this.regiones,
    required this.target,
    required this.bounds,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Padding proporcional (mantiene el ratio) para que halos/trazos no se
    // recorten en los bordes.
    const pad = 0.06;
    final padX = bounds.w * pad;
    final padY = bounds.h * pad;
    final sx = size.width / (bounds.w * (1 + 2 * pad));
    final sy = size.height / (bounds.h * (1 + 2 * pad));
    // Curva suave 0→1→0 para el pulso.
    final t = Curves.easeInOut.transform(pulse.value);

    double mapX(double x) => (x - bounds.minX + padX) * sx;
    double mapY(double y) => (y - bounds.minY + padY) * sy;

    Path pathOf(RegionNivel r) {
      final path = Path();
      for (var i = 0; i < r.polygon.length; i++) {
        if (r.polygon[i].length < 2) continue;
        final x = mapX(r.polygon[i][0]);
        final y = mapY(r.polygon[i][1]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path..close();
    }

    // Escala de texto relativa al lado menor para que se lea igual en compacto
    // y ampliado.
    final unit = size.shortestSide;

    // 1. Unidades normales.
    for (final r in regiones) {
      final active = target != null && _norm(r.unitNumber) == target;
      if (active) continue;
      final path = pathOf(r);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = SozuColors.slate100,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = SozuColors.slate300,
      );
    }

    // 2. Unidad del cliente al final (encima), con respiración profunda:
    //    doble halo que se expande + relleno que aclara al "inhalar".
    for (final r in regiones) {
      final active = target != null && _norm(r.unitNumber) == target;
      if (!active) continue;
      final path = pathOf(r);

      // Halo exterior amplio (respiración).
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + 16 * t
          ..color = SozuColors.emerald400.withValues(alpha: 0.15 + 0.35 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Halo interior más definido.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + 6 * t
          ..color = SozuColors.emerald400.withValues(alpha: 0.35 + 0.45 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Relleno que aclara notablemente al inhalar.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Color.lerp(SozuColors.emerald600, SozuColors.emerald400, t)!,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 1.5 * t
          ..color = SozuColors.emerald700,
      );
    }

    // 3. Números encima de todo.
    for (final r in regiones) {
      final active = target != null && _norm(r.unitNumber) == target;
      double cx = 0, cy = 0;
      var n = 0;
      for (final p in r.polygon) {
        if (p.length < 2) continue;
        cx += p[0];
        cy += p[1];
        n++;
      }
      if (n == 0) continue;
      cx = mapX(cx / n);
      cy = mapY(cy / n);

      // El número de tu unidad crece con la inhalación.
      final fontSize = active ? unit * (0.09 + 0.03 * t) : unit * 0.08;
      final tp = TextPainter(
        text: TextSpan(
          text: r.unitNumber,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : SozuColors.slate500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LevelPainter old) =>
      old.regiones != regiones ||
      old.target != target ||
      old.bounds != bounds;
}
