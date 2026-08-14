import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/shared/adapters/app_version_adapter.dart';
import 'package:sozu_cliente_app/shared/adapters/push_adapter.dart';
import 'package:sozu_cliente_app/shared/ports/app_version_port.dart';
import 'package:sozu_cliente_app/shared/ports/push_port.dart';

/// Providers transversales (no atados a una hoja de `client`): identidad de la
/// sesion, push y version gate. Los datos del cliente viven en
/// `features/client/<hoja>/providers/`.

/// Id del usuario autenticado. `Provider` solo propaga cuando el valor cambia
/// (==), asi los providers de datos solo se refetchean al cambiar realmente de
/// usuario (no en cada notify del perfil/token).
final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).session?.userId;
});

/// Puerto de push. El default es el adaptador real, la unica composicion que
/// existe en produccion; los tests lo sobreescriben con un doble.
/// No se reconstruye con la impersonacion: el token es del dispositivo.
final pushPortProvider = Provider<PushPort>((ref) => PushAdapter());

/// Puerto del version gate. No depende de la sesion (llave anonima).
final appVersionPortProvider = Provider<AppVersionPort>(
  (ref) => AppVersionAdapter(),
);

/// "Version gate" nativo: version minima/sugerida + URLs de store. Ante
/// cualquier error de red/backend devuelve null => la app NO gatea (nunca
/// bloquea por fallo).
///
/// El fallo se imprime porque tragarlo entero ya costo caro: la 1.0.3 llamaba
/// a la function sin `Authorization`, el gateway respondia 401 y el gate
/// quedaba MUDO - ni aviso ni forzado - sin ninguna senal de que estaba roto.
final appVersionGateProvider = FutureProvider<AppVersionInfo?>((ref) async {
  try {
    return await ref.watch(appVersionPortProvider).version();
  } catch (e) {
    debugPrint('[version-gate] sin config, la app no gatea: $e');
    return null;
  }
});
