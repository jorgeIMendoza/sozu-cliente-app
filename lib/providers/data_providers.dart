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

final clienteProductosProvider = FutureProvider<ClienteProductos>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteProductos(impersonate: imp);
});

final clientePerfilProvider = FutureProvider<ClientePerfil>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePerfil(impersonate: imp);
});

final clienteDocumentosProvider = FutureProvider<ClienteDocumentos>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteDocumentos(impersonate: imp);
});

/// Expediente de identidad (tarjeta del Perfil + pantalla Expediente).
final clienteExpedienteProvider = FutureProvider<ClienteExpediente>((ref) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteExpediente(impersonate: imp);
});

final clienteNotificacionesProvider = FutureProvider<ClienteNotificaciones>((
  ref,
) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteNotificaciones(impersonate: imp);
});

/// Estado de cuenta por propiedad (id = cuenta de cobranza).
final estadoCuentaProvider = FutureProvider.family<EstadoCuenta, int>((
  ref,
  idCuenta,
) {
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchEstadoCuenta(idCuenta, impersonate: imp);
});

/// Clientes para el selector de impersonación (no depende del target).
final adminClientesProvider = FutureProvider<AdminClientes>(
  (ref) => fetchAdminClientes(),
);

/// Proyectos SOZU para el filtro "Ver como" del selector de impersonación
/// (mismo catálogo que los avisos: proyectos activos comercializados).
final adminProyectosProvider = FutureProvider<List<CatalogoItem>>(
  (ref) => fetchAvisosProyectos(),
);

/// Dueños/copropietarios de una unidad (proyecto + número de propiedad) para
/// el filtro "Ver como". Key = record (idProyecto, numero).
final adminPropietariosProvider = FutureProvider.autoDispose
    .family<List<AdminCliente>, ({int idProyecto, String numero})>(
      (ref, q) => fetchAdminPropietarios(
        idProyecto: q.idProyecto,
        numeroPropiedad: q.numero,
      ),
    );

/// Invalida todos los datos del cliente (p.ej. al cerrar sesión).
void invalidateAllData(Ref ref) {
  ref.invalidate(clienteResumenProvider);
  ref.invalidate(clientePagosProvider);
  ref.invalidate(clientePropiedadesProvider);
  ref.invalidate(clienteProductosProvider);
  ref.invalidate(propiedadDetalleProvider);
  ref.invalidate(clientePerfilProvider);
  ref.invalidate(clienteDocumentosProvider);
  ref.invalidate(clienteExpedienteProvider);
  ref.invalidate(clienteNotificacionesProvider);
}
