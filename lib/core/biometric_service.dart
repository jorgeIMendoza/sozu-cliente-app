import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login biométrico (huella / Face ID) — SOLO móvil; en web todo devuelve
/// false y no se toca secure storage.
///
/// Guarda el refresh token de Supabase en secure storage (Keystore/Keychain)
/// bajo una key propia, separada de la sesión que persiste
/// SecureSessionStorage (esa se borra en signOut; esta sobrevive para poder
/// re-entrar con biometría).
///
/// IMPORTANTE — rotación: Supabase invalida el refresh token anterior en cada
/// refresh, por lo que hay que re-guardar el token nuevo tras cada
/// signedIn/tokenRefreshed (el AuthController llama a [persistirSesion] desde
/// su listener de onAuthStateChange) y tras cada setSession exitoso.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const _keyHabilitada = 'sozu_biometria_habilitada';
  static const _keyRefreshToken = 'sozu_biometria_refresh_token';
  static const _keyBloqueada = 'sozu_biometria_bloqueada';

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
    final token = Supabase.instance.client.auth.currentSession?.refreshToken;
    if (token == null || token.isEmpty) return false;
    if (!await autenticar()) return false;
    await _storage.write(key: _keyRefreshToken, value: token);
    await _storage.write(key: _keyHabilitada, value: 'true');
    return true;
  }

  /// Desactiva y borra el token guardado (única vía de borrado junto con el
  /// fallo de setSession; el signOut NO borra el token).
  Future<void> deshabilitar() async {
    if (!_esMovil) return;
    await _storage.delete(key: _keyRefreshToken);
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
  /// onAuthStateChange con sesión (signedIn / tokenRefreshed): el token
  /// anterior queda invalidado por Supabase y sin esto el login biométrico
  /// moriría al primer refresh.
  Future<void> persistirSesion(Session? session) async {
    final token = session?.refreshToken;
    if (token == null || token.isEmpty) return;
    if (!await habilitada()) return;
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Flujo completo: autenticar → restaurar sesión con el refresh token
  /// guardado. Si Supabase rechaza el token (inválido/revocado) se borra el
  /// token guardado (se mantiene el flag: el próximo login por contraseña lo
  /// re-alimenta vía [persistirSesion]) y devuelve false para caer al login
  /// normal. Errores de red NO borran el token.
  Future<bool> loginBiometrico() async {
    if (!await habilitada()) return false;
    final token = await _storage.read(key: _keyRefreshToken);
    if (token == null || token.isEmpty) return false;
    if (!await autenticar()) return false;
    try {
      final res = await Supabase.instance.client.auth.setSession(token);
      final nuevo = res.session?.refreshToken;
      if (nuevo != null && nuevo.isNotEmpty) {
        await _storage.write(key: _keyRefreshToken, value: nuevo);
      }
      return res.session != null;
    } on AuthRetryableFetchException {
      return false; // sin red: reintentar luego, el token sigue siendo válido
    } on AuthException {
      await _storage.delete(key: _keyRefreshToken);
      return false;
    } catch (_) {
      return false;
    }
  }
}
