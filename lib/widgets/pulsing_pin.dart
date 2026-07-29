import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Pin de mapa con efecto de "respiración": un círculo que crece y se
/// desvanece alrededor del pin, en loop suave (~2 s, curva easeOut).
///
/// Pensado como child de un `Marker` de flutter_map con `width`/`height` =
/// [PulsingPin.lado] y alineación por defecto (center): el pin se dibuja con
/// la punta en el centro del widget, justo sobre la coordenada, y el halo
/// pulsa alrededor de ese punto. Como flutter_map pinta los markers como
/// widgets Flutter normales (sin overlays nativos), la animación funciona
/// igual en móvil y en web.
///
/// Respeta "reducir movimiento" del sistema: si está activo, muestra un halo
/// estático en lugar del pulso.
class PulsingPin extends StatefulWidget {
  /// Lado del widget cuadrado; el Marker debe usar este mismo tamaño.
  static const double lado = 96;

  final Color color;
  final double pinSize;

  const PulsingPin({
    super.key,
    this.color = SozuBrand.green600,
    this.pinSize = 40,
  });

  @override
  State<PulsingPin> createState() => _PulsingPinState();
}

/// Periodo de un latido del halo.
///
/// No sale de `context.s.motion` y no debe: los tokens describen transiciones
/// de estado (algo pasa de A a B una vez), y esto es un loop ambiental que corre
/// mientras el mapa está en pantalla. Si colgara de un token, ajustar el peso de
/// las hojas modales cambiaría el ritmo de este pulso - dos cosas que no tienen
/// relación quedarían acopladas. Los 2 s son el ritmo de respiración en reposo,
/// que es exactamente la lectura que se busca.
const Duration _pulseCycle = Duration(milliseconds: 2000);

class _PulsingPinState extends State<PulsingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _pulseCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accesibilidad: sin loop si el sistema pide reducir movimiento.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estatico = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: PulsingPin.lado,
      height: PulsingPin.lado,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo que respira alrededor del punto (o estático si aplica).
          if (estatico)
            _halo(diametro: widget.pinSize * 0.9, alpha: 0.20)
          else
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_c.value);
                return _halo(
                  diametro:
                      widget.pinSize * 0.4 +
                      (PulsingPin.lado - widget.pinSize * 0.4) * t,
                  alpha: 0.35 * (1 - t),
                );
              },
            ),
          // Pin con la punta en el centro del widget (= la coordenada).
          Transform.translate(
            offset: Offset(0, -widget.pinSize / 2),
            child: Icon(
              Icons.location_pin,
              size: widget.pinSize,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _halo({required double diametro, required double alpha}) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: alpha),
        border: Border.all(
          color: widget.color.withValues(alpha: (alpha * 1.6).clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}
