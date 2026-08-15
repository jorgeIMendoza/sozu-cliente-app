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
  /// Expediente del titular, o el de una persona ligada si va [contexto].
  Future<ClienteExpediente> identityFile({int? contexto});

  /// Da de alta a un representante legal o a un accionista y lo liga a
  /// [contexto] (por omision, al titular). [porcentaje] solo aplica a un
  /// accionista, y el backend exige que pase del umbral.
  ///
  /// Devuelve el id de la persona creada para poder abrir su expediente sin
  /// esperar a que la lista se refresque; null si el backend no lo manda.
  Future<int?> addPerson({
    required String rol,
    required String nombre,
    required String tipoPersona,
    required String correo,
    required String telefono,
    double? porcentaje,
    int? contexto,
  });

  /// Corrige nombre o porcentaje de una persona ya ligada.
  Future<void> editPerson({
    required int idPersona,
    String? nombre,
    double? porcentaje,
    int? contexto,
  });

  /// Suelta el vinculo (baja logica). El backend lo rechaza si ya subio
  /// documentos o si lo ligo el back office.
  Future<void> removePerson({required int idPersona, int? contexto});

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
