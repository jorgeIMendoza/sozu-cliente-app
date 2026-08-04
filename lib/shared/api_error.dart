/// Errores que declaran los puertos de `domain/`. Sin imports: la UI los atrapa
/// sin conocer el backend.
library;

/// Fallo de una operacion de backend: `status` HTTP y `code` de negocio.
class ApiError implements Exception {
  /// Codigo HTTP; 0 cuando no hubo respuesta (red caida).
  final int status;

  /// Codigo de negocio del backend, p.ej. `forbidden_role`, `network_error`.
  final String code;

  ApiError(this.status, this.code);

  @override
  String toString() => 'ApiError($status, $code)';
}

/// El documento subido no paso la validacion del backend.
class DocumentoInvalidoError implements Exception {
  /// Motivo en espanol, listo para mostrarse al usuario tal cual.
  final String reason;

  DocumentoInvalidoError(this.reason);

  @override
  String toString() => 'DocumentoInvalidoError($reason)';
}

/// Causa de un fallo de autenticacion, ya traducida por el adaptador.
enum AuthFailure {
  /// Contrasena equivocada, usuario inexistente o correo sin confirmar: el
  /// backend responde 400 para los tres y el mensaje se mantiene generico para
  /// no revelar que cuentas existen.
  invalidCredentials,

  /// El backend lo distingue explicitamente (no cae en 400).
  emailNotConfirmed,

  /// Limite de intentos; reintentar mas tarde con las mismas credenciales.
  tooManyAttempts,

  /// No hubo respuesta del servidor. REINTENTABLE: las credenciales guardadas
  /// (refresh token del candado biometrico) siguen siendo validas y NO se borran.
  network,

  /// La sesion o el refresh token ya no valen (revocados o caducados).
  /// El llamador debe DESCARTAR la credencial guardada.
  sessionRevoked,

  unknown,
}

/// Fallo de una operacion de sesion o contrasena.
class AuthError implements Exception {
  final AuthFailure reason;

  AuthError(this.reason);

  @override
  String toString() => 'AuthError($reason)';
}
