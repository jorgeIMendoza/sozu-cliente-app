import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion actual de [AuthPort] sobre Supabase (GoTrue + RPC): la unica
/// frontera donde se conocen sus tipos (`Session` -> [AuthSession],
/// `AuthException` -> [AuthError]). Si el backend cambia, se reescribe este
/// archivo y nada mas.
class AuthAdapter implements AuthPort {
  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  @override
  AuthSession? get currentSession => _toDomain(_sb.auth.currentSession);

  @override
  Stream<AuthSession?> get sessionChanges =>
      _sb.auth.onAuthStateChange.map((data) => _toDomain(data.session));

  @override
  Future<UserProfile?> profile() async {
    try {
      final data = await _sb.rpc('get_current_user_profile');
      final rows = data is List ? data : [data];
      if (rows.isEmpty || rows.first == null) return null;
      final row = Map<String, dynamic>.from(rows.first as Map);
      // Mapper key-del-backend -> campo del dominio: las keys son del RPC y se
      // quedan en espanol; si el backend cambia una, se toca esta linea.
      return UserProfile(
        displayName: row['nombre'] as String?,
        email: row['email'] as String?,
        roleName: row['rol_nombre'] as String?,
        roleId: row['rol_id'] is int
            ? row['rol_id'] as int
            : int.tryParse('${row['rol_id']}'),
        // Ausente hasta que el RPC agregue la columna: se lee como false y el
        // acceso queda igual que antes (solo rol Cliente).
        isBuyer: row['es_comprador'] == true,
        personId: row['id_persona'] is int
            ? row['id_persona'] as int
            : int.tryParse('${row['id_persona']}'),
        requiresPasswordChange: row['debe_cambiar_password'] == true,
        canManageClientApp: row['administrar_app_clientes'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final Session? session;
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      session = res.session;
    } on AuthException catch (e) {
      throw AuthError(_signInFailure(e));
    } catch (_) {
      // Sin AuthException no hubo respuesta del servidor: fue la red.
      throw AuthError(AuthFailure.network);
    }
    final s = _toDomain(session);
    if (s == null) throw AuthError(AuthFailure.unknown);
    return s;
  }

  @override
  Future<bool> verifyPassword(String password) async {
    final email = _sb.auth.currentSession?.user.email;
    if (email == null || email.isEmpty) return false;
    try {
      // Re-login real: ROTA el refresh token y dispara [sessionChanges]. Los
      // listeners cuentan con ello (mismo usuario, solo re-persisten el token).
      await _sb.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException {
      return false;
    } catch (_) {
      throw AuthError(AuthFailure.network);
    }
  }

  @override
  Future<AuthSession> restoreSession(String refreshToken) async {
    try {
      final res = await _sb.auth.setSession(refreshToken);
      final s = _toDomain(res.session);
      if (s == null) throw AuthError(AuthFailure.unknown);
      return s;
    } on AuthError {
      rethrow;
    } on AuthRetryableFetchException {
      throw AuthError(AuthFailure.network);
    } on AuthException {
      throw AuthError(AuthFailure.sessionRevoked);
    } catch (_) {
      throw AuthError(AuthFailure.unknown);
    }
  }

  @override
  Future<void> signOut() => _sb.auth.signOut();

  /// Nombre de la Edge Function de restablecimiento. NO se usa el `/recover`
  /// nativo de GoTrue: el correo transaccional del proyecto sale por Postmark
  /// desde esta función, y GoTrue no tiene SMTP configurado (su envío se pierde
  /// sin dejar rastro ni en Postmark ni en `auth.users.recovery_sent_at`).
  static const _resetFunction = 'reset-user-password';

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _sb.functions.invoke(
        _resetFunction,
        body: {'email': email.trim().toLowerCase()},
      );
    } on FunctionException catch (e) {
      // La función responde 200 genérico exista o no la cuenta (anti-
      // enumeración): un status de error aquí es fallo real de servidor.
      throw AuthError(
        e.status == 429 ? AuthFailure.tooManyAttempts : AuthFailure.unknown,
      );
    } catch (_) {
      throw AuthError(AuthFailure.network);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _sb.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthRetryableFetchException {
      throw AuthError(AuthFailure.network);
    } on AuthException {
      throw AuthError(AuthFailure.unknown);
    } catch (_) {
      throw AuthError(AuthFailure.network);
    }
  }

  /// Tipos que GoTrue puede haber emitido para un enlace de confirmacion. El
  /// `type` de la URL no siempre coincide con el token real, y declarar el que
  /// no es responde 403 sin consumirlo: por eso se reintenta con el contrario.
  static const _tiposEnlace = {
    'magiclink': OtpType.magiclink,
    'signup': OtpType.signup,
    'invite': OtpType.invite,
    'recovery': OtpType.recovery,
    'email': OtpType.email,
    'email_change': OtpType.emailChange,
  };

  @override
  Future<AuthSession> confirmEmailLink({
    required String tokenHash,
    required String type,
  }) async {
    final primero = _tiposEnlace[type] ?? OtpType.magiclink;
    final alterno = switch (primero) {
      OtpType.magiclink => OtpType.signup,
      OtpType.signup => OtpType.magiclink,
      _ => null,
    };
    for (final t in [primero, if (alterno != null) alterno]) {
      try {
        final res = await _sb.auth.verifyOTP(type: t, tokenHash: tokenHash);
        final s = _toDomain(res.session);
        if (s != null) return s;
      } on AuthRetryableFetchException {
        throw AuthError(AuthFailure.network);
      } on AuthException {
        continue; // tipo equivocado: el token sigue vivo, se prueba el otro
      }
    }
    throw AuthError(AuthFailure.sessionRevoked);
  }

  @override
  Future<void> completeRegistration({
    required String email,
    String? name,
  }) async {
    try {
      await _sb.functions.invoke(
        'post-confirmacion-registro',
        body: {'email': email, if (name != null) 'nombre': name},
      );
    } on FunctionException catch (e) {
      throw ApiError(e.status, 'post_confirmacion_failed');
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  @override
  Future<void> markPasswordChanged() async {
    try {
      await _sb.rpc('mark_password_changed');
    } catch (_) {
      // Best-effort por contrato: no abortar el cambio de contrasena.
    }
  }

  /// El backend responde 400 tanto para contrasena equivocada como para
  /// usuario inexistente o correo sin confirmar: los tres caen en
  /// [AuthFailure.invalidCredentials] a proposito (no revelar cuentas).
  static AuthFailure _signInFailure(AuthException e) {
    final code = e.code ?? '';
    final status = int.tryParse(e.statusCode ?? '') ?? 0;
    if (status == 429 || code == 'over_request_rate_limit') {
      return AuthFailure.tooManyAttempts;
    }
    if (code == 'email_not_confirmed') return AuthFailure.emailNotConfirmed;
    return AuthFailure.invalidCredentials;
  }

  static AuthSession? _toDomain(Session? s) {
    if (s == null) return null;
    return AuthSession(
      userId: s.user.id,
      email: s.user.email,
      lastSignInAt: DateTime.tryParse(s.user.lastSignInAt ?? ''),
      refreshToken: s.refreshToken,
    );
  }
}
