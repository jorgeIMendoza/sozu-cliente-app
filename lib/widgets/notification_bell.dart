import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/data_providers.dart';

/// Campana de notificaciones con contador de no leídas.
///
/// Al llegar notificaciones nuevas (sube el conteo): un balón ⚽ aparece al
/// centro, viaja botando con física natural (parábolas decrecientes, squash
/// al impacto, giro) hacia la campana — que durante el vuelo se convierte en
/// una portería con red — y al entrar el balón la red se infla (¡gol!),
/// vuelve la campana y el badge sube con un pop.
/// Bajadas del conteo (marcar leídas) se reflejan sin animación.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vuelo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  OverlayEntry? _balon;

  /// Conteo que se muestra (puede ir "atrasado" mientras vuela el balón).
  int? _mostradas;
  bool _pop = false;
  bool _volando = false; // mientras vuela, la campana es portería

  // Línea de tiempo: aparición → botes → entrada a la red.
  static const _fase1 = 0.16; // balón aparece al centro
  static const _inicioGol = 0.86; // desde aquí el balón "entra" y la red ondea

  @override
  void initState() {
    super.initState();
    _vuelo.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _quitarBalon();
      _vuelo.reset();
      if (!mounted) return;
      // ¡Gol!: mostrar el conteo real con un pop y volver a la campana.
      setState(() {
        _mostradas =
            ref.read(clienteNotificacionesProvider).valueOrNull?.noLeidas ??
            _mostradas;
        _pop = true;
        _volando = false;
      });
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) setState(() => _pop = false);
      });
    });
  }

  @override
  void dispose() {
    _quitarBalon();
    _vuelo.dispose();
    super.dispose();
  }

  void _quitarBalon() {
    _balon?.remove();
    _balon = null;
  }

  void _animarLlegada() {
    if (_vuelo.isAnimating) return; // al anotar tomará el conteo más nuevo
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.attached) {
      setState(() {
        _mostradas =
            ref.read(clienteNotificacionesProvider).valueOrNull?.noLeidas ??
            _mostradas;
      });
      return;
    }
    final destino = box.localToGlobal(box.size.center(Offset.zero));
    final pantalla = MediaQuery.of(context).size;
    final centro = Offset(pantalla.width / 2, pantalla.height * 0.42);

    _quitarBalon();
    setState(() => _volando = true); // campana → portería
    _balon = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _vuelo,
          builder: (_, __) {
            final v = _vuelo.value;
            Offset pos;
            double opacity;
            double angulo;
            double sx = 1, sy = 1; // squash & stretch

            if (v < _fase1) {
              final k = Curves.easeOutBack.transform(v / _fase1);
              pos = centro;
              sx = sy = 0.3 + 0.7 * k;
              opacity = (v / (_fase1 * 0.5)).clamp(0.0, 1.0);
              angulo = 0;
            } else {
              final k = (v - _fase1) / (1 - _fase1); // 0..1 del viaje
              // Botes con física natural: 3 parábolas de altura y duración
              // decrecientes + tramo final de entrada a la red.
              const tramos = [0.36, 0.25, 0.17, 0.22]; // fracciones del viaje
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

              // Avance horizontal constante (se siente natural) y línea de
              // "suelo" que baja/sube suavemente hacia la portería.
              final baseX = centro.dx + (destino.dx - centro.dx) * k;
              final baseY = centro.dy + (destino.dy - centro.dy) * k;

              if (i < 3) {
                final alto = 4 * alturas[i] * s * (1 - s); // parábola
                pos = Offset(baseX, baseY - alto);
                // Squash al impactar el "suelo", estirado en el aire.
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
                // Entrada a la red: pequeño salto y se hunde en la portería.
                final e = Curves.easeIn.transform(s);
                pos = Offset(baseX, baseY - 14 * math.sin(math.pi * s));
                final enc = 1 - 0.65 * e; // se encoge al entrar
                sx = enc;
                sy = enc;
                opacity = s > 0.55 ? ((1 - s) / 0.45).clamp(0.0, 1.0) : 1.0;
              }
              angulo = 5.5 * math.pi * Curves.easeOut.transform(k); // rodando
            }

            const tam = 44.0;
            // Transform.translate (no Positioned): dentro del Overlay el
            // ParentData de Positioned no llega al Stack si hay widgets
            // intermedios.
            return Align(
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: pos - const Offset(tam / 2, tam / 2),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: angulo,
                    child: Transform.scale(
                      scaleX: sx,
                      scaleY: sy,
                      child: const SizedBox(
                        width: tam,
                        height: tam,
                        child: CustomPaint(painter: _BalonPainter()),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    overlay.insert(_balon!);
    _vuelo.forward();
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);

    ref.listen(clienteNotificacionesProvider, (prev, next) {
      final nuevo = next.valueOrNull?.noLeidas;
      if (nuevo == null || !mounted) return;
      final actual = _mostradas;
      // Solo anima la campana visible (las tabs ocultas del shell quedan
      // en Offstage con tickers apagados).
      if (actual != null &&
          nuevo > actual &&
          TickerMode.valuesOf(context).enabled) {
        _animarLlegada(); // llegada: balón primero, número después
      } else if (nuevo != actual && !_vuelo.isAnimating) {
        setState(() => _mostradas = nuevo); // bajadas o primer valor: directo
      }
    });

    _mostradas ??=
        ref.watch(clienteNotificacionesProvider).valueOrNull?.noLeidas ?? 0;
    final noLeidas = _mostradas ?? 0;

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => context.push('/notificaciones'),
      icon: AnimatedScale(
        scale: _pop ? 1.3 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Badge.count(
          count: noLeidas,
          isLabelVisible: noLeidas > 0,
          backgroundColor: tone.negative,
          textColor: Colors.white,
          // Mientras el balón vuela, la campana es una portería cuya red
          // se infla cuando el balón entra (¡gol!).
          child: _volando
              ? AnimatedBuilder(
                  animation: _vuelo,
                  builder: (_, __) {
                    final q = ((_vuelo.value - _inicioGol) / (1 - _inicioGol))
                        .clamp(0.0, 1.0);
                    // Pulso amortiguado de la red al recibir el balón.
                    final impacto =
                        math.sin(math.pi * q) * (1 - 0.35 * q);
                    return CustomPaint(
                      size: const Size(28, 24),
                      painter: _PorteriaPainter(
                        color: tone.textSecondary,
                        impacto: impacto,
                      ),
                    );
                  },
                )
              : Icon(Icons.notifications_outlined, color: tone.textSecondary),
        ),
      ),
    );
  }
}

