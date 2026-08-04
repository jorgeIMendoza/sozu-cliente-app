import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Area de inicio del menu: tablero de resumen, menu activo y notificaciones.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class HomePort {
  /// Resumen del tablero de inicio: financiero, actividad y pendientes.
  Future<ClienteResumen> summary();

  /// Items de menu activos y permitidos para este cliente.
  Future<List<MenuItemDto>> menu();

  /// Notificaciones del cliente y su conteo de no leidas.
  Future<ClienteNotificaciones> notifications();

  /// Marca una notificacion como leida.
  Future<void> markNotificationRead(int notificationId);

  /// Revierte el "leido" de una notificacion.
  Future<void> markNotificationUnread(int notificationId);

  /// Marca como leidas todas las notificaciones del cliente.
  Future<void> markAllNotificationsRead();

  /// Descarta una notificacion: deja de listarse y de contar.
  Future<void> dismissNotification(int notificationId);
}
