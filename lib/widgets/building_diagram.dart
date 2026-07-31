import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/widgets/level_map.dart';

/// Diagrama "¿Dónde está tu unidad?" - réplica del BuildingDiagram del Portal
/// del Cliente (FichaTecnicaSection.tsx de sozu-admin).
///
/// Dos columnas:
///  - Izquierda "NIVEL EN EL EDIFICIO": lista vertical de niveles (del más alto
///    hacia abajo, PLANTA BAJA en oscuro al fondo) con el nivel del cliente
///    resaltado en verde "respirando", un hueco de elevador a un costado y una
///    animación de elevador que sube desde PLANTA BAJA hasta ese nivel.
///  - Derecha "UBICACIÓN EN EL NIVEL": la planta del nivel ([LevelMap], que
///    respira) horizontal y compacta cuando hay `regiones`; si no, una rejilla
///    de números como fallback.
class BuildingDiagram extends StatelessWidget {
  final int numeroPiso;
  final int? totalPisos;

  /// Identificador de la unidad tal cual viene en la ficha (p.ej. "707").
  final String unidad;

  /// Regiones (polígonos) de la planta del nivel; si están vacías se usa la
  /// rejilla de números como fallback.
  final List<RegionNivel> regiones;

  /// Número de departamento para resaltar la unidad en la planta.
  final String? numeroDepa;

  const BuildingDiagram({
    super.key,
    required this.numeroPiso,
    this.totalPisos,
    required this.unidad,
    this.regiones = const [],
    this.numeroDepa,
  });

  // ── Niveles a mostrar (descendente), ventana compacta centrada en el piso ──
  List<int> _niveles() {
    final total =
        (totalPisos != null && totalPisos! >= numeroPiso && totalPisos! > 0)
        ? totalPisos!
        : numeroPiso;
    const maxVisible = 8;
    late int top;
    late int bottom;
    if (total <= maxVisible) {
      top = total;
      bottom = 1;
    } else {
      // Ventana de `maxVisible` niveles que siempre contiene el del cliente.
      top = (numeroPiso + 3).clamp(maxVisible, total);
      bottom = (top - maxVisible + 1).clamp(1, total);
    }
    return [for (int f = top; f >= bottom; f--) f];
  }

