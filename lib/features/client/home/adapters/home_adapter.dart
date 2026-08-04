import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/home/ports/home_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion de [HomePort] sobre Supabase (edge functions cliente-resumen,
/// cliente-menu y cliente-notificaciones).
class HomeAdapter implements HomePort {
  /// Cliente que se esta viendo cuando un super admin impersona; null = el propio.
  final int? impersonate;

  const HomeAdapter({this.impersonate});

  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  /// Invoca una edge function con el JWT del usuario (y la cabecera de
  /// impersonacion si aplica) y normaliza cualquier fallo a [ApiError].
  Future<Map<String, dynamic>> _invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        fn,
        body: body ?? {},
        headers: impersonate != null
            ? {'x-impersonate-id-persona': '$impersonate'}
            : null,
      );
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiError(500, 'empty_response');
    } on FunctionException catch (e) {
      var code = 'internal_error';
      final details = e.details;
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      throw ApiError(e.status, code);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  @override
  Future<ClienteResumen> summary() async =>
      ClienteResumen.fromJson(await _invoke('cliente-resumen'));

  @override
  Future<List<MenuItemDto>> menu() async {
    final res = await _invoke('cliente-menu');
    return ((res['items'] as List?) ?? [])
        .map((e) => MenuItemDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ClienteNotificaciones> notifications() async =>
      ClienteNotificaciones.fromJson(await _invoke('cliente-notificaciones'));

  @override
  Future<void> markNotificationRead(int notificationId) async {
    await _invoke(
      'cliente-notificaciones',
      body: {'action': 'marcar_leida', 'id': notificationId},
    );
  }

  @override
  Future<void> markNotificationUnread(int notificationId) async {
    await _invoke(
      'cliente-notificaciones',
      body: {'action': 'marcar_no_leida', 'id': notificationId},
    );
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _invoke('cliente-notificaciones', body: {'action': 'marcar_todas'});
  }

  @override
  Future<void> dismissNotification(int notificationId) async {
    await _invoke(
      'cliente-notificaciones',
      body: {'action': 'descartar', 'id': notificationId},
    );
  }
}
