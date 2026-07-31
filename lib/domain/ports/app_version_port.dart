import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/domain/api_error.dart';

/// Version gate del app nativo: version minima y sugerida mas URLs de store.
///
/// Unico puerto que funciona pre-login (llave anonima, sin JWT ni
/// impersonacion). Lanza [ApiError]; ante cualquier fallo el consumidor degrada
/// a "sin gate" y nunca bloquea al usuario.
abstract interface class AppVersionPort {
  /// Version minima y sugerida publicadas, con las URLs de store.
  Future<AppVersionInfo> version();
}
