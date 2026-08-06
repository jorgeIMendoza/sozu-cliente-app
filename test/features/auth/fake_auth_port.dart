import 'dart:async';

import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [AuthPort] con estado en memoria: sin red, sin Supabase, sin
/// canales de plataforma. Se inyecta con `authPortProvider.overrideWithValue`.
class FakeAuthPort implements AuthPort {
  FakeAuthPort({this.profileRow});

  /// Credenciales que aceptan [signIn] y [verifyPassword].
  String email = 'cliente@sozu.com';
  String password = 'secreta123';

  /// Lo que devuelve [profile]; null simula "sin fila para su identidad".
  UserProfile? profileRow;

  /// Fallo forzado de la PRÓXIMA operación de sesión; se consume al usarse.
  AuthFailure? nextFailure;

  /// Único refresh token que acepta [restoreSession]. Rota en cada login,
  /// como el backend real.
  String validRefreshToken = 'refresh-token-de-prueba';

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  AuthSession? _session;
  final _changes = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> get sessionChanges => _changes.stream;

  /// Fija la sesión y la emite, como haría el listener de onAuthStateChange.
  void emitSession(AuthSession? session) {
    _session = session;
    _changes.add(session);
  }

  AuthSession _newSession() => AuthSession(
    userId: 'user-de-prueba',
    email: email,
    lastSignInAt: DateTime.utc(2026, 7, 31, 12),
    refreshToken: validRefreshToken,
  );

  AuthFailure? _consumeFailure() {
    final f = nextFailure;
    nextFailure = null;
    return f;
  }

  @override
  Future<UserProfile?> profile() async {
    log.add('profile');
    return profileRow;
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    log.add('signIn');
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
    if (email.trim() != this.email || password != this.password) {
      throw AuthError(AuthFailure.invalidCredentials);
    }
    validRefreshToken = 'rotado-$validRefreshToken';
    final s = _newSession();
    emitSession(s);
    return s;
  }

  @override
  Future<bool> verifyPassword(String password) async {
    log.add('verifyPassword');
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
    return password == this.password;
  }

  @override
  Future<AuthSession> restoreSession(String refreshToken) async {
    log.add('restoreSession');
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
    if (refreshToken != validRefreshToken) {
      throw AuthError(AuthFailure.sessionRevoked);
    }
    validRefreshToken = 'rotado-$validRefreshToken';
    final s = _newSession();
    emitSession(s);
    return s;
  }

  @override
  Future<void> signOut() async {
    log.add('signOut');
    emitSession(null);
  }

  /// Tokens que [confirmEmailLink] acepta. Cualquier otro se trata como
  /// vencido o ya usado, que es el caso real del enlace de un solo uso.
  final Set<String> validTokens = {'token-bueno'};

  /// Correos a los que [completeRegistration] fue llamado, en orden.
  final List<String> completedRegistrations = [];

  @override
  Future<AuthSession> confirmEmailLink({
    required String tokenHash,
    required String type,
  }) async {
    log.add('confirmEmailLink:$type');
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
    if (!validTokens.remove(tokenHash)) {
      throw AuthError(AuthFailure.sessionRevoked);
    }
    final s = _newSession();
    emitSession(s);
    return s;
  }

  @override
  Future<void> completeRegistration({
    required String email,
    String? name,
  }) async {
    log.add('completeRegistration');
    completedRegistrations.add(email);
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    log.add('sendPasswordReset');
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    log.add('updatePassword');
    final failure = _consumeFailure();
    if (failure != null) throw AuthError(failure);
    password = newPassword;
  }

  @override
  Future<void> markPasswordChanged() async {
    log.add('markPasswordChanged');
    profileRow = profileRow == null
        ? null
        : UserProfile(
            displayName: profileRow!.displayName,
            email: profileRow!.email,
            roleName: profileRow!.roleName,
            personId: profileRow!.personId,
            requiresPasswordChange: false,
            canManageClientApp: profileRow!.canManageClientApp,
          );
  }

  void dispose() {
    _changes.close();
  }
}
