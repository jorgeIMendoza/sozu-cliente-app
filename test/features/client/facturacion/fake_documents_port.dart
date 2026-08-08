import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/facturacion/ports/documents_port.dart';

/// Doble de [DocumentsPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `documentsPortProvider.overrideWithValue`.
class FakeDocumentsPort implements DocumentsPort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse.
  Object? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  /// JSON que devuelve [documents]; null usa el de por defecto.
  Map<String, dynamic>? documentsJson;

  @override
  Future<ClienteDocumentos> documents() async {
    _throwIfFailing('documents');
    return ClienteDocumentos.fromJson(
      documentsJson ??
          {
            'documentos': [
              {'id': 1, 'nombre': 'Contrato'},
            ],
            'total': 1,
          },
    );
  }
}
