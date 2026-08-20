import 'package:sozu_cliente_app/shared/ports/live_notifications_port.dart';

/// Doble de [LiveNotificationsPort] en memoria: sin socket, sin Supabase.
/// Se inyecta con `liveNotificationsPortProvider.overrideWithValue`.
class FakeLiveNotificationsPort implements LiveNotificationsPort {
  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  String? emailSuscrito;
  void Function()? _onNew;

  /// Simula que llego una notificacion nueva por el canal.
  void emitir() => _onNew?.call();

  @override
  Future<void> subscribe({
    required String email,
    required void Function() onNew,
  }) async {
    log.add('subscribe:$email');
    emailSuscrito = email;
    _onNew = onNew;
  }

  @override
  Future<void> unsubscribe() async {
    log.add('unsubscribe');
    emailSuscrito = null;
    _onNew = null;
  }
}
