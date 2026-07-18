import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import 'auth_provider.dart';
import 'impersonation_provider.dart';

/// Providers de datos (equivalente a los hooks react-query del app RN).
/// FutureProvider cachea hasta invalidar; refresh = ref.invalidate(provider).
/// Cada provider observa la impersonación (solo web/admin): al cambiar de
/// cliente impersonado todos los fetch se re-ejecutan automáticamente.
///
/// Además observan el usuario autenticado (`authUserIdProvider`): estos
/// providers son keepAlive (cachean hasta invalidar). Sin esta dependencia,
/// tras cerrar sesión y volver a entrar como OTRO cliente, la caché del
/// cliente anterior (o del cliente impersonado por un super admin) seguía
/// viva porque su única dependencia observada (idPersona) no cambiaba. Al
/// atar cada fetch al id del usuario autenticado, cualquier cambio de sesión
/// fuerza un refetch con la identidad correcta.

/// Id del usuario autenticado de Supabase. `Provider` solo propaga cuando el
/// valor cambia (==), así los providers de datos solo se refetchean al
/// cambiar realmente de usuario (no en cada notify del perfil/token).
final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).session?.user.id;
});

final clienteResumenProvider = FutureProvider<ClienteResumen>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteResumen(impersonate: imp);
});

final clientePagosProvider = FutureProvider<ClientePagos>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePagos(impersonate: imp);
});

final clientePropiedadesProvider = FutureProvider<ClientePropiedades>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePropiedades(impersonate: imp);
});

final propiedadDetalleProvider = FutureProvider.family<PropiedadDetalle, int>((
  ref,
  id,
) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchPropiedadDetalle(id, impersonate: imp);
});

final clienteProductosProvider = FutureProvider<ClienteProductos>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteProductos(impersonate: imp);
});

final clientePerfilProvider = FutureProvider<ClientePerfil>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClientePerfil(impersonate: imp);
});

final clienteDocumentosProvider = FutureProvider<ClienteDocumentos>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteDocumentos(impersonate: imp);
});

/// Expediente de identidad (tarjeta del Perfil + pantalla Expediente).
final clienteExpedienteProvider = FutureProvider<ClienteExpediente>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteExpediente(impersonate: imp);
});

final clienteNotificacionesProvider = FutureProvider<ClienteNotificaciones>((
  ref,
) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider).idPersona;
  return fetchClienteNotificaciones(impersonate: imp);
});

/// Estado de cuenta por propiedad (id = cuenta de cobranza).
final estadoCuentaProvider = FutureProvider.family<EstadoCuenta, int>((
  ref,
  idCuenta,
) {
  ref.watch(authUserIdProvider);
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

/// Invalida todos los datos del cliente (p.ej. al cerrar sesión). Recibe el
/// `WidgetRef` de la pantalla que dispara el cierre de sesión.
void invalidateAllData(WidgetRef ref) {
  ref.invalidate(clienteResumenProvider);
  ref.invalidate(clientePagosProvider);
  ref.invalidate(clientePropiedadesProvider);
  ref.invalidate(clienteProductosProvider);
  ref.invalidate(propiedadDetalleProvider);
  ref.invalidate(clientePerfilProvider);
  ref.invalidate(clienteDocumentosProvider);
  ref.invalidate(clienteExpedienteProvider);
  ref.invalidate(clienteNotificacionesProvider);
  ref.invalidate(estadoCuentaProvider);
}
