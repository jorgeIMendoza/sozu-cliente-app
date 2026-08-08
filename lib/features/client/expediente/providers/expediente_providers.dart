import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/expediente/adapters/expediente_adapter.dart';
import 'package:sozu_cliente_app/features/client/expediente/ports/expediente_port.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';

/// Puerto del expediente. Se reconstruye al cambiar la sesion o el cliente
/// impersonado, lo que invalida en cascada los providers de datos.
final expedientePortProvider = Provider<ExpedientePort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return ExpedienteAdapter(impersonate: imp.clientId);
});

/// Expediente del cliente (tarjeta del Perfil + pantalla Expediente).
final identityFileProvider = FutureProvider<ClienteExpediente>(
  (ref) => ref.watch(expedientePortProvider).identityFile(),
);
