import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/domain/api_error.dart';

/// Resultado de subir un documento del expediente: `estatus` resultante
/// ('aprobado' | 'revision') y los datos que el backend detecto para confirmar
/// en el perfil (a lo sumo uno viene poblado).
typedef ExpedienteUpload = ({
  String estatus,
  DatosFiscalesCSF? datosFiscales,
  DatosCURP? datosCurp,
  DatosActa? datosActa,
});

/// Datos del portal del cliente: patrimonio, cobranza, documentos y avisos.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class ClientPortalPort {
  /// Resumen del tablero de inicio: financiero, actividad y pendientes.
  Future<ClienteResumen> summary();

  /// Items de menu activos y permitidos para este cliente.
  Future<List<MenuItemDto>> menu();

  /// Proximos pagos, historial y mantenimiento.
  Future<ClientePagos> payments();

  /// Propiedades del cliente, con sus productos y mantenimiento.
  Future<ClientePropiedades> properties();

  /// Detalle de una propiedad.
  Future<PropiedadDetalle> property(int propertyId);

  /// Productos adicionales agrupados por propiedad.
  Future<ClienteProductos> products();

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

  /// Notificaciones del cliente y su conteo de no leidas.
  Future<ClienteNotificaciones> notifications();

  /// Marca una notificacion como leida.
  Future<void> markNotificationRead(int notificationId);

  /// Revierte el "leido" de una notificacion.
  Future<void> markNotificationUnread(int notificationId);

  /// Marca como leidas todas las notificaciones del cliente.
  Future<void> markAllNotificationsRead();

  /// Descarta una notificacion: deja de listarse y de contar.
  Future<void> dismissNotification(int notificationId);

  /// Estado de cuenta de una propiedad. `accountId` es su cuenta de cobranza.
  Future<EstadoCuenta> accountStatement(int accountId);

  /// URL temporal del PDF del estado de cuenta; null si el backend no la da.
  Future<String?> accountStatementPdfUrl(int accountId);

  /// Datos para pagar un acuerdo: CLABE, beneficiario, concepto y vencimiento.
  Future<DatosPago> paymentDetails(int agreementId);

  /// URL temporal del recibo de un pago; el backend lo genera si no existe.
  /// null si no hay recibo disponible.
  Future<String?> paymentReceiptUrl(int paymentId);

  /// Bancos con convenio para credito hipotecario (catalogo dinamico).
  Future<List<BancoConvenio>> mortgageBanks();

  /// Crea la solicitud de precalificacion de credito hipotecario. null si el
  /// backend no devuelve la solicitud creada.
  Future<SolicitudCredito?> createMortgageApplication({
    required int accountId,
    required int bankId,
    double? creditAmount,
    int? termMonths,
  });

  /// Guarda el metodo de pago final de una cuenta: 'RECURSOS_PROPIOS' o
  /// 'CREDITO_HIPOTECARIO'. `bankId` solo aplica al credito con banco preferente.
  Future<void> setFinalPaymentMethod({
    required int accountId,
    required String method,
    int? bankId,
  });
}