  /// Posición de la unidad dentro del piso a partir de su número.
  /// Convención `piso*100 + posición` (707 → piso 7, posición 7); si no aplica,
  /// se usan los últimos dos dígitos.
  int _posicionEnPiso() {
    final digits = int.tryParse(unidad.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits == null) return 1;
    final byFloor = digits - numeroPiso * 100;
    if (byFloor >= 1 && byFloor <= 40) return byFloor;
    final last2 = digits % 100;
    return last2 >= 1 ? last2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final niveles = _niveles();
    final total =
        (totalPisos != null && totalPisos! >= numeroPiso && totalPisos! > 0)
        ? totalPisos!
        : numeroPiso;
    final hayPlanta = regiones.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿DÓNDE ESTÁ TU UNIDAD?',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: tone.fgSubtle,
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda - niveles del edificio.
              Expanded(
                child: _Columna(
                  label: 'NIVEL EN EL EDIFICIO',
                  tone: tone,
                  child: _ListaNiveles(
                    niveles: niveles,
                    total: total,
                    numeroPiso: numeroPiso,
                    tone: tone,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Columna derecha - planta del nivel (LevelMap) o rejilla.
              Expanded(
                child: _Columna(
                  label: 'UBICACIÓN EN EL NIVEL',
                  tone: tone,
                  child: hayPlanta
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LevelMap(
                              regiones: regiones,
                              numeroDepa: numeroDepa,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Planta del nivel · tu unidad resaltada',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: tone.fgSubtle,
                              ),
                            ),
                          ],
                        )
                      : _RejillaUnidades(
                          numeroPiso: numeroPiso,
                          unidad: unidad,
                          posicion: _posicionEnPiso(),
                          tone: tone,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tone.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Tu unidad',
              style: TextStyle(fontSize: 11, color: tone.fgMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _Columna extends StatelessWidget {
  final String label;
  final SozuColorRoles tone;
  final Widget child;

  const _Columna({
    required this.label,
    required this.tone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: tone.fgSubtle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tone.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

// Alturas fijas del corte del edificio (deben ser coherentes entre las losas y
// el ducto del elevador para que el carro se alinee con cada nivel).
const double _kRoofH = 20; // azotea / techo en corte
const double _kRowH = 26; // alto de cada losa/nivel
const double _kRowGap = 5; // junta (separación) entre losas
const double _kBaseGap = 3; // separación antes de la base/terreno
const double _kBaseH = 9; // base/terreno del edificio
const double _kWallW = 6; // grosor de los muros exteriores en corte
const double _kShaftW = 20; // ancho del ducto/hueco del elevador

class _ListaNiveles extends StatefulWidget {
  final List<int> niveles;
  final int total;
  final int numeroPiso;
  final SozuColorRoles tone;

  const _ListaNiveles({
    required this.niveles,
    required this.total,
    required this.numeroPiso,
    required this.tone,
  });

  @override
  State<_ListaNiveles> createState() => _ListaNivelesState();
}

class _ListaNivelesState extends State<_ListaNiveles>
    with SingleTickerProviderStateMixin {
  // Dueño de la animación del elevador: sube LENTO (~3.2s, easeInOut) UNA sola
  // vez al aparecer la pestaña. Al completar (`AnimationStatus.completed`) se
  // marca `_llego`, lo que dispara el verde + respiración del nivel del cliente.
  late final AnimationController _elev = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _elev,
    curve: Curves.easeInOut,
  );
  bool _llego = false;

  @override
  void initState() {
    super.initState();
    _elev.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_llego) {
        setState(() => _llego = true);
      }
    });
    // Se reproduce solo al aparecer (primera construcción).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _elev.forward();
    });
  }

  @override
  void dispose() {
    _elev.dispose();
    super.dispose();
  }

  // Centro (px) de la losa de índice `i` (0 = nivel más alto), según constantes.
  double _rowCenter(int i) => i * (_kRowH + _kRowGap) + _kRowH / 2;

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final niveles = widget.niveles;
    final k = niveles.indexOf(widget.numeroPiso);

    // Alto del cuerpo (entre los muros): losas + juntas + PLANTA BAJA (sin junta
    // final). Con altura fija evitamos LayoutBuilder y el carro se alinea exacto.
    final bodyH = niveles.length * (_kRowH + _kRowGap) + _kRowH;
    final plantaCenter = _rowCenter(niveles.length);
    final clientCenter = k >= 0 ? _rowCenter(k) : plantaCenter;
    final startFrac = plantaCenter / bodyH;
    final endFrac = clientCenter / bodyH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Azotea en corte (losa superior con pretil), cubre todo el ancho.
        CustomPaint(
          size: const Size(double.infinity, _kRoofH),
          painter: _RoofPainter(tone),
        ),
        // Cuerpo: muro | ducto de elevador | losas apiladas | muro.
        Row(
          children: [
            _Muro(tone: tone, alto: bodyH),
            _Ducto(
              anim: _anim,
              startFrac: startFrac,
              endFrac: endFrac,
              alto: bodyH,
              tone: tone,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final n in niveles) ...[
                    _FilaNivel(
                      texto: 'NIVEL $n',
                      esCliente: n == widget.numeroPiso,
                      activo: _llego,
                      oscuro: false,
                      tone: tone,
                    ),
                    const SizedBox(height: _kRowGap),
                  ],
                  _FilaNivel(
                    texto: 'PLANTA BAJA',
                    esCliente: false,
                    activo: false,
                    oscuro: true,
                    tone: tone,
                  ),
                ],
              ),
            ),
            _Muro(tone: tone, alto: bodyH),
          ],
        ),
        const SizedBox(height: _kBaseGap),
        // Base / terreno del edificio.
        CustomPaint(
          size: const Size(double.infinity, _kBaseH),
          painter: _BasePainter(tone),
        ),
      ],
    );
  }
}

