import 'package:sozu_cliente_app/shared/api_error.dart';

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
  final String? displayName;
  final String? email;
  final String? roleName;

  /// Id del rol (`roles.id`). Uno de los dos caminos que abre el portal: lo
  /// compara `PortalAccess.allows` (estable, no depende del nombre del rol).
  final int? roleId;

  /// ¿Tiene una compra activa (`compradores.activo`)? El otro camino al portal:
  /// un interno puede ser cliente y su rol no lo dice.
  ///
  /// `false` mientras el RPC no devuelva `es_comprador`, y ahí el acceso queda
  /// como antes (solo rol Cliente): el campo es aditivo a propósito para no
  /// exigir un despliegue simultáneo con el backend.
  final bool isBuyer;
  final int? personId;

  /// Flag de contrasena temporal (`debe_cambiar_password`): fuerza el cambio
  /// antes de entrar. Distinto de `AuthController.mustChangePassword`, que es
  /// la lectura de este campo con default.
  final bool requiresPasswordChange;

  /// Permiso `roles.administrar_app_clientes`: habilita el acceso administrador
  /// del app (selector de clientes, avisos, configuracion).
  final bool canManageClientApp;

  /// `usuarios.activo`. El RPC dejó de filtrar por `activo = TRUE` (antes una
  /// cuenta dada de baja devolvía cero filas), así que el gate vive aquí.
  final bool isActive;

  /// `usuarios.email_confirmado`: si el correo ya fue verificado.
  final bool isEmailConfirmed;

  /// `roles.requiere_confirmacion_email`: true en los roles de portal (Cliente
  /// incluido). Los roles internos entran sin confirmar el correo.
  final bool requiresEmailConfirmation;

  const UserProfile({
    this.displayName,
    this.email,
    this.roleName,
    this.roleId,
    this.isBuyer = false,
    this.personId,
    this.requiresPasswordChange = false,
    this.canManageClientApp = false,
    this.isActive = true,
    this.isEmailConfirmed = true,
    this.requiresEmailConfirmation = false,
  });

  /// El rol exige confirmar el correo y todavía no está confirmado.
  bool get hasPendingEmailConfirmation =>
      requiresEmailConfirmation && !isEmailConfirmed;
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

  /// Envia el correo de restablecimiento de contrasena. Lanza [AuthError] solo
  /// ante fallo real (red o servidor): que la cuenta no exista NO es error, el
  /// backend responde igual para no revelar que correos estan registrados.
  Future<void> sendPasswordReset(String email);

  /// Reenvia el correo de confirmacion de la cuenta. Se llama SIN sesion (el
  /// gate ya la cerro), asi que recibe el correo por parametro. Lanza
  /// [AuthError] ante fallo real.
  Future<void> resendEmailConfirmation(String email);

  /// Cambia la contrasena del usuario autenticado. Lanza [AuthError].
  Future<void> updatePassword(String newPassword);

  /// Limpia el flag de contrasena temporal. Best-effort: el llamador no debe
  /// abortar el cambio de contrasena si esto falla.
  Future<void> markPasswordChanged();

  /// Canjea el token de un enlace de confirmacion y deja la sesion abierta.
  ///
  /// [type] es el tipo que declara la URL. Lanza [AuthError]: `sessionRevoked`
  /// si el token vencio o ya se uso (el enlace es de un solo uso).
  Future<AuthSession> confirmEmailLink({
    required String tokenHash,
    required String type,
  });

  /// Cierra el alta tras confirmar el correo: marca la cuenta como confirmada
  /// y dispara el envio de credenciales. Requiere la sesion de
  /// [confirmEmailLink] como prueba de titularidad.
  Future<void> completeRegistration({required String email, String? name});
}
