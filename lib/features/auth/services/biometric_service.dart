import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Resultado de [BiometricService.loginBiometrico]. Distinguir los casos importa
/// porque solo uno se arregla reintentando: `sessionExpired` exige un login por
/// contraseña, y sin decirlo el botón parece roto.
enum BiometricLoginResult {
  /// Sesión restaurada.
  success,

  /// El usuario canceló o la huella no coincidió. Reintentable.
  cancelled,

  /// No hay token guardado, o el servidor lo rechazó. Hace falta entrar una vez
  /// con contraseña para volver a armar la biometría.
  sessionExpired,

  /// Sin red. El token guardado sigue sirviendo.
  networkError,
}

/// Login biométrico (huella / Face ID) - SOLO móvil; en web todo devuelve
/// false y no se toca secure storage.
///
/// La huella NUNCA sale del teléfono: `local_auth` solo le pregunta al sistema
/// "¿es el usuario enrolado?" y recibe sí o no. Lo que este servicio guarda es
/// el refresh token de Supabase, así que la biometría es un candado local sobre
/// una sesión ya autenticada, no una identificación contra el servidor.
///
/// Guarda el refresh token en secure storage (Keystore/Keychain) bajo una key
/// propia, separada de la sesión que persiste SecureSessionStorage (esa se
/// borra en signOut; esta sobrevive para poder re-entrar con biometría).
///
/// IMPORTANTE - rotación: el backend invalida el refresh token anterior en
/// cada refresh, por lo que hay que re-guardar el token nuevo tras cada
/// cambio de sesión (el AuthController llama a [persistirSesion] desde su
/// listener de sessionChanges) y tras cada [loginBiometrico] exitoso.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  /// Puerto de auth, inyectado por AuthController al construirse (este
  /// singleton no puede leer providers). Usarlo antes es error de wiring:
  /// `late` a propósito para que truene en vez de fallar en silencio.
  late AuthPort _port;

  /// Inyecta el puerto. Lo llama AuthController; los tests pasan su doble.
  void usarPuerto(AuthPort port) => _port = port;

  static const _keyHabilitada = 'sozu_biometria_habilitada';
  static const _keyRefreshToken = 'sozu_biometria_refresh_token';
  static const _keyBloqueada = 'sozu_biometria_bloqueada';
  static const _keyUserId = 'sozu_biometria_user_id';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// "Ahora no" en la oferta post-login: solo en memoria, así no se insiste
  /// en lo que queda de esta ejecución del app pero sí (recordatorio suave)
  /// en el siguiente arranque.
  bool ofertaRechazada = false;

  bool get _esMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Hardware biométrico disponible Y con huella/rostro enrolado.
  Future<bool> soportado() async {
    if (!_esMovil) return false;
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Flag persistido: el usuario activó el login biométrico.
  Future<bool> habilitada() async {
    if (!_esMovil) return false;
    return await _storage.read(key: _keyHabilitada) == 'true';
  }

  /// Habilitada Y con refresh token guardado: se puede ofrecer el botón
  /// "Entrar con huella / Face ID" en el login.
  Future<bool> disponibleParaLogin() async {
    if (!await habilitada()) return false;
    final token = await _storage.read(key: _keyRefreshToken);
    return token != null && token.isNotEmpty;
  }

  /// Pide huella/rostro al usuario. Devuelve false ante cancelación o
  /// cualquier error del plugin (lockout, notAvailable, notEnrolled, etc.).
  Future<bool> autenticar() async {
    if (!_esMovil) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a SOZU',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Activa el login biométrico: autentica una vez para confirmar y guarda
  /// el refresh token de la sesión ACTUAL + el flag.
  Future<bool> habilitar() async {
    if (!_esMovil) return false;
    final session = _port.currentSession;
    final token = session?.refreshToken;
    final userId = session?.userId;
    if (token == null || token.isEmpty || userId == null) return false;
    if (!await autenticar()) return false;
    await _storage.write(key: _keyRefreshToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyHabilitada, value: 'true');
    return true;
  }

  /// Apaga la biometría si el enrolamiento es de [userId]; si es de otra cuenta
  /// no la toca. Se usa cuando una cuenta pierde el derecho a biometría (entrar
  /// con acceso administrador) sin arrastrar el enrolamiento de otra cuenta que
  /// use el mismo teléfono.
  Future<void> deshabilitarSiEsDe(String userId) async {
    if (!_esMovil) return;
    if (await _storage.read(key: _keyUserId) == userId) {
      await deshabilitar();
    }
  }

  /// Desactiva y borra el token guardado (única vía de borrado junto con el
  /// fallo de setSession; el signOut NO borra el token).
  Future<void> deshabilitar() async {
    if (!_esMovil) return;
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyHabilitada);
    await _storage.delete(key: _keyBloqueada);
  }

  /// Candado persistido: el "logout" con biometría habilitada NO cierra la
  /// sesión en el servidor (gotrue revoca la sesión actual en cualquier
  /// signOut, incluso scope local, lo que invalidaría el refresh token
  /// guardado). Solo se marca bloqueada; sobrevive al cierre del app.
  Future<void> marcarBloqueada() async {
    if (!_esMovil) return;
    await _storage.write(key: _keyBloqueada, value: 'true');
  }

  Future<void> desmarcarBloqueada() async {
    if (!_esMovil) return;
    await _storage.delete(key: _keyBloqueada);
  }

  Future<bool> bloqueada() async {
    if (!_esMovil) return false;
    return await _storage.read(key: _keyBloqueada) == 'true';
  }

  /// Re-guarda el refresh token rotado. Llamar en cada evento de
  /// sessionChanges con sesión (login / refresh): el token anterior queda
  /// invalidado por el backend y sin esto el login biométrico moriría al
  /// primer refresh.
  ///
  /// Ignora las sesiones de otra cuenta: el enrolamiento está atado al usuario
  /// que lo activó.
  Future<void> persistirSesion(AuthSession? session) async {
    final token = session?.refreshToken;
    if (token == null || token.isEmpty) return;
    if (!await habilitada()) return;
    // El enrolamiento pertenece a UNA cuenta. Sin esta comprobación, entrar con
    // otra cuenta en el mismo teléfono sobreescribía el token guardado y la
    // huella acababa restaurando ESA sesión: un administrador que entrara en el
    // teléfono de un cliente enrolado quedaba accesible con la huella del
    // cliente.
    final userId = session!.userId;
    final enrolado = await _storage.read(key: _keyUserId);
    if (enrolado == null) {
      // Enrolamiento de una build que no guardaba el dueño: se adopta el de esta
      // sesión para que quede atado de aquí en adelante.
      await _storage.write(key: _keyUserId, value: userId);
    } else if (enrolado != userId) {
      return;
    }
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Flujo completo: autenticar → restaurar sesión con el refresh token
  /// guardado. Si el backend rechaza el token (inválido/revocado) se borra el
  /// token guardado y se mantiene el flag: el próximo login por contraseña lo
  /// re-alimenta vía [persistirSesion]. Errores de red NO borran el token.
  Future<BiometricLoginResult> loginBiometrico() async {
    if (!await habilitada()) return BiometricLoginResult.sessionExpired;
    final token = await _storage.read(key: _keyRefreshToken);
    // Sin token no se pide la huella: seria un prompt que no puede entrar.
    if (token == null || token.isEmpty) {
      return BiometricLoginResult.sessionExpired;
    }
    if (!await autenticar()) return BiometricLoginResult.cancelled;
    try {
      final nueva = await _port.restoreSession(token);
      final nuevo = nueva.refreshToken;
      if (nuevo != null && nuevo.isNotEmpty) {
        await _storage.write(key: _keyRefreshToken, value: nuevo);
      }
      return BiometricLoginResult.success;
    } on AuthError catch (e) {
      if (e.reason == AuthFailure.network) {
        return BiometricLoginResult.networkError;
      }
      if (e.reason == AuthFailure.sessionRevoked) {
        await _storage.delete(key: _keyRefreshToken);
      }
      return BiometricLoginResult.sessionExpired;
    } catch (_) {
      return BiometricLoginResult.sessionExpired;
    }
  }
}
