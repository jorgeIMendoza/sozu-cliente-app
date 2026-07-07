import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

/// Mapa del nivel dibujado desde `regiones` (polígonos 0–100), resaltando la
/// unidad del cliente con un pulso animado (glow). Port de LevelMap.tsx.
class LevelMap extends StatefulWidget {
  final List<RegionNivel> regiones;
  final String? numeroDepa;

  const LevelMap({super.key, required this.regiones, required this.numeroDepa});

  @override
  State<LevelMap> createState() => _LevelMapState();
}

class _LevelMapState extends State<LevelMap>
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
      aspectRatio: 1,
      child: CustomPaint(
        painter: _LevelPainter(
          regiones: widget.regiones,
          target: widget.numeroDepa == null ? null : _norm(widget.numeroDepa!),
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

class _LevelPainter extends CustomPainter {
  final List<RegionNivel> regiones;
  final String? target;
  final Animation<double> pulse;

  _LevelPainter({
    required this.regiones,
    required this.target,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    // Curva suave 0→1→0 para el pulso.
    final t = Curves.easeInOut.transform(pulse.value);

    Path pathOf(RegionNivel r) {
      final path = Path();
      for (var i = 0; i < r.polygon.length; i++) {
        final x = r.polygon[i][0] * sx;
        final y = r.polygon[i][1] * sy;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path..close();
    }

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
          ..color =
              Color.lerp(SozuColors.emerald600, SozuColors.emerald400, t)!,
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
      for (final p in r.polygon) {
        cx += p[0];
        cy += p[1];
      }
      cx = cx / r.polygon.length * sx;
      cy = cy / r.polygon.length * sy;

      // El número de tu unidad crece con la inhalación.
      final fontSize = active
          ? size.width * (0.055 + 0.025 * t)
          : size.width * 0.05;
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
      old.regiones != regiones || old.target != target;
}
