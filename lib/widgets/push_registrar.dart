import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/push_service.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../router.dart';

/// Con sesión de un Cliente real:
/// - Móvil: registra el dispositivo para push (FCM) y conecta sus handlers
///   (foreground → refresca campana; tap → pantalla de notificaciones).
/// - Todas las plataformas: suscripción Realtime a INSERTs en
///   notificaciones_cliente del propio email → la campana se actualiza al
///   instante con la app abierta (requiere la policy de solo-lectura del
///   dueño y la tabla en la publicación supabase_realtime).
class PushRegistrar extends ConsumerStatefulWidget {
  final Widget child;

  const PushRegistrar({super.key, required this.child});

  @override
  ConsumerState<PushRegistrar> createState() => _PushRegistrarState();
}

class _PushRegistrarState extends ConsumerState<PushRegistrar> {
  static const _pollIntervalo = Duration(seconds: 30);

  bool _handlersListos = false;
  RealtimeChannel? _canalNotif;
  String? _emailSuscrito;
  Timer? _pollTimer;

  Future<void> _registrar() async {
    await PushService.registrarDispositivo();
    if (_handlersListos || !mounted) return;
    _handlersListos = true;
    PushService.onForegroundMessage((_) {
      ref.invalidate(clienteNotificacionesProvider);
    });
    await PushService.onNotificationTap((_) {
      ref.read(routerProvider).go('/notificaciones');
    });
  }

  void _sincronizarRealtime({required bool activo, String? email}) {
    if (activo && email != null && email.isNotEmpty) {
      if (_emailSuscrito == email) return;
      _canalNotif?.unsubscribe();
      final sb = Supabase.instance.client;
      // El socket de Realtime debe llevar el JWT del usuario: sin esto la
      // policy RLS se evalúa como anon y los eventos nunca llegan.
      final token = sb.auth.currentSession?.accessToken;
      if (token != null) sb.realtime.setAuth(token);
      final canal = sb.channel('notificaciones-cliente');
      canal.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notificaciones_cliente',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'email_cliente',
          value: email,
        ),
        callback: (payload) {
          debugPrint('[realtime] notificación nueva: ${payload.newRecord}');
          if (mounted) ref.invalidate(clienteNotificacionesProvider);
        },
      );
      canal.subscribe((status, error) {
        debugPrint('[realtime] canal notificaciones: $status'
            '${error != null ? ' · $error' : ''} (email=$email)');
      });
      _canalNotif = canal;
      _emailSuscrito = email;
    } else if (!activo && _canalNotif != null) {
      _canalNotif!.unsubscribe();
      _canalNotif = null;
      _emailSuscrito = null;
    }
  }

  /// Refresco periódico de la campana con la app abierta (respaldo del
  /// realtime; cubre también la impersonación de admin, donde el canal
  /// realtime no aplica).
  void _sincronizarPolling({required bool activo}) {
    if (activo && _pollTimer == null) {
      _pollTimer = Timer.periodic(_pollIntervalo, (_) {
        if (mounted) ref.invalidate(clienteNotificacionesProvider);
      });
    } else if (!activo && _pollTimer != null) {
      _pollTimer!.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _canalNotif?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final esClienteConSesion = auth.session != null && auth.isCliente;
    final email = (auth.profile?.email ?? auth.session?.user.email)
        ?.trim()
        .toLowerCase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (esClienteConSesion && PushService.soportado) _registrar();
      _sincronizarRealtime(activo: esClienteConSesion, email: email);
      _sincronizarPolling(activo: auth.session != null);
    });
    return widget.child;
  }
}
