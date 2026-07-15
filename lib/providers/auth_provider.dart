import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/biometric_service.dart';
import '../core/portal_tracking.dart';
import '../core/push_service.dart';

/// Estado de sesión/JWT + perfil (espejo de src/providers/AuthProvider.tsx).
/// - Perfil vía RPC SECURITY DEFINER `get_current_user_profile` (por auth.uid()).
///   NO se consultan tablas directamente.
/// - `mustChangePassword` fuerza el cambio de contraseña temporal.
/// - El listener de onAuthStateChange solo actualiza la sesión; el perfil se
///   carga aparte (mismo patrón anti-deadlock que el app RN).

class WrongCurrentPasswordError implements Exception {}

class UserProfile {
  final String? nombre;
  final String? email;
  final String? rolNombre;
  final int? idPersona;
  final bool debeCambiarPassword;

  /// roles.administrar_app_clientes: habilita el acceso administrador del app
  /// (selector de clientes, envío de avisos, configuración).
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

class AuthController extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;

  Session? session;
  UserProfile? profile;

  /// true mientras el login valida el rol tras autenticar; el router no debe
  /// sacar al usuario de /login (evita que el signOut por rol inválido borre
  /// el mensaje de error al desmontar la pantalla).
  bool loginEnCurso = false;

  /// Candado biométrico: la sesión de Supabase sigue viva (nunca se revocó)
  /// pero la app se comporta como deslogueada hasta desbloquear con
  /// huella/rostro o contraseña. El router lo trata como "sin sesión".
  bool locked = false;

  bool _authReady = false;
  bool _profileReady = false;
  String? _profileForUserId;

  bool get isLoading => !_authReady || !_profileReady;
  bool get mustChangePassword => profile?.debeCambiarPassword ?? false;
  bool get isCliente => profile?.rolNombre == 'Cliente';

  /// Acceso administrador del app: por permiso del rol (no por nombre).
  bool get isSuperAdmin => profile?.administrarAppClientes ?? false;

  AuthController() {
    _init();
  }

  Future<void> _init() async {
    session = _sb.auth.currentSession;
    // Arranque en frío con candado activo: la app abre bloqueada (login con
    // prompt biométrico) aunque la sesión siga viva por debajo.
    if (session != null &&
        await BiometricService.instance.habilitada() &&
        await BiometricService.instance.bloqueada()) {
      locked = true;
    }
    _authReady = true;
    if (session != null && !locked) {
      await refreshProfile();
    }
    _profileReady = true;
    notifyListeners();

    _sub = _sb.auth.onAuthStateChange.listen((data) {
      final next = data.session;
      final changedUser = next?.user.id != session?.user.id;
      session = next;
      // Supabase ROTA el refresh token en cada signedIn/tokenRefreshed: si el
      // login biométrico está habilitado hay que re-guardar el token nuevo o
      // el guardado queda invalidado.
      if (next != null) {
        unawaited(BiometricService.instance.persistirSesion(next));
      }
      if (next == null) {
        profile = null;
        _profileForUserId = null;
        _profileReady = true;
        notifyListeners();
      } else if (!locked && (changedUser || _profileForUserId != next.user.id)) {
        // Bloqueada: no cargar perfil (se carga al desbloquear).
        _loadProfileFor(next.user.id);
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

  /// Lee el perfil vía RPC (rol + flag de cambio de contraseña).
  Future<UserProfile?> refreshProfile() async {
    try {
      final data = await _sb.rpc('get_current_user_profile');
      final rows = data is List ? data : [data];
      if (rows.isEmpty || rows.first == null) {
        profile = null;
        notifyListeners();
        return null;
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      profile = UserProfile(
        nombre: row['nombre'] as String?,
        email: row['email'] as String?,
        rolNombre: row['rol_nombre'] as String?,
        idPersona: row['id_persona'] is int
            ? row['id_persona'] as int
            : int.tryParse('${row['id_persona']}'),
        debeCambiarPassword: row['debe_cambiar_password'] == true,
        administrarAppClientes: row['administrar_app_clientes'] == true,
      );
      _profileForUserId = session?.user.id;
      notifyListeners();
      return profile;
    } catch (_) {
      profile = null;
      notifyListeners();
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    final res = await _sb.auth
        .signInWithPassword(email: email.trim(), password: password);
    // Entrar por contraseña también levanta el candado biométrico.
    locked = false;
    await BiometricService.instance.desmarcarBloqueada();
    // Si la biometría ya está habilitada, refresca el token guardado con el
    // de esta sesión (además del listener, para no depender de su orden).
    await BiometricService.instance.persistirSesion(res.session);
    await refreshProfile();
  }

  /// Hook para el login: ofrecer activar biometría tras un login por
  /// contraseña (solo móvil soportado, aún no habilitada y sin "Ahora no"
  /// previo en esta ejecución).
  Future<bool> debeOfrecerBiometria() async {
    final bio = BiometricService.instance;
    if (bio.ofertaRechazada) return false;
    if (!await bio.soportado()) return false;
    return !await bio.habilitada();
  }

  Future<void> resetPassword(String email) async {
    await _sb.auth.resetPasswordForEmail(email.trim());
  }

  /// Cambio forzado (contraseña temporal): updateUser + mark_password_changed.
  Future<void> updatePassword(String newPassword) async {
    await _sb.auth.updateUser(UserAttributes(password: newPassword));
    await _sb.rpc('mark_password_changed');
    await refreshProfile();
  }

  /// Cambio voluntario: verifica la contraseña actual re-autenticando.
  Future<void> changePassword(String current, String next) async {
    final email = session?.user.email ?? profile?.email;
    if (email == null || email.isEmpty) throw WrongCurrentPasswordError();
    try {
      await _sb.auth.signInWithPassword(email: email, password: current);
    } on AuthException {
      throw WrongCurrentPasswordError();
    }
    await _sb.auth.updateUser(UserAttributes(password: next));
    try {
      await _sb.rpc('mark_password_changed');
    } catch (_) {
      // no bloquear el cambio si el RPC falla; el flag se limpia luego
    }
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
    await _sb.auth.signOut();
    locked = false;
    profile = null;
    notifyListeners();
  }

  /// Cierre iniciado por el usuario o por inactividad. Con biometría
  /// habilitada NO se toca el servidor: gotrue revoca la sesión actual en
  /// cualquier signOut (aun scope local), lo que invalidaría el refresh
  /// token guardado y mataría el acceso con huella. En su lugar la app se
  /// BLOQUEA (candado persistido): la sesión sigue viva por debajo y la
  /// huella/rostro (o la contraseña) la desbloquea.
  Future<void> lockOrSignOut() async {
    if (session != null && await BiometricService.instance.habilitada()) {
      PushService.olvidarSesion();
      await PortalTracking.cerrar();
      await BiometricService.instance.marcarBloqueada();
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
  Future<bool> unlockConBiometria() async {
    if (!locked || session == null) return false;
    if (!await BiometricService.instance.autenticar()) return false;
    await BiometricService.instance.desmarcarBloqueada();
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

final authProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController();
});

/// Se enciende cuando InactivityWatcher cierra la sesión por inactividad;
/// el login lo lee para explicar el cierre y lo apaga al reintentar.
final inactivityLogoutProvider = StateProvider<bool>((ref) => false);
