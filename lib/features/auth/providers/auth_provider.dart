import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/portal_tracking.dart';
import 'package:sozu_cliente_app/core/push_service.dart';
import 'package:sozu_cliente_app/features/auth/adapters/auth_adapter.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Estado de sesión/JWT + perfil (espejo de src/providers/AuthProvider.tsx).
/// - Todo acceso al backend va por [AuthPort]; este archivo no conoce Supabase.
/// - `mustChangePassword` fuerza el cambio de contraseña temporal.
/// - El listener de sessionChanges solo actualiza la sesión; el perfil se
///   carga aparte (mismo patrón anti-deadlock que el app RN).

class WrongCurrentPasswordError implements Exception {}

class AuthController extends ChangeNotifier {
  /// Al construirse inyecta el puerto en [BiometricService]: el singleton no
  /// puede leer providers, y así el doble de un test lo alcanza sin más wiring.
  AuthController(this._port) {
    BiometricService.instance.usePort(_port);
    _init();
  }

  final AuthPort _port;
  StreamSubscription<AuthSession?>? _sub;

  AuthSession? session;
  UserProfile? profile;

  /// true mientras una pantalla de autenticación sigue trabajando después de
  /// que el estado de sesión ya cambió; el router no debe sacar al usuario de
  /// ella. Cubre dos casos: el login validando el rol (un signOut por rol
  /// inválido borraría el mensaje de error al desmontar) y el cambio de
  /// contraseña ofreciendo la biometría (el perfil ya no exige el cambio, así
  /// que el redirect se llevaría el sheet a medias).
  bool authFlowInProgress = false;

  /// Candado biométrico: la sesión del backend sigue viva (nunca se revocó)
  /// pero la app se comporta como deslogueada hasta desbloquear con
  /// huella/rostro o contraseña. El router lo trata como "sin sesión".
  bool locked = false;

  bool _authReady = false;
  bool _profileReady = false;
  String? _profileForUserId;

  bool get isLoading => !_authReady || !_profileReady;
  bool get mustChangePassword => profile?.requiresPasswordChange ?? false;

  /// Id del rol de usuario final (Cliente), configurable por ambiente vía el
  /// env `CLIENTE_ROL_ID` (dev/prod distintos). Si no está definido, el gate
  /// cae al nombre "Cliente" (transición) para no romper el acceso.
  static final int? clientRoleId = dotenv.isInitialized
      ? int.tryParse(dotenv.env['CLIENTE_ROL_ID'] ?? '')
      : null;

  /// ¿El perfil es un usuario final de la app (rol Cliente)? Por `roleId`; con
  /// fallback al nombre normalizado si `CLIENTE_ROL_ID` no está configurado.
  static bool isClientRole(UserProfile? p) {
    if (p == null) return false;
    if (clientRoleId != null) return p.roleId == clientRoleId;
    return (p.roleName ?? '').trim().toLowerCase() == 'cliente';
  }

  bool get isClient => isClientRole(profile);

  /// Acceso administrador del app: por permiso del rol (no por nombre).
  bool get isSuperAdmin => profile?.canManageClientApp ?? false;

