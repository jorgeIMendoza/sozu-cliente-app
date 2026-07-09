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

class _InactivityWatcherState extends ConsumerState<InactivityWatcher> {
  static const _timeout = Duration(minutes: 5);
  Timer? _timer;

  void _reset() {
    _timer?.cancel();
    if (ref.read(authProvider).session == null) return;
    _timer = Timer(_timeout, _logout);
  }

  Future<void> _logout() async {
    final auth = ref.read(authProvider);
    if (auth.session == null) return;
    ref.read(inactivityLogoutProvider.notifier).state = true;
    await auth.signOut();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-arma o cancela el timer cuando cambia el estado de sesión.
    final hasSession = ref.watch(authProvider.select((a) => a.session != null));
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
