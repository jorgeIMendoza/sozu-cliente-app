import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';

/// Cierra la sesión automáticamente tras un rato sin actividad del usuario
/// (toques, scroll, movimiento del puntero). Envuelve toda la app; solo actúa
/// cuando hay sesión iniciada.
///
/// El plazo depende del dispositivo, no del capricho: ver [kPhoneInactivityTimeout] y
/// [kDesktopInactivityTimeout].
class InactivityWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const InactivityWatcher({super.key, required this.child});

  @override
  ConsumerState<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends ConsumerState<InactivityWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;

  /// Última actividad real del usuario. El Timer solo cubre la app en primer
  /// plano: en móvil el OS congela el isolate en background y el timer no
  /// dispara (en web la pestaña sigue viva). Al volver (resumed) se compara
  /// contra este timestamp para cerrar sesión si ya venció.
  DateTime? _lastActivity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Plazo de inactividad vigente.
  ///
  /// Un teléfono se guarda en el bolsillo y se pierde: plazo corto. Un
  /// escritorio está en un espacio controlado y cortar la sesión cada 5 minutos
  /// hace que el usuario tenga que reautenticarse a media tarea, que es la vía
  /// rápida a que alguien apunte la contraseña en un post-it.
  ///
  /// El criterio es el FORMATO, no la plataforma: web abierta en el navegador
  /// del celular debe usar el plazo corto, y para eso se mide el lado menor de
  /// la pantalla en vez de confiar en `kIsWeb`.
  Duration get _currentTimeout {
    final isPhone = kIsWeb
        ? MediaQuery.sizeOf(context).shortestSide < 600
        : (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
    return isPhone ? kPhoneInactivityTimeout : kDesktopInactivityTimeout;
  }

  /// Sesión "usable": con el candado biométrico puesto la sesión de Supabase
  /// sigue viva pero la app ya está bloqueada - no hay nada que vigilar.
  bool get _hasUsableSession {
    final auth = ref.read(authProvider);
    return auth.session != null && !auth.locked;
  }

  void _reset() {
    _timer?.cancel();
    if (!_hasUsableSession) return;
    _lastActivity = DateTime.now();
    _timer = Timer(_currentTimeout, _logout);
  }

  Future<void> _logout() async {
    final auth = ref.read(authProvider);
    if (!_hasUsableSession) return;
    _timer?.cancel();
    ref.read(inactivityLogoutProvider.notifier).state = true;
    // Con biometría habilitada solo bloquea (la sesión sigue viva para
    // re-entrar con huella); sin biometría cierra sesión de verdad.
    await auth.lockOrSignOut();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final lastActivity = _lastActivity;
    if (lastActivity == null || !_hasUsableSession) return;
    final elapsed = DateTime.now().difference(lastActivity);
    if (elapsed >= _currentTimeout) {
      _logout();
    } else {
      // Re-arma solo con el tiempo restante; el timer congelado en background
      // habría disparado tarde.
      _timer?.cancel();
      _timer = Timer(_currentTimeout - elapsed, _logout);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-arma o cancela el timer cuando cambia el estado de sesión/candado.
    final hasSession = ref.watch(
      authProvider.select((a) => a.session != null && !a.locked),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hasSession) {
        if (_timer == null || !_timer!.isActive) _reset();
      } else {
        _timer?.cancel();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      onPointerMove: (_) => _reset(),
      onPointerSignal: (_) => _reset(),
      child: widget.child,
    );
  }
}

/// Plazo de inactividad en teléfono (y web en pantalla de teléfono).
const Duration kPhoneInactivityTimeout = Duration(minutes: 5);

/// Plazo de inactividad en escritorio (y web en pantalla grande).
const Duration kDesktopInactivityTimeout = Duration(minutes: 15);
