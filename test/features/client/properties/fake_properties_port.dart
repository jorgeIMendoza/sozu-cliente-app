import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/properties/ports/properties_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [PropertiesPort] con datos fijos en memoria: sin red, sin
/// Supabase. Se inyecta con `propertiesPortProvider.overrideWithValue`.
class FakePropertiesPort implements PropertiesPort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  /// JSON que devuelve [properties]; null usa el de por defecto. Se fija para
  /// probar listados (filtros, vacios) sin tocar el resto del doble.
  Map<String, dynamic>? propertiesJson;

  @override
  Future<ClientePropiedades> properties() async {
    _throwIfFailing('properties');
    return ClientePropiedades.fromJson(
      propertiesJson ??
          {
            'en_adquisicion': [
              {'id': 11, 'nombre': '101', 'proyecto': 'Toreo'},
            ],
            'totales': {'en_adquisicion': 1000.0},
          },
    );
  }

  @override
  Future<PropiedadDetalle> property(int propertyId) async {
    _throwIfFailing('property:$propertyId');
    return PropiedadDetalle.fromJson({'id': propertyId, 'nombre': '101'});
  }

  @override
  Future<ClientePagos> payments() async {
    _throwIfFailing('payments');
    return ClientePagos.fromJson({
      'saldo': {'total': 1000.0, 'pagado': 400.0, 'pendiente': 600.0},
    });
  }

  @override
  Future<EstadoCuenta> accountStatement(int accountId) async {
    _throwIfFailing('accountStatement:$accountId');
    return EstadoCuenta.fromJson({
      'resumen': {'precio_final': 1000.0, 'saldo_pendiente': 600.0},
    });
  }

  @override
  Future<String?> accountStatementPdfUrl(int accountId) async {
    _throwIfFailing('accountStatementPdfUrl:$accountId');
    return 'https://firmada/estado-$accountId.pdf';
  }

  @override
  Future<DatosPago> paymentDetails(int agreementId) async {
    _throwIfFailing('paymentDetails:$agreementId');
    return DatosPago.fromJson({'concepto': 'Mensualidad', 'monto': 100.0});
  }

  @override
  Future<String?> paymentReceiptUrl(int paymentId) async {
    _throwIfFailing('paymentReceiptUrl:$paymentId');
    return 'https://firmada/recibo-$paymentId.pdf';
  }

  @override
  Future<List<BancoConvenio>> mortgageBanks() async {
    _throwIfFailing('mortgageBanks');
    return [
      BancoConvenio.fromJson({'id': 1, 'nombre': 'BBVA'}),
    ];
  }

  @override
  Future<SolicitudCredito?> createMortgageApplication({
    required int accountId,
    required int bankId,
    double? creditAmount,
    int? termMonths,
  }) async {
    _throwIfFailing('createMortgageApplication:$accountId:$bankId');
    return null;
  }

  @override
  Future<void> setFinalPaymentMethod({
    required int accountId,
    required String method,
    int? bankId,
  }) async {
    _throwIfFailing('setFinalPaymentMethod:$accountId:$method:$bankId');
  }
}
