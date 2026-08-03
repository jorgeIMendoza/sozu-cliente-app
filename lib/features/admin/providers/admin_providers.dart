import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/adapters/admin_adapter.dart';
import 'package:sozu_cliente_app/features/admin/ports/admin_port.dart';

/// Puerto de admin. El default es el adaptador real, la única composición
/// que existe en producción; los tests lo sobreescriben con un doble
/// (`overrideWithValue`), así que main.dart no necesita wiring propio.
final adminPortProvider = Provider<AdminPort>((ref) => AdminAdapter());

/// Clientes para el selector de impersonación (no depende del target).
final adminClientsProvider = FutureProvider<AdminClientes>(
  (ref) => ref.watch(adminPortProvider).clients(),
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
