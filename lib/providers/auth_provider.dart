import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _authReady = true;
    if (session != null) {
      await refreshProfile();
    }
    _profileReady = true;
    notifyListeners();

    _sub = _sb.auth.onAuthStateChange.listen((data) {
      final next = data.session;
      final changedUser = next?.user.id != session?.user.id;
      session = next;
      if (next == null) {
        profile = null;
        _profileForUserId = null;
        _profileReady = true;
        notifyListeners();
      } else if (changedUser || _profileForUserId != next.user.id) {
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
    await _sb.auth.signInWithPassword(email: email.trim(), password: password);
    await refreshProfile();
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

  Future<void> signOut() async {
    // El token push NO se da de baja: las notificaciones siguen llegando
    // deslogeado (el cierre por inactividad no debe cortar los push). Solo
    // se olvida el registro local para re-registrar si entra otro cliente.
    PushService.olvidarSesion();
    // Cierra la sesión de mediciones ANTES de perder el JWT.
    await PortalTracking.cerrar();
    await _sb.auth.signOut();
    profile = null;
    notifyListeners();
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
