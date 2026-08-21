import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/portal_tracking.dart';
import 'package:sozu_cliente_app/core/push_service.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/router.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';

/// Con sesión de un Cliente real:
/// - Móvil: registra el dispositivo para push (FCM) y conecta sus handlers
///   (foreground → refresca campana; tap → pantalla de notificaciones).
/// - Todas las plataformas: suscripción Realtime a INSERTs en
///   las notificaciones del propio email → la campana se actualiza al instante
///   con la app abierta. El cómo vive en `LiveNotificationsPort`.
class PushRegistrar extends ConsumerStatefulWidget {
  final Widget child;

  const PushRegistrar({super.key, required this.child});

  @override
  ConsumerState<PushRegistrar> createState() => _PushRegistrarState();
}

class _PushRegistrarState extends ConsumerState<PushRegistrar> {
  static const _pollIntervalo = Duration(seconds: 30);

  bool _handlersListos = false;
  Timer? _pollTimer;

  Future<void> _registrar() async {
    await PushService.registrarDispositivo(ref.read(pushPortProvider));
    if (_handlersListos || !mounted) return;
    _handlersListos = true;
    PushService.onForegroundMessage((_) {
      ref.invalidate(notificationsProvider);
    });
    await PushService.onNotificationTap((_) {
      // push (no go): apila sobre la pantalla actual para que exista
      // "regresar"; con go se reemplazaba el stack y no había flecha.
      ref.read(routerProvider).push('/notificaciones');
    });
  }

  /// La idempotencia y el estado de la suscripcion viven en el puerto, no aqui:
  /// este widget solo dice si debe haber escucha y para quien.
  void _sincronizarEnVivo({required bool activo, String? email}) {
    final puerto = ref.read(liveNotificationsPortProvider);
    if (activo && email != null && email.isNotEmpty) {
      puerto.subscribe(
        email: email,
        onNew: () {
          if (mounted) ref.invalidate(notificationsProvider);
        },
      );
    } else if (!activo) {
      puerto.unsubscribe();
    }
  }

  /// Refresco periódico de la campana con la app abierta (respaldo del
  /// realtime; cubre también la impersonación de admin, donde el canal
  /// realtime no aplica).
  void _sincronizarPolling({required bool activo}) {
    if (activo && _pollTimer == null) {
      _pollTimer = Timer.periodic(_pollIntervalo, (_) {
        if (mounted) ref.invalidate(notificationsProvider);
      });
    } else if (!activo && _pollTimer != null) {
      _pollTimer!.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    ref.read(liveNotificationsPortProvider).unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final esClienteConSesion = auth.session != null && auth.hasPortalAccess;
    final email = (auth.profile?.email ?? auth.session?.email)
        ?.trim()
        .toLowerCase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (esClienteConSesion && PushService.soportado) _registrar();
      _sincronizarEnVivo(activo: esClienteConSesion, email: email);
      _sincronizarPolling(activo: auth.session != null);
      // Mediciones "Uso por portal": sesión del portal clientes (solo
      // clientes reales; la impersonación de admin no cuenta).
      if (esClienteConSesion) {
        PortalTracking.iniciar(ref.read(trackingPortProvider));
      }
    });
    return widget.child;
  }
}
