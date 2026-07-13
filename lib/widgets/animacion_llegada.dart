import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Variantes de la animación de llegada de notificaciones (configurables por
/// el admin en "Enviar avisos"; llegan al cliente vía cliente-notificaciones).
enum AnimacionCampana {
  sobre('sobre', 'Sobre volador ✉️'),
  gol('gol', 'Gol ⚽'),
  cohete('cohete', 'Cohete 🚀');

  final String clave;
  final String etiqueta;

  const AnimacionCampana(this.clave, this.etiqueta);

  static AnimacionCampana desde(String? clave) => AnimacionCampana.values
      .firstWhere((a) => a.clave == clave, orElse: () => AnimacionCampana.gol);
}

/// Fracción inicial de la línea de tiempo: aparición del proyectil al centro.
const kFase1Animacion = 0.16;

/// Desde aquí la red de la portería ondea (variante gol).
const kInicioGolAnimacion = 0.86;

/// Duración estándar de la animación completa.
const kDuracionAnimacion = Duration(milliseconds: 2300);

/// Frame de la animación para un instante `v` (0-1) del controller: dibuja el
/// proyectil (sobre/balón/cohete) viajando de `centro` a `destino` en
/// coordenadas del Stack contenedor (Overlay o preview). Motor compartido
/// entre la campana real (NotificationBell) y el demo del admin.
Widget frameAnimacionLlegada({
  required AnimacionCampana variante,
  required double v,
  required Offset centro,
  required Offset destino,
}) => switch (variante) {
  AnimacionCampana.sobre => _frameSobre(v, centro, destino),
  AnimacionCampana.gol => _frameGol(v, centro, destino),
  AnimacionCampana.cohete => _frameCohete(v, centro, destino),
};

// Coloca un widget en coordenadas del Stack contenedor (Transform.translate,
// no Positioned: el ParentData de Positioned no alcanza el Stack del Overlay
// con widgets intermedios).
Widget _en(Offset pos, double tam, Widget child) => Align(
  alignment: Alignment.topLeft,
  child: Transform.translate(
    offset: pos - Offset(tam / 2, tam / 2),
    child: child,
  ),
);

// ── SOBRE: aparece al centro y vuela "al viento" ─────────────────────────────
Widget _frameSobre(double v, Offset centro, Offset destino) {
  Offset pos;
  double escala;
  double opacity;
  double angulo;
  if (v < kFase1Animacion) {
    final k = Curves.easeOutBack.transform(v / kFase1Animacion);
    pos = centro;
    escala = 0.3 + 0.7 * k;
    opacity = (v / (kFase1Animacion * 0.5)).clamp(0.0, 1.0);
    angulo = -0.15 * (1 - k);
  } else {
    final k = Curves.easeInOutSine.transform(
      (v - kFase1Animacion) / (1 - kFase1Animacion),
    );
    final control = Offset(
      (centro.dx + destino.dx) / 2 - 70,
      math.min(centro.dy, destino.dy) - 90,
    );
    final u = 1 - k;
    final base = centro * (u * u) + control * (2 * u * k) + destino * (k * k);
    final calma = 1 - k;
    pos =
        base +
        Offset(
          14 * math.sin(5 * math.pi * k) * calma,
          18 * math.sin(3.5 * math.pi * k) * calma,
        );
    escala = k < 0.8 ? 1.0 : 1.0 - 0.6 * ((k - 0.8) / 0.2);
    opacity = k > 0.92 ? ((1 - k) / 0.08).clamp(0.0, 1.0) : 1.0;
    angulo = 0.45 * math.sin(4 * math.pi * k) * (0.3 + 0.7 * calma);
  }
  const tam = 52.0;
  return _en(
    pos,
    tam,
    Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angulo,
        child: Transform.scale(
          scale: escala,
          child: Container(
            width: tam,
            height: tam,
            decoration: const BoxDecoration(
              color: SozuColors.emerald500,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.email_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

// ── GOL: balón con botes decrecientes hasta la portería ─────────────────────
Widget _frameGol(double v, Offset centro, Offset destino) {
  Offset pos;
  double opacity;
  double angulo;
  double sx = 1, sy = 1;

  if (v < kFase1Animacion) {
    final k = Curves.easeOutBack.transform(v / kFase1Animacion);
    pos = centro;
    sx = sy = 0.3 + 0.7 * k;
    opacity = (v / (kFase1Animacion * 0.5)).clamp(0.0, 1.0);
    angulo = 0;
  } else {
    final k = (v - kFase1Animacion) / (1 - kFase1Animacion);
    const tramos = [0.36, 0.25, 0.17, 0.22];
    const alturas = [110.0, 52.0, 22.0, 0.0];
    var acc = 0.0;
    var i = 0;
    var s = 0.0;
    for (; i < tramos.length; i++) {
      if (k <= acc + tramos[i] || i == tramos.length - 1) {
        s = ((k - acc) / tramos[i]).clamp(0.0, 1.0);
        break;
      }
      acc += tramos[i];
    }
    final baseX = centro.dx + (destino.dx - centro.dx) * k;
    final baseY = centro.dy + (destino.dy - centro.dy) * k;
    if (i < 3) {
      final alto = 4 * alturas[i] * s * (1 - s);
      pos = Offset(baseX, baseY - alto);
      if (s < 0.09 || s > 0.91) {
        sx = 1.14;
        sy = 0.82;
      } else {
        final vuelo = (alto / alturas[0]).clamp(0.0, 1.0);
        sx = 1 - 0.05 * vuelo;
        sy = 1 + 0.07 * vuelo;
      }
      opacity = 1;
    } else {
      final e = Curves.easeIn.transform(s);
      pos = Offset(baseX, baseY - 14 * math.sin(math.pi * s));
      final enc = 1 - 0.65 * e;
      sx = enc;
      sy = enc;
      opacity = s > 0.55 ? ((1 - s) / 0.45).clamp(0.0, 1.0) : 1.0;
    }
    angulo = 5.5 * math.pi * Curves.easeOut.transform(k);
  }

  const tam = 44.0;
  return _en(
    pos,
    tam,
    Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angulo,
        child: Transform.scale(
          scaleX: sx,
          scaleY: sy,
          child: const SizedBox(
            width: tam,
            height: tam,
            child: CustomPaint(painter: BalonPainter()),
          ),
        ),
      ),
    ),
  );
}

// ── COHETE: enciende motores y despega en arco con estela ───────────────────
Widget _frameCohete(double v, Offset centro, Offset destino) {
  const tam = 48.0;
  final control = Offset(
    (centro.dx + destino.dx) / 2,
    math.min(centro.dy, destino.dy) - 170,
  );
  Offset puntoEn(double k) {
    final u = 1 - k;
    return centro * (u * u) + control * (2 * u * k) + destino * (k * k);
  }

  if (v < kFase1Animacion) {
    final k = Curves.easeOutBack.transform(v / kFase1Animacion);
    final jitter = Offset(
      2.2 * math.sin(40 * math.pi * v),
      1.5 * math.cos(34 * math.pi * v),
    );
    return _en(
      centro + jitter,
      tam,
      Opacity(
        opacity: (v / (kFase1Animacion * 0.5)).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.3 + 0.7 * k,
          child: const Text(
            '🚀',
            style: TextStyle(
              fontSize: 36,
              height: 1,
              shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }

  final k = Curves.easeInOutCubic.transform(
    (v - kFase1Animacion) / (1 - kFase1Animacion),
  );
  final pos = puntoEn(k);
  final dir =
      (control - centro) * (2 * (1 - k)) + (destino - control) * (2 * k);
  final angulo = math.atan2(dir.dy, dir.dx) + math.pi / 4;
  final escala = k < 0.85 ? 1.0 : 1.0 - 0.6 * ((k - 0.85) / 0.15);
  final opacity = k > 0.92 ? ((1 - k) / 0.08).clamp(0.0, 1.0) : 1.0;

  return Stack(
    children: [
      for (var i = 1; i <= 3; i++)
        if (k - i * 0.055 > 0)
          _en(
            puntoEn(k - i * 0.055),
            10,
            Opacity(
              opacity: ((0.55 - 0.15 * i) * opacity).clamp(0.0, 1.0),
              child: Container(
                width: 10.0 - 2 * i,
                height: 10.0 - 2 * i,
                decoration: BoxDecoration(
                  color: i == 1
                      ? const Color(0xFFFFB020)
                      : const Color(0xFFFF7043),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      _en(
        pos,
        tam,
        Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angulo,
            child: Transform.scale(
              scale: escala,
              child: const Text(
                '🚀',
                style: TextStyle(
                  fontSize: 36,
                  height: 1,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Balón clásico estilizado: base con degradado, pentágono central, gajos
/// perimetrales, costuras y brillo especular. Legible a 40-50 px.
class BalonPainter extends CustomPainter {
  const BalonPainter();

  Path _pentagono(Offset c, double r, double rot) {
    final p = Path();
    for (var i = 0; i < 5; i++) {
      final a = rot + i * 2 * math.pi / 5;
      final v = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(v.dx, v.dy) : p.lineTo(v.dx, v.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const negro = Color(0xFF23272E);

    canvas.drawCircle(
      c + Offset(0, r * 0.10),
      r * 0.96,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.45),
          radius: 1.15,
          colors: const [Colors.white, Color(0xFFE9EDF2), Color(0xFFC6CDD8)],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    final costura = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = negro.withValues(alpha: 0.55);

    final rotC = -math.pi / 2;
    canvas.drawPath(_pentagono(c, r * 0.34, rotC), Paint()..color = negro);

    for (var i = 0; i < 5; i++) {
      final a = rotC + math.pi / 5 + i * 2 * math.pi / 5;
      final centroGajo = c + Offset(math.cos(a), math.sin(a)) * (r * 0.92);
      canvas.drawPath(
        _pentagono(centroGajo, r * 0.34, a),
        Paint()..color = negro,
      );
      final desde = c + Offset(math.cos(a), math.sin(a)) * (r * 0.34);
      final hasta = centroGajo - Offset(math.cos(a), math.sin(a)) * (r * 0.30);
      canvas.drawLine(desde, hasta, costura);
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.38, -r * 0.42),
        width: r * 0.55,
        height: r * 0.34,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    canvas.drawCircle(
      c,
      r - 0.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = negro.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant BalonPainter oldDelegate) => false;
}

/// Portería con perspectiva y red; `impacto` (0-1) infla la red hacia atrás
/// cuando el balón entra.
class PorteriaPainter extends CustomPainter {
  final Color color;
  final double impacto;

  const PorteriaPainter({required this.color, required this.impacto});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final postes = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = color.withValues(alpha: 0.55);

    final tl = Offset(w * 0.08, h * 0.12);
    final tr = Offset(w * 0.92, h * 0.12);
    final bl = Offset(w * 0.02, h * 0.98);
    final br = Offset(w * 0.98, h * 0.98);
    final push = impacto * h * 0.14;
    final btl = Offset(w * 0.24, h * 0.34 + push * 0.4);
    final btr = Offset(w * 0.76, h * 0.34 + push * 0.4);
    final bbl = Offset(w * 0.20 - push * 0.3, h * 0.98);
    final bbr = Offset(w * 0.80 + push * 0.3, h * 0.98);

    for (var i = 0; i <= 3; i++) {
      final t = i / 3;
      final arriba = Offset.lerp(btl, btr, t)!;
      final abajo = Offset.lerp(bbl, bbr, t)!;
      final medio = Offset.lerp(arriba, abajo, 0.5)! + Offset(0, push * 0.8);
      canvas.drawPath(
        Path()
          ..moveTo(arriba.dx, arriba.dy)
          ..quadraticBezierTo(medio.dx, medio.dy, abajo.dx, abajo.dy),
        red,
      );
    }
    for (var i = 1; i <= 3; i++) {
      final t = i / 4;
      final izq = Offset.lerp(btl, bbl, t)!;
      final der = Offset.lerp(btr, bbr, t)!;
      final medio = Offset.lerp(izq, der, 0.5)! + Offset(0, push);
      canvas.drawPath(
        Path()
          ..moveTo(izq.dx, izq.dy)
          ..quadraticBezierTo(medio.dx, medio.dy, der.dx, der.dy),
        red,
      );
    }
    canvas.drawLine(tl, btl, red);
    canvas.drawLine(tr, btr, red);
    canvas.drawLine(bl, bbl, red);
    canvas.drawLine(br, bbr, red);

    canvas.drawPath(
      Path()
        ..moveTo(bl.dx, bl.dy)
        ..lineTo(tl.dx, tl.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(br.dx, br.dy),
      postes,
    );
  }

  @override
  bool shouldRepaint(covariant PorteriaPainter old) =>
      old.impacto != impacto || old.color != color;
}

/// Campana (o portería en gol) para usarse como destino de la animación —
/// compartida entre la campana real y el demo.
class CampanaDestino extends StatelessWidget {
  final AnimacionCampana variante;
  final bool animando;
  final double v; // valor actual del controller (para la red de la portería)
  final Color color;

  const CampanaDestino({
    super.key,
    required this.variante,
    required this.animando,
    required this.v,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (animando && variante == AnimacionCampana.gol) {
      final q = ((v - kInicioGolAnimacion) / (1 - kInicioGolAnimacion)).clamp(
        0.0,
        1.0,
      );
      final impacto = math.sin(math.pi * q) * (1 - 0.35 * q);
      return CustomPaint(
        size: const Size(28, 24),
        painter: PorteriaPainter(color: color, impacto: impacto),
      );
    }
    return Icon(Icons.notifications_outlined, color: color);
  }
}
