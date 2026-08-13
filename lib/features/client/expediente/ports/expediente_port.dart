import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Resultado de subir un documento del expediente.
///
/// Los tres `datos*` son el contrato ANTERIOR a la accion `analizar`, cuando el
/// backend extraia los datos DESPUES de guardar el archivo. Con el backend
/// nuevo llegan en null porque el cliente ya los confirmo antes de subir; se
/// conservan mientras conviven las dos versiones de la edge function.
typedef ExpedienteUpload = ({
  String estatus,
  DatosFiscalesCSF? datosFiscales,
  DatosCURP? datosCurp,
  DatosActa? datosActa,
});

/// Expediente de documentos del cliente: que se le pide, que ya entrego y como
/// sube uno nuevo.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class ExpedientePort {
  /// Slots del expediente con su estatus, agrupados segun el tipo de persona.
  Future<ClienteExpediente> identityFile();

  /// Analiza un PDF SIN guardarlo: devuelve el veredicto y los campos que se
  /// pudieron extraer para que el cliente los confirme.
  ///
  /// Que el documento no proceda NO es una excepcion: viaja en
  /// [AnalisisDocumento.resultado]. Devuelve null cuando el backend todavia no
  /// conoce la accion, y entonces el llamador sube directo.
  Future<AnalisisDocumento?> analyzeDocument({
    required String slotKey,
    required int typeId,
    required String fileName,
    required String fileBase64,
  });

  /// Sube el documento ya revisado. Lanza [DocumentoInvalidoError] con el
  /// motivo redactado para el cliente si el backend lo rechaza.
  ///
  /// [fields] son los valores que el cliente confirmo y [hash] el del archivo
  /// analizado: el backend rechaza la subida si no es el mismo archivo.
  ///
  /// [docId] solo aplica a un slot multiple (anexos): reemplaza ESE anexo. Sin
  /// el, un slot multiple agrega uno nuevo y no toca los demas. [descripcion]
  /// es lo que distingue un anexo de otro y tambien es solo del slot multiple.
  Future<ExpedienteUpload> uploadDocument({
    required int typeId,
    required String fileName,
    required String fileBase64,
    String? slotKey,
    String? hash,
    Map<String, String>? fields,
    int? docId,
    String? descripcion,
  });
}
