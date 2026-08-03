import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/features/client/documents/adapters/documents_adapter.dart';
import 'package:sozu_cliente_app/features/client/documents/ports/documents_port.dart';
import 'package:sozu_cliente_app/providers/data_providers.dart';

/// Puerto de documentos. Se reconstruye al cambiar la sesion o el cliente
/// impersonado, lo que invalida en cascada los providers de datos de la hoja.
final documentsPortProvider = Provider<DocumentsPort>((ref) {
  ref.watch(authUserIdProvider);
  final imp = ref.watch(impersonationProvider);
  return DocumentsAdapter(impersonate: imp.clientId);
});

/// Documentos y facturas del cliente.
final documentsProvider = FutureProvider<ClienteDocumentos>(
  (ref) => ref.watch(documentsPortProvider).documents(),
);

/// Expediente de identidad (tarjeta del Perfil + pantalla Expediente).
final identityFileProvider = FutureProvider<ClienteExpediente>(
  (ref) => ref.watch(documentsPortProvider).identityFile(),
);


