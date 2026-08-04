import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/home/adapters/home_adapter.dart';
import 'package:sozu_cliente_app/features/client/home/ports/home_port.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';

/// Puerto de inicio. Se reconstruye al cambiar la sesion o el cliente
/// impersonado, lo que invalida en cascada los providers de datos de la hoja
/// (el keying de cache que antes repetia cada FutureProvider).
final homePortProvider = Provider<HomePort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return HomeAdapter(impersonate: imp.clientId);
});

/// Resumen del tablero de inicio: financiero, actividad y pendientes.
final summaryProvider = FutureProvider<ClienteResumen>(
  (ref) => ref.watch(homePortProvider).summary(),
);

/// Menu lateral del portal (submenus activos/permitidos). Si el fetch falla,
/// la UI cae a su menu hardcodeado.
final menuProvider = FutureProvider<List<MenuItemDto>>(
  (ref) => ref.watch(homePortProvider).menu(),
);

/// Notificaciones del cliente y su conteo de no leidas.
final notificationsProvider = FutureProvider<ClienteNotificaciones>(
  (ref) => ref.watch(homePortProvider).notifications(),
);
