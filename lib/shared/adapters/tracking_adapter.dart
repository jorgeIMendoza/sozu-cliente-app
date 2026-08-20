import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/shared/ports/tracking_port.dart';

/// Implementacion actual de [TrackingPort] sobre Supabase (RPC
/// `register/touch/close_portal_session`): la unica frontera donde se conocen
/// sus tipos.
class TrackingAdapter implements TrackingPort {
  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Future<String?> register({
    required String portal,
    required String userAgent,
  }) async {
    try {
      final res = await _sb.rpc(
        'register_portal_session',
        params: {'p_portal': portal, 'p_user_agent': userAgent},
      );
      return res as String?;
    } catch (e) {
      // Se traga a proposito: una medicion perdida no puede impedir entrar.
      debugPrint('TrackingAdapter: no se pudo registrar la sesion: $e');
      return null;
    }
  }

  @override
  Future<void> touch(String sessionId) async {
    try {
      await _sb.rpc(
        'touch_portal_session',
        params: {'p_session_id': sessionId},
      );
    } catch (_) {
      // El siguiente latido reintenta.
    }
  }

  @override
  Future<void> close(String sessionId) async {
    try {
      await _sb.rpc(
        'close_portal_session',
        params: {'p_session_id': sessionId},
      );
    } catch (_) {
      // La sesion expira sola por inactividad.
    }
  }
}
