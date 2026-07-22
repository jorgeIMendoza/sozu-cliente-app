import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Verde de marca de WhatsApp (para el ícono suelto, sin fondo verde propio).
const Color kWhatsAppGreen = Color(0xFF25D366);

/// Logo de WhatsApp (globo de chat con auricular telefónico) dibujado con
/// [CustomPaint] a partir del MISMO path SVG que usa el portal
/// (`AdvisorCard.tsx`, simple-icons). El proyecto no tiene `flutter_svg`, así
/// que un parser mínimo de path (abajo) lo convierte a [Path] y se pinta con
/// [color] sobre cualquier fondo — nítido a 18-20 px.
///
/// Uso: blanco sobre el fondo verde de un botón, o [kWhatsAppGreen] si va
/// suelto.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({super.key, this.size = 18, this.color = kWhatsAppGreen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WhatsAppPainter(color)),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;

  const _WhatsAppPainter(this.color);

  /// Path SVG del glifo (viewBox 0 0 24 24), idéntico al del portal.
  static const String _svgPath =
      'M.057 24l1.687-6.163a11.867 11.867 0 0 1-1.587-5.946C.16 5.335 5.495 0 '
      '12.05 0a11.817 11.817 0 0 1 8.413 3.488 11.824 11.824 0 0 1 3.48 '
      '8.414c-.003 6.557-5.338 11.892-11.893 11.892a11.9 11.9 0 0 1-5.688-1.448'
      'L.057 24zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-'
      '4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-'
      '9.889 9.884a9.86 9.86 0 0 0 1.51 5.26l-.999 3.648 3.978-1.607zm11.387-'
      '5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-'
      '.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347'
      '.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-'
      '1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-'
      '.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.149-.669-1.612-.916-'
      '2.207-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-'
      '1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 '
      '4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 '
      '1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z';

  static final Path _base = _parseSvgPath(_svgPath);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);
    canvas.drawPath(_base, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WhatsAppPainter old) => old.color != color;
}

/// Parser mínimo de un atributo `d` de SVG a [Path]. Soporta los comandos
/// M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z (absolutos y relativos), suficiente
/// para glifos de simple-icons como el de WhatsApp.
final RegExp _pathToken = RegExp(
  r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?',
);

Path _parseSvgPath(String d) {
  final path = Path();
  final toks = _pathToken.allMatches(d).map((m) => m.group(0)!).toList();
  int i = 0;
  double cx = 0, cy = 0; // punto actual
  double sx = 0, sy = 0; // inicio del subpath
  double pcx = 0, pcy = 0; // último punto de control (para S/T)
  String cmd = '';
  String lastCmd = '';

  bool isCmd(String t) =>
      t.length == 1 && 'MmLlHhVvCcSsQqTtAaZz'.contains(t);
  double n() => double.parse(toks[i++]);

  while (i < toks.length) {
    if (isCmd(toks[i])) {
      cmd = toks[i];
      i++;
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        cx = sx;
        cy = sy;
        lastCmd = cmd;
        continue;
      }
    } else if (cmd.isEmpty) {
      i++; // token inesperado antes del primer comando: evita bucle infinito
      continue;
    }

    switch (cmd) {
      case 'M':
        cx = n();
        cy = n();
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
        cmd = 'L';
        break;
      case 'm':
        cx += n();
        cy += n();
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
        cmd = 'l';
        break;
      case 'L':
        cx = n();
        cy = n();
        path.lineTo(cx, cy);
        break;
      case 'l':
        cx += n();
        cy += n();
        path.lineTo(cx, cy);
        break;
      case 'H':
        cx = n();
        path.lineTo(cx, cy);
        break;
      case 'h':
        cx += n();
        path.lineTo(cx, cy);
        break;
      case 'V':
        cy = n();
        path.lineTo(cx, cy);
        break;
      case 'v':
        cy += n();
        path.lineTo(cx, cy);
        break;
      case 'C':
        {
          final x1 = n(), y1 = n(), x2 = n(), y2 = n(), x = n(), y = n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          pcx = x2;
          pcy = y2;
          cx = x;
          cy = y;
        }
        break;
      case 'c':
        {
          final x1 = cx + n(),
              y1 = cy + n(),
              x2 = cx + n(),
              y2 = cy + n(),
              x = cx + n(),
              y = cy + n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          pcx = x2;
          pcy = y2;
          cx = x;
          cy = y;
        }
        break;
      case 'S':
        {
          final refl = 'CcSs'.contains(lastCmd);
          final x1 = refl ? 2 * cx - pcx : cx;
          final y1 = refl ? 2 * cy - pcy : cy;
          final x2 = n(), y2 = n(), x = n(), y = n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          pcx = x2;
          pcy = y2;
          cx = x;
          cy = y;
        }
        break;
      case 's':
        {
          final refl = 'CcSs'.contains(lastCmd);
          final x1 = refl ? 2 * cx - pcx : cx;
          final y1 = refl ? 2 * cy - pcy : cy;
          final x2 = cx + n(), y2 = cy + n(), x = cx + n(), y = cy + n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          pcx = x2;
          pcy = y2;
          cx = x;
          cy = y;
        }
        break;
      case 'Q':
        {
          final x1 = n(), y1 = n(), x = n(), y = n();
          path.quadraticBezierTo(x1, y1, x, y);
          pcx = x1;
          pcy = y1;
          cx = x;
          cy = y;
        }
        break;
      case 'q':
        {
          final x1 = cx + n(), y1 = cy + n(), x = cx + n(), y = cy + n();
          path.quadraticBezierTo(x1, y1, x, y);
          pcx = x1;
          pcy = y1;
          cx = x;
          cy = y;
        }
        break;
      case 'T':
        {
          final refl = 'QqTt'.contains(lastCmd);
          final x1 = refl ? 2 * cx - pcx : cx;
          final y1 = refl ? 2 * cy - pcy : cy;
          final x = n(), y = n();
          path.quadraticBezierTo(x1, y1, x, y);
          pcx = x1;
          pcy = y1;
          cx = x;
          cy = y;
        }
        break;
      case 't':
        {
          final refl = 'QqTt'.contains(lastCmd);
          final x1 = refl ? 2 * cx - pcx : cx;
          final y1 = refl ? 2 * cy - pcy : cy;
          final x = cx + n(), y = cy + n();
          path.quadraticBezierTo(x1, y1, x, y);
          pcx = x1;
          pcy = y1;
          cx = x;
          cy = y;
        }
        break;
      case 'A':
        {
          final rx = n(), ry = n(), rot = n(), laf = n(), sf = n();
          final x = n(), y = n();
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx.abs(), ry.abs()),
            rotation: rot * math.pi / 180,
            largeArc: laf != 0,
            clockwise: sf != 0,
          );
          cx = x;
          cy = y;
        }
        break;
      case 'a':
        {
          final rx = n(), ry = n(), rot = n(), laf = n(), sf = n();
          final x = cx + n(), y = cy + n();
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx.abs(), ry.abs()),
            rotation: rot * math.pi / 180,
            largeArc: laf != 0,
            clockwise: sf != 0,
          );
          cx = x;
          cy = y;
        }
        break;
      default:
        i++; // comando no soportado: no consumir en bucle
        break;
    }
    lastCmd = cmd;
  }
  return path;
}
