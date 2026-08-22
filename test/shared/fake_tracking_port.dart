import 'package:sozu_cliente_app/shared/ports/tracking_port.dart';

/// Doble de [TrackingPort] en memoria: sin red, sin Supabase.
/// Se inyecta con `trackingPortProvider.overrideWithValue`.
///
/// No tiene `nextFailure` como los demas dobles a proposito: el puerto real no
/// lanza, porque perder una medicion no puede romper el flujo del usuario. Para
/// simular que no se pudo registrar se pone [nextSessionId] en null.
class FakeTrackingPort implements TrackingPort {
  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Id que devuelve [register]. `null` = no se pudo registrar.
  String? nextSessionId = 'sesion-1';

  String? registeredPortal;
  String? registeredUserAgent;

  @override
  Future<String?> register({
    required String portal,
    required String userAgent,
  }) async {
    log.add('register');
    registeredPortal = portal;
    registeredUserAgent = userAgent;
    return nextSessionId;
  }

  @override
  Future<void> touch(String sessionId) async => log.add('touch:$sessionId');

  @override
  Future<void> close(String sessionId) async => log.add('close:$sessionId');
}
