import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/ports/app_version_port.dart';

/// Doble de [AppVersionPort] en memoria: sin red, sin Supabase.
/// Se inyecta con `appVersionPortProvider.overrideWithValue`.
class FakeAppVersionPort implements AppVersionPort {
  /// Fallo forzado de la PRÓXIMA llamada; se consume al usarse.
  ApiError? nextFailure;

  /// Veces que se pidió la versión.
  int calls = 0;

  /// Lo que devuelve [version] mientras no haya fallo forzado.
  AppVersionInfo stored;

  FakeAppVersionPort({AppVersionInfo? info})
    : stored = info ?? const AppVersionInfo(minVersion: '1.0.0');

  @override
  Future<AppVersionInfo> version() async {
    calls++;
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
    return stored;
  }
}
