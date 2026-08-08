import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/features/client/facturacion/providers/documents_providers.dart';
import 'package:sozu_cliente_app/features/client/home/providers/home_providers.dart';
import 'package:sozu_cliente_app/features/client/products/providers/products_providers.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';

/// Invalida los datos de las 5 hojas de `client` (p.ej. al cerrar sesion con
/// candado biometrico, donde la sesion sigue viva y nada se invalida solo).
void invalidateAllData(WidgetRef ref) {
  ref.invalidate(menuProvider);
  ref.invalidate(summaryProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(paymentsProvider);
  ref.invalidate(propertiesProvider);
  ref.invalidate(propertyDetailProvider);
  ref.invalidate(accountStatementProvider);
  ref.invalidate(productsProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(documentsProvider);
  ref.invalidate(identityFileProvider);
}
