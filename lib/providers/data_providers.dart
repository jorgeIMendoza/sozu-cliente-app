import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import 'impersonation_provider.dart';

/// Providers de datos (equivalente a los hooks react-query del app RN).
/// FutureProvider cachea hasta invalidar; refresh = ref.invalidate(provider).
/// Cada provider observa la impersonación (solo web/admin): al cambiar de
/// cliente impersonado todos los fetch se re-ejecutan automáticamente.

final clienteResumenProvider = FutureProvider<ClienteResumen>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteResumen(impersonate: imp);
});

final clientePagosProvider = FutureProvider<ClientePagos>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePagos(impersonate: imp);
});

final clientePropiedadesProvider = FutureProvider<ClientePropiedades>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePropiedades(impersonate: imp);
});

final propiedadDetalleProvider = FutureProvider.family<PropiedadDetalle, int>((
  ref,
  id,
) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchPropiedadDetalle(id, impersonate: imp);
});

final clientePerfilProvider = FutureProvider<ClientePerfil>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePerfil(impersonate: imp);
});

final clienteDocumentosProvider = FutureProvider<ClienteDocumentos>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteDocumentos(impersonate: imp);
});

final clienteNotificacionesProvider = FutureProvider<ClienteNotificaciones>((
  ref,
) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteNotificaciones(impersonate: imp);
});

/// Clientes para el selector de impersonación (no depende del target).
final adminClientesProvider = FutureProvider<AdminClientes>(
  (ref) => fetchAdminClientes(),
);

/// Invalida todos los datos del cliente (p.ej. al cerrar sesión).
void invalidateAllData(Ref ref) {
  ref.invalidate(clienteResumenProvider);
  ref.invalidate(clientePagosProvider);
  ref.invalidate(clientePropiedadesProvider);
  ref.invalidate(propiedadDetalleProvider);
  ref.invalidate(clientePerfilProvider);
  ref.invalidate(clienteDocumentosProvider);
  ref.invalidate(clienteNotificacionesProvider);
}
