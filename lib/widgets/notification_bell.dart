import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/data_providers.dart';
import 'animacion_llegada.dart';

/// Campana de notificaciones con contador de no leídas.
///
/// Al subir el conteo corre la animación configurada por el admin (sobre /
/// gol / cohete — ver [AnimacionCampana]); el badge muestra el número nuevo
/// hasta que la animación "aterriza", con un pop. Bajadas del conteo (marcar
/// leídas) se reflejan sin animación.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vuelo = AnimationController(
    vsync: this,
    duration: kDuracionAnimacion,
  );
  OverlayEntry? _proyectil;

  /// Conteo que se muestra (va "atrasado" mientras corre la animación).
  int? _mostradas;
  bool _pop = false;
  bool _volando = false;
  AnimacionCampana _variante = AnimacionCampana.gol;

  @override
  void initState() {
    super.initState();
    _vuelo.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _quitarProyectil();
      _vuelo.reset();
      if (!mounted) return;
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
    _quitarProyectil();
    _vuelo.dispose();
    super.dispose();
  }

  void _quitarProyectil() {
    _proyectil?.remove();
    _proyectil = null;
  }

  void _animarLlegada() {
    if (_vuelo.isAnimating) return; // al terminar tomará el conteo más nuevo
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
    _variante = AnimacionCampana.desde(
      ref.read(clienteNotificacionesProvider).valueOrNull?.animacionCampana,
    );

    _quitarProyectil();
    setState(() => _volando = true);
    _proyectil = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _vuelo,
          builder: (_, __) => frameAnimacionLlegada(
            variante: _variante,
            v: _vuelo.value,
            centro: centro,
            destino: destino,
          ),
        ),
      ),
    );
    overlay.insert(_proyectil!);
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
        _animarLlegada();
      } else if (nuevo != actual && !_vuelo.isAnimating) {
        setState(() => _mostradas = nuevo);
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
          child: AnimatedBuilder(
            animation: _vuelo,
            builder: (_, __) => CampanaDestino(
              variante: _variante,
              animando: _volando,
              v: _vuelo.value,
              color: tone.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
