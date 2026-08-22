import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/shared/ports/live_notifications_port.dart';

/// Implementacion actual de [LiveNotificationsPort] sobre Supabase Realtime
/// (INSERTs en `notificaciones_cliente`): la unica frontera donde se conocen
/// sus tipos.
///
/// Requiere la policy de solo-lectura del dueno y la tabla dentro de la
/// publicacion `supabase_realtime`.
class LiveNotificationsAdapter implements LiveNotificationsPort {
  static const _canal = 'notificaciones-cliente';
  static const _tabla = 'notificaciones_cliente';

  RealtimeChannel? _suscripcion;
  String? _emailSuscrito;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Future<void> subscribe({
    required String email,
    required void Function() onNew,
  }) async {
    if (_emailSuscrito == email) return;
    await unsubscribe();

    // El socket debe llevar el JWT del usuario: sin esto la policy RLS se
    // evalua como anon y los eventos nunca llegan.
    final token = _sb.auth.currentSession?.accessToken;
    if (token != null) _sb.realtime.setAuth(token);

    final canal = _sb.channel(_canal)
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: _tabla,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'email_cliente',
          value: email,
        ),
        // El payload NO se propaga: el puerto solo avisa que llego algo. Y no
        // se loguea, que trae datos del cliente.
        callback: (_) => onNew(),
      );
    canal.subscribe((status, error) {
      debugPrint(
        '[realtime] canal notificaciones: $status'
        '${error != null ? ' · $error' : ''}',
      );
    });

    _suscripcion = canal;
    _emailSuscrito = email;
  }

  @override
  Future<void> unsubscribe() async {
    await _suscripcion?.unsubscribe();
    _suscripcion = null;
    _emailSuscrito = null;
  }
}
