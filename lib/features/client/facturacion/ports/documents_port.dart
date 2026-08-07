import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Resultado de subir un documento del expediente: `estatus` resultante
/// ('aprobado' | 'revision') y los datos que el backend detecto para confirmar
/// en el perfil (a lo sumo uno viene poblado).
typedef ExpedienteUpload = ({
  String estatus,
  DatosFiscalesCSF? datosFiscales,
  DatosCURP? datosCurp,
  DatosActa? datosActa,
});

/// Area de documentos del menu: los que la empresa entrega al cliente y el
/// expediente de identidad que el cliente sube.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class DocumentsPort {
  /// Documentos y facturas del cliente.
  Future<ClienteDocumentos> documents();

  /// Expediente de identidad: slots con su estatus.
  Future<ClienteExpediente> identityFile();

  /// Sube un documento del expediente; el backend valida el PDF, lo guarda y lo
  /// registra. Lanza [DocumentoInvalidoError] si no pasa la validacion.
  Future<ExpedienteUpload> uploadIdentityDocument({
    required int typeId,
    required String fileName,
    required String fileBase64,
    String? contentType,
  });
}
