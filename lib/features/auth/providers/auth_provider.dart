import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/portal_tracking.dart';
import 'package:sozu_cliente_app/core/push_service.dart';
import 'package:sozu_cliente_app/features/auth/adapters/auth_adapter.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/features/auth/services/portal_access.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Estado de sesión/JWT + perfil (espejo de src/providers/AuthProvider.tsx).
/// - Todo acceso al backend va por [AuthPort]; este archivo no conoce Supabase.
/// - `mustChangePassword` fuerza el cambio de contraseña temporal.
/// - El listener de sessionChanges solo actualiza la sesión; el perfil se
///   carga aparte (mismo patrón anti-deadlock que el app RN).
/// - [AuthController.applyAccessGates] cierra la sesión de las cuentas que no
///   pueden entrar (dadas de baja o con el correo sin confirmar).

class WrongCurrentPasswordError implements Exception {}

/// Motivo por el que una cuenta autenticada NO puede usar la app. El orden de
/// los valores es el del gate: primero la baja, después el correo.
enum AccessBlock {
  /// `usuarios.activo = false`.
  deactivated,

  /// Rol de portal (`roles.requiere_confirmacion_email`) cuyo correo todavía no
  /// está verificado (`usuarios.email_confirmado = false`).
  emailNotConfirmed,
}

