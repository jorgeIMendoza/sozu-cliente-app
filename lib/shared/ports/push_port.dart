import 'package:sozu_cliente_app/shared/api_error.dart';

/// Registro de notificaciones push del dispositivo y preferencia del cliente.
///
/// Nunca impersona: el token pertenece al dispositivo del usuario logueado, no
/// al cliente que un admin este viendo. Todos los metodos lanzan [ApiError].
abstract interface class PushPort {
  /// Registra el token del dispositivo. `platform`: 'android' | 'ios'.
  Future<void> registerToken({required String token, required String platform});

  /// Da de baja el token del dispositivo. Best-effort al cerrar sesion.
  Future<void> unregisterToken(String token);

  /// Preferencia de push del cliente; true si nunca la ha cambiado.
  Future<bool> enabled();

  /// Activa o desactiva los push. No da de baja tokens: el envio filtra por
  /// esta preferencia, asi que reactivar es inmediato.
  Future<void> setEnabled(bool value);
}
