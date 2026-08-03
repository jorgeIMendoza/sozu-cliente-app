import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/properties/adapters/properties_adapter.dart';
import 'package:sozu_cliente_app/features/client/properties/ports/properties_port.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';

/// Puerto de propiedades. Se reconstruye al cambiar la sesion o el cliente
/// impersonado, lo que invalida en cascada los providers de datos de la hoja
/// (el keying de cache que antes repetia cada FutureProvider).
final propertiesPortProvider = Provider<PropertiesPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return PropertiesAdapter(impersonate: imp.idPersona);
});

/// Propiedades del cliente, con sus productos y mantenimiento.
final propertiesProvider = FutureProvider<ClientePropiedades>(
  (ref) => ref.watch(propertiesPortProvider).properties(),
);

/// Detalle de una propiedad. Key = id de la propiedad.
final propertyDetailProvider = FutureProvider.family<PropiedadDetalle, int>(
  (ref, id) => ref.watch(propertiesPortProvider).property(id),
);

/// Proximos pagos, historial y mantenimiento.
final paymentsProvider = FutureProvider<ClientePagos>(
  (ref) => ref.watch(propertiesPortProvider).payments(),
);

/// Estado de cuenta por propiedad. Key = id de la cuenta de cobranza.
final accountStatementProvider = FutureProvider.family<EstadoCuenta, int>(
  (ref, idCuenta) =>
      ref.watch(propertiesPortProvider).accountStatement(idCuenta),
);

@Deprecated('Usar propertiesProvider (features/client/properties/providers/).')
final clientePropiedadesProvider = propertiesProvider;

@Deprecated(
  'Usar propertyDetailProvider (features/client/properties/providers/).',
)
final propiedadDetalleProvider = propertyDetailProvider;

@Deprecated('Usar paymentsProvider (features/client/properties/providers/).')
final clientePagosProvider = paymentsProvider;

@Deprecated(
  'Usar accountStatementProvider (features/client/properties/providers/).',
)
final estadoCuentaProvider = accountStatementProvider;
