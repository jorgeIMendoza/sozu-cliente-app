import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/home/ports/home_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [HomePort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `homePortProvider.overrideWithValue`.
class FakeHomePort implements HomePort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  int noLeidas = 2;

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<ClienteResumen> summary() async {
    _throwIfFailing('summary');
    return ClienteResumen.fromJson({
      'cliente': {'nombre_legal': 'Alex Hernández', 'iniciales': 'AH'},
      'resumen': {'patrimonio_total': 100.0},
    });
  }

  @override
  Future<List<MenuItemDto>> menu() async {
    _throwIfFailing('menu');
    return [
      MenuItemDto.fromJson({
        'id': 1,
        'label': 'Inicio',
        'route': '/inicio',
        'orden': 1,
      }),
      MenuItemDto.fromJson({
        'id': 2,
        'label': 'Pagos',
        'route': '/pagos',
        'orden': 2,
      }),
    ];
  }

  @override
  Future<ClienteNotificaciones> notifications() async {
    _throwIfFailing('notifications');
    return ClienteNotificaciones.fromJson({
      'notificaciones': [],
      'no_leidas': noLeidas,
    });
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {
    _throwIfFailing('markNotificationRead:$notificationId');
    noLeidas = noLeidas > 0 ? noLeidas - 1 : 0;
  }

  @override
  Future<void> markNotificationUnread(int notificationId) async {
    _throwIfFailing('markNotificationUnread:$notificationId');
    noLeidas++;
  }

  @override
  Future<void> markAllNotificationsRead() async {
    _throwIfFailing('markAllNotificationsRead');
    noLeidas = 0;
  }

  @override
  Future<void> dismissNotification(int notificationId) async {
    _throwIfFailing('dismissNotification:$notificationId');
  }
}
