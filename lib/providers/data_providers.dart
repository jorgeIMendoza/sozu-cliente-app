import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/api_client.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';

/// Providers transversales (no atados a una hoja de `client`): identidad de la
/// sesion y version gate. Los datos del cliente viven en
/// `features/client/<hoja>/providers/`.

/// Id del usuario autenticado. `Provider` solo propaga cuando el
/// valor cambia (==), así los providers de datos solo se refetchean al
/// cambiar realmente de usuario (no en cada notify del perfil/token).
final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).session?.userId;
});

/// "Version gate" nativo: versión mínima/sugerida + URLs de store. No depende
/// de la sesión (anon key, funciona pre-login). Ante cualquier error de
/// red/backend devuelve null => la app NO gatea (nunca bloquea por fallo).
final appVersionGateProvider = FutureProvider<AppVersionInfo?>((ref) async {
  try {
    return await fetchAppVersion();
  } catch (_) {
    return null;
  }
});
