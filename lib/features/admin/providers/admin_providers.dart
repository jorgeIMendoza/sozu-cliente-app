import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/adapters/admin_adapter.dart';
import 'package:sozu_cliente_app/features/admin/ports/admin_port.dart';

/// Puerto de admin. El default es el adaptador real, la única composición
/// que existe en producción; los tests lo sobreescriben con un doble
/// (`overrideWithValue`), así que main.dart no necesita wiring propio.
final adminPortProvider = Provider<AdminPort>((ref) => AdminAdapter());

/// Padrón COMPLETO. Camino heredado: la pantalla busca con
/// [adminClientSearchProvider].
final adminClientsProvider = FutureProvider<AdminClientes>(
  (ref) => ref.watch(adminPortProvider).clients(),
);

/// Filas por página, y también el techo que pinta la pantalla: la lista no
/// tiene scroll propio y construye todas las que reciba.
const int kAdminClientSearchPageSize = 50;

/// Búsqueda de clientes contra el servidor, con la consulta como clave.
///
/// `autoDispose` porque cada texto tecleado es una clave distinta: sin él la
/// caché crece con cada letra durante toda la sesión.
final adminClientSearchProvider = FutureProvider.autoDispose
    .family<AdminClientes, String>(
      (ref, query) => ref
          .watch(adminPortProvider)
          .searchClients(query: query, limit: kAdminClientSearchPageSize),
    );

/// Proyectos SOZU para el filtro "Ver como" del selector de impersonación
/// (mismo catálogo que los avisos: proyectos activos comercializados).
final adminProjectsProvider = FutureProvider<List<CatalogoItem>>(
  (ref) => ref.watch(adminPortProvider).projectCatalog(),
);

/// Dueños/copropietarios de una unidad (proyecto + número de propiedad) para
/// el filtro "Ver como". Key = record (projectId, propertyNumber).
final adminOwnersProvider = FutureProvider.autoDispose
    .family<List<AdminCliente>, ({int projectId, String propertyNumber})>(
      (ref, q) => ref
          .watch(adminPortProvider)
          .owners(projectId: q.projectId, propertyNumber: q.propertyNumber),
    );

/// Avisos ya creados (enviados, programados, cancelados). El alta lo invalida
/// al enviar; la lista de recientes lo observa.
final adminAnnouncementsProvider = FutureProvider<List<AvisoApp>>(
  (ref) => ref.watch(adminPortProvider).announcements(),
);

/// Animacion de la campana del cliente (configuracion general, no por aviso).
final adminBellAnimationProvider = FutureProvider<String>(
  (ref) => ref.watch(adminPortProvider).bellAnimation(),
);
