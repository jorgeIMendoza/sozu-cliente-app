import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import 'animacion_llegada.dart';

/// GlobalKey del destino de notificaciones en la barra inferior flotante
/// (móvil): apunta al ítem "Notificaciones" cuando es una pestaña visible, o
/// al botón "Más" (…) cuando "Notificaciones" vive dentro del overflow. El
/// [NotificacionesFx] la usa para saber hacia dónde volar cuando no hay una
/// campana visible en la pantalla actual.
final GlobalKey notifNavKey = GlobalKey(debugLabel: 'notif-nav-destino');

/// Registro global de campanas de notificaciones montadas. Permite que el
/// controlador global ([NotificacionesFx]) sepa si en la pantalla actual hay
/// una campana visible que ya corre la animación de llegada por su cuenta
/// (Inicio, pestañas con AppBar, topbar del portal) y así no duplicarla.
class NotifFx {
  NotifFx._();
  static final NotifFx instance = NotifFx._();

  final Map<State, bool> _campanas = {};

  /// La campana [s] reporta si está visible (pestaña activa / topbar), lo que
  /// implica que ella misma anima la llegada.
  void reportarCampana(State s, {required bool visible}) =>
      _campanas[s] = visible;

  void quitarCampana(State s) => _campanas.remove(s);

  /// true si alguna campana montada está visible en la pantalla actual.
  bool hayCampanaVisible() =>
      _campanas.entries.any((e) => e.value && e.key.mounted);

  /// Centro global del destino de notificaciones del bottom nav (ítem
  /// "Notificaciones" o botón "Más"); si no existe, cae a la esquina superior
  /// derecha (donde suele estar la campana).
  Offset destinoNav(Size pantalla, double topInset) {
    final ctx = notifNavKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box != null && box.attached) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    return Offset(pantalla.width - 36, topInset + 28);
  }
}

/// Controlador global de la animación de "llegada" de notificaciones. Siempre
/// montado bajo el ShellRoute del cliente (todas las pantallas, en móvil,
/// portal y escritorio), observa [clienteNotificacionesProvider] una sola vez
/// a nivel app —sin depender del TickerMode de una campana en una pestaña
/// offstage— y, al subir el contador de no leídas, lanza el proyectil en el
/// rootOverlay hacia el destino de notificaciones visible en la pantalla.
///
/// Reparto de responsabilidades para no duplicar la animación:
/// - Si hay una campana visible (Inicio, pestañas con AppBar, topbar del
///   portal), ella misma corre la animación (comportamiento conservado) y este
///   controlador NO dispara.
/// - Si no hay campana visible (pantallas secundarias / pestañas sin campana),
///   este controlador vuela hacia el ítem "Notificaciones"/"Más" del bottom
///   nav, o a la esquina superior derecha como último recurso.
class NotificacionesFx extends ConsumerStatefulWidget {
  final Widget child;

  const NotificacionesFx({super.key, required this.child});

  @override
  ConsumerState<NotificacionesFx> createState() => _NotificacionesFxState();
}

class _NotificacionesFxState extends ConsumerState<NotificacionesFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vuelo = AnimationController(
    vsync: this,
    duration: kDuracionAnimacion,
  );
  OverlayEntry? _proyectil;

  /// Último conteo observado (para detectar incrementos).
  int? _mostradas;
  AnimacionCampana _variante = AnimacionCampana.gol;

  @override
  void initState() {
    super.initState();
    _vuelo.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _quitarProyectil();
      _vuelo.reset();
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
    if (_vuelo.isAnimating) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.attached) return;

    final pantalla = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final destino = NotifFx.instance.destinoNav(pantalla, topInset);
    final centro = Offset(pantalla.width / 2, pantalla.height * 0.42);
    _variante = AnimacionCampana.desde(
      ref.read(clienteNotificacionesProvider).valueOrNull?.animacionCampana,
    );

    _quitarProyectil();
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
    _vuelo.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clienteNotificacionesProvider, (prev, next) {
      final nuevo = next.valueOrNull?.noLeidas;
      if (nuevo == null || !mounted) return;
      final actual = _mostradas;
      _mostradas = nuevo;
      // Solo dispara si sube el contador y ninguna campana visible lo hará ya
      // (en Inicio / pestañas con AppBar / topbar del portal anima la campana).
      if (actual != null &&
          nuevo > actual &&
          !NotifFx.instance.hayCampanaVisible()) {
        _animarLlegada();
      }
    });
    _mostradas ??=
        ref.watch(clienteNotificacionesProvider).valueOrNull?.noLeidas;
    return widget.child;
  }
}
