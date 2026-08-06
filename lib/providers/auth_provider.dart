import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/biometric_service.dart';
import '../core/portal_tracking.dart';
import '../core/push_service.dart';
import '../data/api_client.dart';

/// Estado de sesión/JWT + perfil (espejo de src/providers/AuthProvider.tsx).
/// - Perfil vía RPC SECURITY DEFINER `get_current_user_profile` (por auth.uid()).
///   NO se consultan tablas directamente.
/// - `mustChangePassword` fuerza el cambio de contraseña temporal.
/// - El listener de onAuthStateChange solo actualiza la sesión; el perfil se
///   carga aparte (mismo patrón anti-deadlock que el app RN).
/// - [AuthController.aplicarGatesDeAcceso] cierra la sesión de las cuentas que
///   no pueden entrar (dadas de baja o con el correo sin confirmar).

class WrongCurrentPasswordError implements Exception {}

/// Motivo por el que una cuenta autenticada NO puede usar la app. El orden de
/// los valores es el del gate: primero la baja, después el correo.
enum AccesoBloqueado {
  /// `usuarios.activo = false`.
  desactivada,

  /// Rol de portal (`roles.requiere_confirmacion_email`) cuyo correo todavía no
  /// está verificado (`usuarios.email_confirmado = false`).
  emailNoConfirmado,
}

/// Texto que se muestra al usuario para cada motivo de bloqueo.
String mensajeAccesoBloqueado(AccesoBloqueado motivo) => switch (motivo) {
  AccesoBloqueado.desactivada =>
    'Tu cuenta está desactivada. Contacta al administrador para reactivarla.',
  AccesoBloqueado.emailNoConfirmado =>
    'Confirma tu correo para entrar. Revisa tu bandeja de entrada.',
};

class UserProfile {
  final String? nombre;
  final String? email;
  final String? rolNombre;
  final int? idPersona;
  final bool debeCambiarPassword;

  /// roles.administrar_app_clientes: habilita el acceso administrador del app
  /// (selector de clientes, envío de avisos, configuración).
  final bool administrarAppClientes;

  /// usuarios.activo. La RPC dejó de filtrar por `activo = TRUE` (antes una
  /// cuenta dada de baja devolvía cero filas), así que el gate vive aquí.
  final bool activo;

  /// usuarios.email_confirmado: si el correo ya fue verificado.
  final bool emailConfirmado;

  /// roles.requiere_confirmacion_email: true en los roles de portal (Cliente
  /// incluido). Los roles internos entran sin confirmar el correo.
  final bool requiereConfirmacionEmail;

  const UserProfile({
    this.nombre,
    this.email,
    this.rolNombre,
    this.idPersona,
    this.debeCambiarPassword = false,
    this.administrarAppClientes = false,
    this.activo = true,
    this.emailConfirmado = true,
    this.requiereConfirmacionEmail = false,
  });

  /// El rol exige confirmar el correo y todavía no está confirmado.
  bool get emailPendienteDeConfirmar =>
      requiereConfirmacionEmail && !emailConfirmado;
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

  /// Motivo por el que el gate de cuenta cerró la sesión (baja o correo sin
  /// confirmar). El router lo lee para llevar a la pantalla que corresponde y
  /// el login para explicar el rechazo. Se limpia al reintentar el acceso.
  AccesoBloqueado? bloqueoAcceso;

  /// Correo de la cuenta bloqueada. La sesión ya no existe cuando se muestra la
  /// pantalla de confirmación, así que se conserva aquí para poder reenviar el
  /// correo de confirmación.
  String? emailBloqueado;

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
      // Rehidratar una sesión guardada NO puede saltarse el gate: una cuenta
      // dada de baja (o con el correo des-confirmado por un reset) tiene que
      // caer aquí igual que en el login.
      await aplicarGatesDeAcceso();
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
        // Defaults TOLERANTES: mientras la migración que agrega estas columnas
        // no esté desplegada la RPC no las devuelve (llegan null) y nadie debe
        // quedar bloqueado por eso. `!= false` = "true salvo negativa expresa".
        activo: row['activo'] != false,
        emailConfirmado: row['email_confirmado'] != false,
        requiereConfirmacionEmail: row['requiere_confirmacion_email'] == true,
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

  /// Gate de acceso sobre el perfil ya cargado: cuenta desactivada primero,
  /// correo sin confirmar después (`debe_cambiar_password` lo maneja el router
  /// al final, ya con la sesión aceptada). Si la cuenta no puede entrar cierra
  /// la sesión y deja registrado el motivo en [bloqueoAcceso].
  ///
  /// Devuelve null cuando el acceso es válido, o cuando no hay perfil que
  /// evaluar: un perfil ausente (RPC caída, sin fila en `usuarios`) ya lo
  /// rechazan las pantallas de acceso por su cuenta.
  ///
  /// Los defaults tolerantes de [UserProfile] hacen que este gate sea inocuo
  /// mientras la migración de `email_confirmado` no esté desplegada.
  Future<AccesoBloqueado?> aplicarGatesDeAcceso() async {
    final p = profile;
    if (p == null) return null;
    final AccesoBloqueado motivo;
    if (!p.activo) {
      motivo = AccesoBloqueado.desactivada;
    } else if (p.emailPendienteDeConfirmar) {
      motivo = AccesoBloqueado.emailNoConfirmado;
    } else {
      return null;
    }
    // El correo se guarda ANTES del signOut: después no queda ni perfil ni
    // sesión de donde sacarlo para el reenvío.
    final email = p.email ?? session?.user.email;
    await signOut();
    bloqueoAcceso = motivo;
    emailBloqueado = email;
    notifyListeners();
    return motivo;
  }

  /// Olvida el último bloqueo (al reintentar el acceso o volver al login).
  void limpiarBloqueo() {
    if (bloqueoAcceso == null && emailBloqueado == null) return;
    bloqueoAcceso = null;
    emailBloqueado = null;
    notifyListeners();
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

  /// Recuperación de contraseña self-service.
  ///
  /// Va por la Edge Function `reset-user-password` en MODO PÚBLICO, no por
  /// `auth.resetPasswordForEmail`: ese atajo se salta el flujo de la
  /// plataforma. La función repone la contraseña temporal, DES-CONFIRMA el
  /// correo y manda el enlace de confirmación; al abrirlo el usuario confirma y
  /// define su contraseña, y vuelve a la app con `debe_cambiar_password` (que
  /// el router ya maneja llevándolo a /change-password).
  ///
  /// La respuesta es SIEMPRE genérica por diseño (anti-enumeración de correos):
  /// aquí se ignora a propósito y la UI muestra el mismo mensaje de éxito
  /// exista o no la cuenta.
  Future<void> resetPassword(String email) async {
    await invokeAnonFunction(
      'reset-user-password',
      body: {'email': email.trim().toLowerCase()},
    );
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
    try {
      await _sb.auth.signOut();
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