  Future<void> _init() async {
    session = _port.currentSession;
    // Arranque en frío con candado activo: la app abre bloqueada (login con
    // prompt biométrico) aunque la sesión siga viva por debajo.
    if (session != null &&
        await BiometricService.instance.isEnabled() &&
        await BiometricService.instance.isLocked()) {
      locked = true;
    }
    _authReady = true;
    if (session != null && !locked) {
      await refreshProfile();
    }
    _profileReady = true;
    notifyListeners();

    _sub = _port.sessionChanges.listen((next) {
      final changedUser = next?.userId != session?.userId;
      session = next;
      // El backend ROTA el refresh token en cada login/refresh: si el login
      // biométrico está habilitado hay que re-guardar el token nuevo o el
      // guardado queda invalidado.
      if (next != null) {
        unawaited(BiometricService.instance.persistSession(next));
      }
      if (next == null) {
        profile = null;
        _profileForUserId = null;
        _profileReady = true;
        notifyListeners();
      } else if (!locked && (changedUser || _profileForUserId != next.userId)) {
        // Bloqueada: no cargar perfil (se carga al desbloquear).
        _loadProfileFor(next.userId);
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfileFor(String userId) async {
    _profileReady = false;
    notifyListeners();
    await refreshProfile();
    _profileForUserId = userId;
    _profileReady = true;
    notifyListeners();
  }

  /// Lee el perfil vía el puerto (rol + flag de cambio de contraseña).
  Future<UserProfile?> refreshProfile() async {
    profile = await _port.profile();
    if (profile != null) _profileForUserId = session?.userId;
    notifyListeners();
    return profile;
  }

  /// Traduce el fallo de [signIn] a un mensaje accionable.
  ///
  /// Vive aquí y no en la pantalla porque el mapa fallo→mensaje es política de
  /// auth, no de UI. La causa ([AuthFailure]) ya viene traducida del adaptador.
  ///
  /// Antes todo caía en "Correo o contrasena incorrectos", incluido el límite
  /// de intentos y la red caída: el usuario reintentaba con la contraseña
  /// correcta y volvía a fallar sin saber por qué.
  static String signInErrorMessage(Object e) {
    // Sin AuthError no hubo respuesta del servidor: fue la red.
    final reason = e is AuthError ? e.reason : AuthFailure.network;
    return switch (reason) {
      AuthFailure.tooManyAttempts =>
        'Demasiados intentos. Espera un minuto y vuelve a probar.',
      AuthFailure.emailNotConfirmed =>
        'Tu correo aun no esta confirmado. Revisa tu bandeja.',
      AuthFailure.network =>
        'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
      _ => 'Correo o contrasena incorrectos.',
    };
  }

  Future<void> signIn(String email, String password) async {
    final newSession = await _port.signIn(email: email, password: password);
    // Entrar por contraseña también levanta el candado biométrico.
    locked = false;
    await BiometricService.instance.unlock();
    // Si la biometría ya está habilitada, refresca el token guardado con el
    // de esta sesión (además del listener, para no depender de su orden).
    await BiometricService.instance.persistSession(newSession);
    await refreshProfile();
  }

  /// Hook para el login: ofrecer activar biometría tras un login por
  /// contraseña (solo móvil soportado, aún no habilitada y sin "Ahora no"
  /// previo en esta ejecución).
  Future<bool> shouldOfferBiometrics() async {
    final bio = BiometricService.instance;
    if (bio.offerDeclined) return false;
    // SOLO clientes. La biometría es un candado local sobre un refresh token
    // guardado, y la sesión de un administrador puede impersonar a cualquier
    // cliente: no se deja detrás de la huella enrolada en un teléfono.
    if (!isClient) return false;
    if (!await bio.isSupported()) return false;
    return !await bio.isEnabled();
  }

  Future<void> resetPassword(String email) async {
    await _port.sendPasswordReset(email);
  }

  /// Cambio forzado (contraseña temporal): updatePassword + limpiar el flag.
  Future<void> updatePassword(String newPassword) async {
    await _port.updatePassword(newPassword);
    await _port.markPasswordChanged();
    await refreshProfile();
  }

  /// Cambio voluntario: verifica la contraseña actual re-autenticando.
  Future<void> changePassword(String current, String next) async {
    // verifyPassword lanza AuthError si no se pudo verificar (red/servidor):
    // eso NO es contraseña equivocada y se deja propagar tal cual.
    if (!await _port.verifyPassword(current)) {
      throw WrongCurrentPasswordError();
    }
    await _port.updatePassword(next);
    await _port.markPasswordChanged();
    await refreshProfile();
  }

  /// Cierre REAL de sesión (revoca la sesión actual en el servidor). Usar
  /// solo cuando la sesión no debe sobrevivir (rol inválido en el login,
  /// desactivar biometría). Para el cierre normal usa [lockOrSignOut].
  Future<void> signOut() async {
    // El token push NO se da de baja: las notificaciones siguen llegando
    // deslogeado (el cierre por inactividad no debe cortar los push). Solo
    // se olvida el registro local para re-registrar si entra otro cliente.
    PushService.olvidarSesion();
    // Cierra la sesión de mediciones ANTES de perder el JWT.
    await PortalTracking.cerrar();
    await _port.signOut();
    locked = false;
    profile = null;
    notifyListeners();
  }

  /// Cierre iniciado por el usuario o por inactividad. Con biometría
  /// habilitada NO se toca el servidor: el backend revoca la sesión actual en
  /// cualquier signOut (aun scope local), lo que invalidaría el refresh
  /// token guardado y mataría el acceso con huella. En su lugar la app se
  /// BLOQUEA (candado persistido): la sesión sigue viva por debajo y la
  /// huella/rostro (o la contraseña) la desbloquea.
  Future<void> lockOrSignOut() async {
    if (session != null && await BiometricService.instance.isEnabled()) {
      PushService.olvidarSesion();
      await PortalTracking.cerrar();
      await BiometricService.instance.lock();
      locked = true;
      profile = null;
      _profileForUserId = null;
      notifyListeners();
      return;
    }
    await signOut();
  }

  /// Desbloqueo con huella/rostro: la sesión nunca se cerró, solo se
  /// re-valida la identidad y se recarga el perfil.
  Future<bool> unlockWithBiometrics() async {
    if (!locked || session == null) return false;
    if (!await BiometricService.instance.authenticate()) return false;
    await BiometricService.instance.unlock();
    locked = false;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Puerto de auth. El default es el adaptador real, la única composición
/// que existe en producción; los tests lo sobreescriben con un doble
/// (`overrideWithValue`), así que main.dart no necesita wiring propio.
final authPortProvider = Provider<AuthPort>((ref) => AuthAdapter());

final authProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(ref.watch(authPortProvider));
});

/// Se enciende cuando InactivityWatcher cierra la sesión por inactividad;
/// el login lo lee para explicar el cierre y lo apaga al reintentar.
final inactivityLogoutProvider = StateProvider<bool>((ref) => false);
