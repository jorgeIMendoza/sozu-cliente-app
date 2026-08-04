import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/ports/push_port.dart';

/// Doble de [PushPort] en memoria: sin red, sin Supabase, sin FCM.
/// Se inyecta con `pushPortProvider.overrideWithValue`.
class FakePushPort implements PushPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Tokens registrados, token -> plataforma.
  final Map<String, String> tokens = {};

  /// Preferencia de push: sin fila en BD el backend responde true.
  bool storedEnabled = true;

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    _throwIfFailing('registerToken');
    tokens[token] = platform;
  }

  @override
  Future<void> unregisterToken(String token) async {
    _throwIfFailing('unregisterToken');
    tokens.remove(token);
  }

  @override
  Future<bool> enabled() async {
    _throwIfFailing('enabled');
    return storedEnabled;
  }

  @override
  Future<void> setEnabled(bool value) async {
    _throwIfFailing('setEnabled');
    storedEnabled = value;
  }
}
