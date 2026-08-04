import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/documents/ports/documents_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [DocumentsPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `documentsPortProvider.overrideWithValue`.
class FakeDocumentsPort implements DocumentsPort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse. Si es un
  /// [DocumentoInvalidoError] solo aplica a [uploadIdentityDocument].
  Object? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<ClienteDocumentos> documents() async {
    _throwIfFailing('documents');
    return ClienteDocumentos.fromJson({
      'documentos': [
        {'id': 1, 'nombre': 'Contrato'},
      ],
      'total': 1,
    });
  }

  @override
  Future<ClienteExpediente> identityFile() async {
    _throwIfFailing('identityFile');
    return ClienteExpediente.fromJson({
      'slots': [],
      'requeridos_total': 5,
      'requeridos_aprobados': 2,
      'subidos': 3,
    });
  }

  @override
  Future<ExpedienteUpload> uploadIdentityDocument({
    required int typeId,
    required String fileName,
    required String fileBase64,
    String? contentType,
  }) async {
    _throwIfFailing('uploadIdentityDocument:$typeId:$fileName');
    return (
      estatus: 'revision',
      datosFiscales: null,
      datosCurp: null,
      datosActa: null,
    );
  }
}
