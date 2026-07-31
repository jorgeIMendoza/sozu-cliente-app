import 'package:sozu_cliente_app/domain/api_error.dart';

/// Sesion autenticada, vista desde el dominio.
class AuthSession {
  final String userId;
  final String? email;
  final DateTime? lastSignInAt;

  /// Credencial de renovacion. Solo el candado biometrico la persiste; no se
  /// muestra ni se loguea. Viene en cada emision porque el backend la ROTA en
  /// cada login y cada refresh: leerla aparte da la anterior.
  final String? refreshToken;

  const AuthSession({
    required this.userId,
    this.email,
    this.lastSignInAt,
    this.refreshToken,
  });
}

/// Perfil del usuario autenticado: identidad, rol y permisos.
class UserProfile {
  final String? nombre;
  final String? email;
  final String? rolNombre;
  final int? idPersona;
  final bool debeCambiarPassword;

  /// Permiso `roles.administrar_app_clientes`: habilita el acceso administrador
  /// del app (selector de clientes, avisos, configuracion).
  final bool administrarAppClientes;

  const UserProfile({
    this.nombre,
    this.email,
    this.rolNombre,
    this.idPersona,
    this.debeCambiarPassword = false,
    this.administrarAppClientes = false,
  });
}

/// Sesion, perfil y contrasenas. No cubre el candado biometrico ni el cierre por
/// inactividad: eso es estado local de la app, no del backend.
abstract interface class AuthPort {
  /// Sesion vigente, o null si no hay ninguna.
  AuthSession? get currentSession;

  /// Cambios de sesion: login, cierre y rotacion de token. Emite null al cerrar.
  Stream<AuthSession?> get sessionChanges;

  /// Perfil del usuario autenticado, o null si no hay fila para su identidad.
  /// No lanza: cualquier fallo se reporta como null.
  Future<UserProfile?> profile();

  /// Entra con correo y contrasena. Lanza [AuthError] con la causa traducida.
  Future<AuthSession> signIn({required String email, required String password});

  /// Confirma la identidad del usuario actual sin transicionar de sesion.
  /// false si la contrasena no coincide; lanza [AuthError] si no se pudo
  /// verificar (red, servidor), que el llamador debe distinguir del false.
  Future<bool> verifyPassword(String password);

  /// Restaura la sesion desde un refresh token guardado (login biometrico).
  ///
  /// Lanza [AuthError], y el candado biometrico DEPENDE de cual: `network` es
  /// reintentable y el token guardado sigue vivo; `sessionRevoked` significa que
  /// hay que borrarlo. Confundirlos deja al usuario fuera con un token sano.
  Future<AuthSession> restoreSession(String refreshToken);

  /// Cierra la sesion revocandola en el servidor.
  Future<void> signOut();

  /// Envia el correo de restablecimiento de contrasena.
  Future<void> sendPasswordReset(String email);

  /// Cambia la contrasena del usuario autenticado. Lanza [AuthError].
  Future<void> updatePassword(String newPassword);

  /// Limpia el flag de contrasena temporal. Best-effort: el llamador no debe
  /// abortar el cambio de contrasena si esto falla.
  Future<void> markPasswordChanged();
}
