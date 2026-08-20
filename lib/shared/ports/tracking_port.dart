/// Sesion de medicion de uso de un portal ("Uso por portal" en Alta Direccion).
///
/// Tres RPC `SECURITY DEFINER` que ya usan los demas portales. No lanza:
/// perder una medicion NUNCA debe romper el flujo del usuario, asi que un
/// fallo se traga y el siguiente latido reintenta. Por eso es el unico puerto
/// del repo que no propaga `ApiError`.
abstract interface class TrackingPort {
  /// Abre la sesion y devuelve su id, o `null` si no se pudo registrar.
  Future<String?> register({required String portal, required String userAgent});

  /// Latido de actividad. La sesion caduca sola sin el.
  Future<void> touch(String sessionId);

  /// Cierra la sesion. Necesita JWT, asi que va ANTES del signOut.
  Future<void> close(String sessionId);
}
