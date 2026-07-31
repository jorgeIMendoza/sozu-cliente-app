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
      return UserProfile(
        nombre: row['nombre'] as String?,
        email: row['email'] as String?,
        rolNombre: row['rol_nombre'] as String?,
        idPersona: row['id_persona'] is int
            ? row['id_persona'] as int
            : int.tryParse('${row['id_persona']}'),
        debeCambiarPassword: row['debe_cambiar_password'] == true,
        administrarAppClientes: row['administrar_app_clientes'] == true,
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

  @override
  Future<void> sendPasswordReset(String email) =>
      _sb.auth.resetPasswordForEmail(email.trim());

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
