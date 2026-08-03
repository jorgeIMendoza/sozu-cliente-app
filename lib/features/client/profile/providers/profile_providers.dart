import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/profile/adapters/profile_adapter.dart';
import 'package:sozu_cliente_app/features/client/profile/ports/profile_port.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';

/// Puerto de perfil. Se reconstruye al cambiar la sesion o el cliente
/// impersonado, lo que invalida en cascada los providers de datos de la hoja.
final profilePortProvider = Provider<ProfilePort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return ProfileAdapter(impersonate: imp.clientId);
});

/// Perfil completo del cliente.
final profileProvider = FutureProvider<ClientePerfil>(
  (ref) => ref.watch(profilePortProvider).profile(),
);
