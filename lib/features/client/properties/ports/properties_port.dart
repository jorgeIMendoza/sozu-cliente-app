import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Area de propiedades del menu (adquisicion y patrimonio): inmuebles y todo
/// su plan de pagos - estado de cuenta, pagar y credito hipotecario.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class PropertiesPort {
  /// Propiedades del cliente, con sus productos y mantenimiento.
  Future<ClientePropiedades> properties();

  /// Detalle de una propiedad.
  Future<PropiedadDetalle> property(int propertyId);

  /// Proximos pagos, historial y mantenimiento.
  Future<ClientePagos> payments();

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
