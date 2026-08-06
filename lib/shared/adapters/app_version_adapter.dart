import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/adapters/anon_function.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/ports/app_version_port.dart';

/// Implementacion actual de [AppVersionPort] sobre la edge function
/// `cliente-app-version`: la unica frontera donde se conocen sus tipos.
class AppVersionAdapter implements AppVersionPort {
  /// Version minima/sugerida y URLs de tienda.
  ///
  /// Va por [invokeAnonFunction] y NO por `functions.invoke`: esta llamada
  /// corre sin sesion (el gate decide antes del login) y ese cliente manda la
  /// llave anonima en `apikey` Y en `Authorization`, que el gateway nuevo
  /// rechaza con 401 antes de ejecutar nada.
  @override
  Future<AppVersionInfo> version() async {
    final AnonFunctionResponse res;
    try {
      res = await invokeAnonFunction('cliente-app-version');
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
    if (res.status < 200 || res.status >= 300) {
      throw ApiError(res.status, '${res.body['error'] ?? 'internal_error'}');
    }
    return AppVersionInfo.fromJson(res.body);
  }
}
