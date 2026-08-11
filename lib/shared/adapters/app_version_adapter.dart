import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/adapters/anon_function.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/shared/ports/app_version_port.dart';

/// Implementacion actual de [AppVersionPort] sobre la edge function
/// `cliente-app-version`: la unica frontera donde se conocen sus tipos.
class AppVersionAdapter implements AppVersionPort {
  /// Version minima/sugerida y URLs de tienda.
  ///
  /// Va por [invokeAnonFunction] porque corre sin sesion: el gate decide antes
  /// del login. `withAuthorization` es obligatorio aqui: la function NO esta
  /// declarada publica en `config.toml`, asi que con solo `apikey` el gateway
  /// responde 401 y el gate se quedaba ciego en cada arranque.
  @override
  Future<AppVersionInfo> version() async {
    final AnonFunctionResponse res;
    try {
      res = await invokeAnonFunction(
        'cliente-app-version',
        withAuthorization: true,
      );
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
    if (res.status < 200 || res.status >= 300) {
      throw ApiError(res.status, '${res.body['error'] ?? 'internal_error'}');
    }
    return AppVersionInfo.fromJson(res.body);
  }
}