/// Balón clásico estilizado: base con degradado, pentágono central, gajos
/// perimetrales, costuras y brillo especular. Legible a 40-50 px.
class _BalonPainter extends CustomPainter {
  const _BalonPainter();

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

    // Sombra suave.
    canvas.drawCircle(
      c + Offset(0, r * 0.10),
      r * 0.96,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Base con degradado (luz arriba-izquierda).
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

    // Pentágono central.
    final rotC = -math.pi / 2;
    canvas.drawPath(_pentagono(c, r * 0.34, rotC), Paint()..color = negro);

    // Gajos perimetrales (recortados por el círculo) + costuras radiales.
    for (var i = 0; i < 5; i++) {
      final a = rotC + math.pi / 5 + i * 2 * math.pi / 5;
      final centroGajo = c + Offset(math.cos(a), math.sin(a)) * (r * 0.92);
      canvas.drawPath(
        _pentagono(centroGajo, r * 0.34, a),
        Paint()..color = negro,
      );
      // Costura del vértice del pentágono central hacia el gajo.
      final desde = c + Offset(math.cos(a), math.sin(a)) * (r * 0.34);
      final hasta = centroGajo - Offset(math.cos(a), math.sin(a)) * (r * 0.30);
      canvas.drawLine(desde, hasta, costura);
    }

    // Brillo especular.
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

    // Contorno.
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
  bool shouldRepaint(covariant _BalonPainter oldDelegate) => false;
}

/// Portería con perspectiva y red; `impacto` (0-1) infla la red hacia atrás
/// cuando el balón entra.
class _PorteriaPainter extends CustomPainter {
  final Color color;
  final double impacto;

  const _PorteriaPainter({required this.color, required this.impacto});

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

    // Marco frontal (postes + travesaño) con base más ancha.
    final tl = Offset(w * 0.08, h * 0.12);
    final tr = Offset(w * 0.92, h * 0.12);
    final bl = Offset(w * 0.02, h * 0.98);
    final br = Offset(w * 0.98, h * 0.98);
    // Fondo de la red (perspectiva) — se empuja hacia atrás con el impacto.
    final push = impacto * h * 0.14;
    final btl = Offset(w * 0.24, h * 0.34 + push * 0.4);
    final btr = Offset(w * 0.76, h * 0.34 + push * 0.4);
    final bbl = Offset(w * 0.20 - push * 0.3, h * 0.98);
    final bbr = Offset(w * 0.80 + push * 0.3, h * 0.98);

    // Red: verticales y horizontales del plano trasero (con leve comba).
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
    // Laterales de la red (unión marco frontal ↔ plano trasero).
    canvas.drawLine(tl, btl, red);
    canvas.drawLine(tr, btr, red);
    canvas.drawLine(bl, bbl, red);
    canvas.drawLine(br, bbr, red);

    // Marco frontal al último (encima de la red).
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
  bool shouldRepaint(covariant _PorteriaPainter old) =>
      old.impacto != impacto || old.color != color;
}