/// Texto que se muestra al usuario para cada motivo de bloqueo.
String accessBlockMessage(AccessBlock reason) => switch (reason) {
  AccessBlock.deactivated =>
    'Tu cuenta está desactivada. Contacta al administrador para reactivarla.',
  AccessBlock.emailNotConfirmed =>
    'Confirma tu correo para entrar. Revisa tu bandeja de entrada.',
};

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
  /// contraseña cerrando la sesión (el perfil ya no exige el cambio, así que el
  /// redirect abandonaría la ruta con el cierre a medias).
  bool authFlowInProgress = false;

  /// Candado biométrico: la sesión del backend sigue viva (nunca se revocó)
  /// pero la app se comporta como deslogueada hasta desbloquear con
  /// huella/rostro o contraseña. El router lo trata como "sin sesión".
  bool locked = false;

  /// Motivo por el que el gate de cuenta cerró la sesión (baja o correo sin
  /// confirmar). El router lo lee para llevar a la pantalla que corresponde y
  /// el login para explicar el rechazo. Se limpia al reintentar el acceso.
  AccessBlock? blockedAccess;

  /// Correo de la cuenta bloqueada. La sesión ya no existe cuando se muestra la
  /// pantalla de confirmación, así que se conserva aquí para poder reenviar el
  /// correo de confirmación.
  String? blockedEmail;

  bool _authReady = false;
  bool _profileReady = false;
  String? _profileForUserId;

  bool get isLoading => !_authReady || !_profileReady;
  bool get mustChangePassword => profile?.requiresPasswordChange ?? false;

  bool get hasPortalAccess => PortalAccess.allows(profile);

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
      // Rehidratar una sesión guardada NO puede saltarse el gate: una cuenta
      // dada de baja (o con el correo des-confirmado por un reset) tiene que
      // caer aquí igual que en el login.
      await applyAccessGates();
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

  /// Gate de acceso sobre el perfil ya cargado: cuenta desactivada primero,
  /// correo sin confirmar después (`debe_cambiar_password` lo maneja el router
  /// al final, ya con la sesión aceptada). Si la cuenta no puede entrar cierra
  /// la sesión y deja registrado el motivo en [blockedAccess].
  ///
  /// Devuelve null cuando el acceso es válido, o cuando no hay perfil que
  /// evaluar: un perfil ausente (RPC caída, sin fila en `usuarios`) ya lo
  /// rechazan las pantallas de acceso por su cuenta.
  ///
  /// Los defaults tolerantes de [UserProfile] hacen que este gate sea inocuo
  /// mientras la migración de `email_confirmado` no esté desplegada.
  Future<AccessBlock?> applyAccessGates() async {
    final p = profile;
    if (p == null) return null;
    final AccessBlock reason;
    if (!p.isActive) {
      reason = AccessBlock.deactivated;
    } else if (p.hasPendingEmailConfirmation) {
      reason = AccessBlock.emailNotConfirmed;
    } else {
      return null;
    }
    // El correo se guarda ANTES del signOut: después no queda ni perfil ni
    // sesión de donde sacarlo para el reenvío.
    final email = p.email ?? session?.email;
    await signOut();
    blockedAccess = reason;
    blockedEmail = email;
    notifyListeners();
    return reason;
  }

  /// Olvida el último bloqueo (al reintentar el acceso o volver al login).
  void clearAccessBlock() {
    if (blockedAccess == null && blockedEmail == null) return;
    blockedAccess = null;
    blockedEmail = null;
    notifyListeners();
  }

  /// Reenvía el correo de confirmación de la cuenta bloqueada por el gate.
  Future<void> resendEmailConfirmation(String email) async {
    await _port.resendEmailConfirmation(email);
  }

  /// Mensaje para un fallo de [resendEmailConfirmation].
  static String resendConfirmationErrorMessage(Object e) {
    final reason = e is AuthError ? e.reason : AuthFailure.network;
    return switch (reason) {
      AuthFailure.tooManyAttempts =>
        'Demasiadas solicitudes. Espera unos minutos y vuelve a intentar.',
      AuthFailure.network =>
        'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
      _ => 'No pudimos reenviar el correo. Contacta a soporte.',
    };
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

  /// Mensaje para un fallo de [resetPassword]. Solo cubre fallos REALES: que la
  /// cuenta no exista no llega aquí, el backend responde éxito genérico.
  static String resetPasswordErrorMessage(Object e) {
    final reason = e is AuthError ? e.reason : AuthFailure.network;
    return switch (reason) {
      AuthFailure.tooManyAttempts =>
        'Demasiadas solicitudes. Espera unos minutos y vuelve a intentar.',
      AuthFailure.network =>
        'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
      _ => 'No pudimos enviar el correo. Intenta de nuevo o escribe a soporte.',
    };
  }

  /// Mensaje para un fallo de [updatePassword] o [changePassword].
  static String changePasswordErrorMessage(Object e) {
    if (e is WrongCurrentPasswordError) {
      return 'Tu contrasena actual no es correcta.';
    }
    final reason = e is AuthError ? e.reason : AuthFailure.network;
    return switch (reason) {
      AuthFailure.tooManyAttempts =>
        'Demasiados intentos. Espera un minuto y vuelve a probar.',
      AuthFailure.network =>
        'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
      AuthFailure.sessionRevoked =>
        'Tu sesion expiro. Vuelve a iniciar sesion e intenta de nuevo.',
      _ =>
        'No pudimos actualizar la contrasena. Revisa que cumpla los '
            'requisitos e intenta de nuevo.',
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
    // SOLO usuarios del portal. La biometría es un candado local sobre un
    // refresh token guardado, y la sesión de un administrador puede impersonar a
    // cualquier cliente: no se deja detrás de la huella enrolada en un teléfono.
    if (!hasPortalAccess) return false;
    if (!await bio.isSupported()) return false;
    return !await bio.isEnabled();
  }

  /// Canjea el enlace de confirmación y cierra el alta. Deja la sesión abierta
  /// y el perfil ya cargado, para que el guard decida el destino.
  Future<void> confirmEmailLink({
    required String tokenHash,
    required String type,
    String? email,
    String? nombre,
  }) async {
    await _port.confirmEmailLink(tokenHash: tokenHash, type: type);
    final correo = email ?? session?.email;
    if (correo != null && correo.isNotEmpty) {
      // Best-effort: la confirmación en Auth ya ocurrió. Si esto falla, el
      // usuario entra igual; lo que se pierde es el correo de credenciales.
      try {
        await _port.completeRegistration(email: correo, name: nombre);
      } catch (_) {
        // sin ruido: no bloquea el acceso
      }
    }
    await refreshProfile();
  }

  /// Mensaje para un fallo de [confirmEmailLink].
  static String confirmEmailErrorMessage(Object e) {
    final reason = e is AuthError ? e.reason : AuthFailure.network;
    return switch (reason) {
      AuthFailure.network =>
        'No pudimos conectar. Revisa tu conexion e intenta de nuevo.',
      _ =>
        'El enlace vencio o ya se uso (dura 24 horas). Pide uno nuevo desde '
            '"¿Olvidaste tu contrasena?".',
    };
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
    try {
      await _port.signOut();
    } catch (_) {
      // Sin red el cierre en el servidor falla. El estado local se limpia
      // igual: ni el gate de cuenta ni un logout pueden quedarse a medias por
      // un error de conexión y dejar al usuario dentro.
    }
    locked = false;
    profile = null;
    // La sesión se limpia AQUÍ y no solo en el listener: en el arranque en frío
    // el gate puede cerrar la sesión antes de que `_sub` exista, y con `session`
    // desactualizada el router creería que sigue habiendo sesión válida.
    session = null;
    _profileForUserId = null;
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

/// Se enciende al terminar el cambio de contraseña temporal, que cierra la
/// sesión a propósito; el login lo lee para confirmar el cambio y lo apaga al
/// reintentar. Mismo mecanismo que [inactivityLogoutProvider].
final passwordChangedProvider = StateProvider<bool>((ref) => false);
