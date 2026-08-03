import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/products/adapters/products_adapter.dart';
import 'package:sozu_cliente_app/features/client/products/ports/products_port.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';

/// Puerto de productos adicionales. Se reconstruye al cambiar la sesion o el
/// cliente impersonado, lo que invalida en cascada los providers de la hoja.
final productsPortProvider = Provider<ProductsPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return ProductsAdapter(impersonate: imp.clientId);
});

/// Productos adicionales agrupados por propiedad.
final productsProvider = FutureProvider<ClienteProductos>(
  (ref) => ref.watch(productsPortProvider).products(),
);

