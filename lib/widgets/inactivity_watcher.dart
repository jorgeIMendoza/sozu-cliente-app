import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// Cierra la sesión automáticamente tras 5 minutos sin actividad del usuario
/// (toques, scroll, movimiento del puntero). Envuelve toda la app; solo actúa
/// cuando hay sesión iniciada.
class InactivityWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const InactivityWatcher({super.key, required this.child});

  @override
  ConsumerState<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends ConsumerState<InactivityWatcher>
    with WidgetsBindingObserver {
  static const _timeout = Duration(minutes: 5);
  Timer? _timer;

  /// Última actividad real del usuario. El Timer solo cubre la app en primer
  /// plano: en móvil el OS congela el isolate en background y el timer no
  /// dispara (en web la pestaña sigue viva). Al volver (resumed) se compara
  /// contra este timestamp para cerrar sesión si ya venció.
  DateTime? _ultimaActividad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Sesión "usable": con el candado biométrico puesto la sesión de Supabase
  /// sigue viva pero la app ya está bloqueada — no hay nada que vigilar.
  bool get _activa {
    final auth = ref.read(authProvider);
    return auth.session != null && !auth.locked;
  }

  void _reset() {
    _timer?.cancel();
    if (!_activa) return;
    _ultimaActividad = DateTime.now();
    _timer = Timer(_timeout, _logout);
  }

  Future<void> _logout() async {
    final auth = ref.read(authProvider);
    if (!_activa) return;
    _timer?.cancel();
    ref.read(inactivityLogoutProvider.notifier).state = true;
    // Con biometría habilitada solo bloquea (la sesión sigue viva para
    // re-entrar con huella); sin biometría cierra sesión de verdad.
    await auth.lockOrSignOut();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final ultima = _ultimaActividad;
    if (ultima == null || !_activa) return;
    final transcurrido = DateTime.now().difference(ultima);
    if (transcurrido >= _timeout) {
      _logout();
    } else {
      // Re-arma solo con el tiempo restante; el timer congelado en background
      // habría disparado tarde.
      _timer?.cancel();
      _timer = Timer(_timeout - transcurrido, _logout);
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
