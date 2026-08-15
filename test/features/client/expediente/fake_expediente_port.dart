import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/ports/expediente_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [ExpedientePort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `expedientePortProvider.overrideWithValue`.
class FakeExpedientePort implements ExpedientePort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse. Si es un
  /// [DocumentoInvalidoError] solo tiene sentido en [uploadDocument].
  Object? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// `doc_id` de la ultima subida: null = anexo nuevo, con valor = reemplazo.
  int? docIdRecibido;

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  /// JSON que devuelve [identityFile]; null usa el de por defecto.
  Map<String, dynamic>? expedienteJson;

  /// JSON que devuelve [analyzeDocument]; null simula el backend anterior, que
  /// no conoce la accion.
  Map<String, dynamic>? analisisJson;

  @override
  Future<ClienteExpediente> identityFile({int? contexto}) async {
    _throwIfFailing('identityFile');
    return ClienteExpediente.fromJson(
      expedienteJson ??
          {
            'slots': [],
            'requeridos_total': 5,
            'requeridos_aprobados': 2,
            'subidos': 3,
          },
    );
  }

  /// Personas dadas de alta, para afirmar sobre ellas en los tests.
  final List<Map<String, Object?>> altas = [];

  /// Id que devuelve [addPerson], como el que manda la edge function.
  int idAlta = 900;

  @override
  Future<int?> addPerson({
    required String rol,
    required String nombre,
    required String tipoPersona,
    required String correo,
    required String telefono,
    double? porcentaje,
    int? contexto,
  }) async {
    _throwIfFailing('addPerson:$rol:$nombre');
    altas.add({
      'rol': rol,
      'nombre': nombre,
      'tipo': tipoPersona,
      'correo': correo,
      'telefono': telefono,
      'porcentaje': porcentaje,
      'contexto': contexto,
    });
    return idAlta;
  }

  @override
  Future<void> editPerson({
    required int idPersona,
    String? nombre,
    double? porcentaje,
    int? contexto,
  }) async => _throwIfFailing('editPerson:$idPersona');

  @override
  Future<void> removePerson({required int idPersona, int? contexto}) async =>
      _throwIfFailing('removePerson:$idPersona');

  @override
  Future<AnalisisDocumento?> analyzeDocument({
    required String slotKey,
    required int typeId,
    required String fileName,
    required String fileBase64,
  }) async {
    _throwIfFailing('analyzeDocument:$slotKey:$typeId');
    final j = analisisJson;
    return j == null ? null : AnalisisDocumento.fromJson(j);
  }

  @override
  Future<ExpedienteUpload> uploadDocument({
    required int typeId,
    required String fileName,
    required String fileBase64,
    String? slotKey,
    String? hash,
    Map<String, String>? fields,
    int? docId,
    String? descripcion,
  }) async {
    _throwIfFailing('uploadDocument:$typeId:$fileName');
    docIdRecibido = docId;
    return (
      estatus: 'revision',
      datosFiscales: null,
      datosCurp: null,
      datosActa: null,
    );
  }
}