/// Muro exterior del edificio en corte (fachada lateral): barra vertical delgada
/// con un ligero gradiente para dar sensación de grosor de muro.
class _Muro extends StatelessWidget {
  final SozuColorRoles tone;
  final double alto;

  const _Muro({required this.tone, required this.alto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kWallW,
      height: alto,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [tone.surfaceAlt, tone.border],
        ),
        border: Border.all(color: tone.border, width: 0.8),
      ),
    );
  }
}

/// Ducto (hueco) del elevador en corte: canal vertical recesado con rieles y un
/// carro que sube LENTO desde PLANTA BAJA hasta el nivel del cliente.
/// La altura es fija (`alto`) para alinear el carro con cada losa sin
/// LayoutBuilder.
class _Ducto extends StatelessWidget {
  final Animation<double> anim;
  final double startFrac;
  final double endFrac;
  final double alto;
  final SozuColorRoles tone;

  const _Ducto({
    required this.anim,
    required this.startFrac,
    required this.endFrac,
    required this.alto,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    const carH = 20.0;
    return SizedBox(
      width: _kShaftW,
      height: alto,
      child: Stack(
        children: [
          // Canal recesado (más oscuro que la fachada).
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [tone.border, tone.surfaceAlt, tone.border],
                ),
                border: Border.all(color: tone.border),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Rieles del ducto.
          Positioned.fill(child: CustomPaint(painter: _RielesPainter(tone))),
          // Carro del elevador.
          AnimatedBuilder(
            animation: anim,
            builder: (context, _) {
              final frac = startFrac + (endFrac - startFrac) * anim.value;
              final top = (frac * alto - carH / 2).clamp(0.0, alto - carH);
              return Positioned(
                top: top,
                left: 0,
                right: 0,
                child: _ElevatorCar(tone: tone, height: carH),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Carro del elevador: cabina con cable arriba y línea de puertas.
class _ElevatorCar extends StatelessWidget {
  final SozuColorRoles tone;
  final double height;

  const _ElevatorCar({required this.tone, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cable de suspensión.
          Container(
            width: 1.5,
            height: 5,
            color: tone.fgMuted.withValues(alpha: 0.7),
          ),
          // Cabina.
          Container(
            width: 13,
            height: height - 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tone.primary, tone.primaryHover],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: tone.primary.withValues(alpha: 0.45),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            // Línea de puertas.
            child: Center(
              child: Container(
                width: 1.2,
                height: (height - 5) * 0.55,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Losa / nivel del corte. Antes de que llegue el elevador, el nivel del cliente
/// está NEUTRO (mismo fondo que los demás, solo un borde sutil). Al LLEGAR el
/// elevador (`activo == true`, disparado por el `completed` del controlador)
/// pasa a verde y "respira" (pulso de glow + escala, repeat reverse) y aparece
/// la flecha "Tú".
class _FilaNivel extends StatefulWidget {
  final String texto;
  final bool esCliente; // es el nivel del cliente
  final bool activo; // el elevador ya llegó (habilita verde + respiración)
  final bool oscuro; // PLANTA BAJA
  final SozuColorRoles tone;

  const _FilaNivel({
    required this.texto,
    required this.esCliente,
    required this.activo,
    required this.oscuro,
    required this.tone,
  });

  @override
  State<_FilaNivel> createState() => _FilaNivelState();
}

class _FilaNivelState extends State<_FilaNivel>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  // Verde + respiración solo cuando es el nivel del cliente Y el elevador llegó.
  bool get _verde => widget.esCliente && widget.activo;

  @override
  void initState() {
    super.initState();
    if (_verde) _initBreathing();
  }

  void _initBreathing() {
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _FilaNivel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Arranca la respiración justo cuando el elevador llega (activo -> true).
    if (_verde && _c == null) {
      _initBreathing();
    } else if (!_verde && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final verde = _verde;

    final Color fondo = widget.oscuro ? tone.fg : tone.surfaceAlt;
    final Color texColor = verde
        ? Colors.white
        : widget.oscuro
        ? tone.surface
        : tone.fgMuted;

    final Gradient? gradient = verde
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tone.primary, tone.primaryHover],
          )
        : widget.oscuro
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tone.fg, tone.primaryHover],
          )
        : null;

    // Borde: verde marcado / cliente-en-espera (neutro con borde sutil) / normal.
    final Color borde = verde
        ? tone.primary
        : (widget.esCliente
              ? tone.primary.withValues(alpha: 0.45)
              : tone.border);

    // Ventanas (textura de fachada) tenues; ocultas en el nivel verde.
    final Color? ventanas = verde
        ? null
        : widget.oscuro
        ? tone.surface.withValues(alpha: 0.16)
        : tone.fgMuted.withValues(alpha: 0.10);

    Widget fila(double t) {
      final scale = verde ? 1 + 0.02 * t : 1.0;
      return Transform.scale(
        scale: scale,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: _kRowH,
                decoration: BoxDecoration(
                  color: gradient == null ? fondo : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: borde),
                  boxShadow: verde
                      ? [
                          BoxShadow(
                            color: tone.primary.withValues(
                              alpha: 0.25 + 0.35 * t,
                            ),
                            blurRadius: 6 + 10 * t,
                            spreadRadius: 0.5 * t,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (ventanas != null)
                      Positioned.fill(
                        child: CustomPaint(painter: _VentanasPainter(ventanas)),
                      ),
                    Text(
                      widget.texto,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: texColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Espacio reservado para la flecha "◄ Tú" (alinea las filas). Solo
            // aparece cuando el elevador llegó al nivel del cliente.
            SizedBox(
              width: 30,
              child: verde
                  ? Row(
                      children: [
                        const SizedBox(width: 3),
                        Icon(Icons.play_arrow, size: 12, color: tone.primary),
                        Text(
                          'Tú',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tone.primary,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    if (_c == null) return fila(0);
    return AnimatedBuilder(
      animation: _c!,
      builder: (context, _) => fila(Curves.easeInOut.transform(_c!.value)),
    );
  }
}

/// Rejilla de unidades del nivel (fallback cuando el edificio no tiene `regiones`
/// de plano en la BD). La celda de tu unidad "respira" igual que la planta, para
/// que "UBICACIÓN EN EL NIVEL" luzca viva aun sin plano cargado.
class _RejillaUnidades extends StatefulWidget {
  final int numeroPiso;
  final String unidad;
  final int posicion;
  final SozuColorRoles tone;

  const _RejillaUnidades({
    required this.numeroPiso,
    required this.unidad,
    required this.posicion,
    required this.tone,
  });

  @override
  State<_RejillaUnidades> createState() => _RejillaUnidadesState();
}

class _RejillaUnidadesState extends State<_RejillaUnidades>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    // Respira desde que aparece (misma cadencia que la planta / el nivel).
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cols = 4;
    final filas = math.max(2, (widget.posicion / cols).ceil());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < filas; r++) ...[
          Row(
            children: [
              for (int c = 0; c < cols; c++) ...[
                Expanded(child: _celda(r * cols + c + 1)),
                if (c < cols - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (r < filas - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _celda(int i) {
    final tone = widget.tone;
    final resaltado = i == widget.posicion;
    final etiqueta = resaltado
        ? widget.unidad
        : '${widget.numeroPiso * 100 + i}';

    Widget celda(double t) {
      return AspectRatio(
        aspectRatio: 1.35,
        child: Transform.scale(
          scale: resaltado ? 1 + 0.05 * t : 1.0,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: resaltado
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(tone.primaryHover, tone.primary, t) ??
                            tone.primary,
                        tone.primary,
                      ],
                    )
                  : null,
              color: resaltado ? null : tone.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: resaltado ? tone.primary : tone.border),
              boxShadow: resaltado
                  ? [
                      BoxShadow(
                        color: tone.primary.withValues(alpha: 0.30 + 0.40 * t),
                        blurRadius: 6 + 14 * t,
                        spreadRadius: 0.5 + 1.5 * t,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: resaltado ? tone.onPrimary : tone.fgMuted,
              ),
            ),
          ),
        ),
      );
    }

    if (!resaltado) return celda(0);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => celda(Curves.easeInOut.transform(_c.value)),
    );
  }
}

/// Azotea del edificio en corte: losa superior oscura con pretil (cap) y una
/// pequeña estructura de azotea (cuarto de máquinas) centrada.
class _RoofPainter extends CustomPainter {
  final SozuColorRoles tone;

  _RoofPainter(this.tone);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const m = 2.0;

    // Losa de azotea.
    final slab = Paint()..color = tone.fg;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        m,
        h * 0.35,
        w - m,
        h,
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      ),
      slab,
    );

    // Pretil (cap) más claro sobre la losa.
    final cap = Paint()..color = tone.fgMuted;
    canvas.drawRRect(
      RRect.fromLTRBR(
        m,
        h * 0.35 - 3,
        w - m,
        h * 0.35 + 1,
        const Radius.circular(1),
      ),
      cap,
    );

    // Cuarto de máquinas / estructura de azotea.
    final mr = Paint()..color = tone.primaryHover;
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.05, w * 0.16, h * 0.32), mr);
  }

  @override
  bool shouldRepaint(covariant _RoofPainter oldDelegate) =>
      oldDelegate.tone != tone;
}

/// Base / terreno del edificio (barra oscura con línea de piso más clara).
class _BasePainter extends CustomPainter {
  final SozuColorRoles tone;

  _BasePainter(this.tone);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = Paint()..color = tone.fg;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        0,
        0,
        w,
        h,
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      ground,
    );
    final line = Paint()..color = tone.fgMuted;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 1.5), line);
  }

  @override
  bool shouldRepaint(covariant _BasePainter oldDelegate) =>
      oldDelegate.tone != tone;
}

/// Rieles del ducto del elevador: dos guías verticales con travesaños tenues.
class _RielesPainter extends CustomPainter {
  final SozuColorRoles tone;

  _RielesPainter(this.tone);

  @override
  void paint(Canvas canvas, Size size) {
    final x1 = size.width * 0.30;
    final x2 = size.width * 0.70;
    final rail = Paint()
      ..color = tone.fgMuted.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x1, 2), Offset(x1, size.height - 2), rail);
    canvas.drawLine(Offset(x2, 2), Offset(x2, size.height - 2), rail);

    final rung = Paint()
      ..color = tone.fgMuted.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (double y = 6; y < size.height - 4; y += 12) {
      canvas.drawLine(Offset(x1, y), Offset(x2, y), rung);
    }
  }

  @override
  bool shouldRepaint(covariant _RielesPainter oldDelegate) =>
      oldDelegate.tone != tone;
}

/// Textura tenue de ventanas para dar estética de fachada a cada losa.
class _VentanasPainter extends CustomPainter {
  final Color color;

  _VentanasPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const winW = 5.0;
    const winH = 8.0;
    const step = 13.0;
    final y = (size.height - winH) / 2;
    for (double x = 7; x + winW < size.width - 7; x += step) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + winW, y + winH, const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VentanasPainter oldDelegate) =>
      oldDelegate.color != color;
}
